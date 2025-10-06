defmodule ACPex.Protocol.Connection do
  @moduledoc """
  GenServer that manages the state for a single agent-client connection.

  The Connection module is a core component in the ACPex OTP architecture,
  sitting between the transport layer and individual session processes. It is
  responsible for:

  - Handling connection-level protocol messages (`initialize`, `authenticate`)
  - Managing the lifecycle of session processes via a `SessionSupervisor`
  - Routing messages to the appropriate session based on `session_id`
  - Handling bidirectional JSON-RPC communication
  - Managing pending requests and matching responses

  ## Architecture

  Each connection spawns its own supervision tree:

      Connection.GenServer
      ├── SessionSupervisor
      │   ├── Session.GenServer (session_id_1)
      │   ├── Session.GenServer (session_id_2)
      │   └── ...

  ## Message Flow

  1. **Incoming messages** arrive via `{:message, json_rpc_message}`
  2. **Connection-level messages** are handled directly by calling the handler module
  3. **Session-level messages** are forwarded to the appropriate session process
  4. **Responses** are matched with pending requests via their `id` field

  ## Examples

      # Start an agent connection
      {:ok, pid} = Connection.start_link(
        handler_module: MyAgent,
        handler_args: [],
        role: :agent,
        transport_pid: transport_pid
      )

      # Send a notification to the other party
      Connection.send_notification(pid, "session/update", %{
        "session_id" => "abc123",
        "update" => %{"kind" => "message", "content" => "Hello"}
      })

      # Send a request and await response
      response = Connection.send_request(pid, "fs/read_text_file", %{
        "path" => "/tmp/file.txt"
      })

  """
  use GenServer
  require Logger

  alias ACPex.Protocol.SessionSupervisor
  alias ACPex.Transport.Ndjson

  defstruct handler_module: nil,
            handler_state: nil,
            role: nil,
            transport_pid: nil,
            session_sup: nil,
            # %{session_id => session_pid}
            sessions: %{},
            pending_requests: %{},
            next_id: 1

  # Public API

  @doc """
  Starts a new Connection GenServer.

  ## Options

    * `:handler_module` - The module implementing either `ACPex.Agent` or `ACPex.Client`
    * `:handler_args` - Arguments passed to the handler's `init/1` callback
    * `:role` - Either `:agent` or `:client`
    * `:transport_pid` - (optional) PID of an existing transport process
    * `:opts` - Additional GenServer options (e.g., `:name`)

  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    # Extract nested options for GenServer and transport configuration
    nested_opts = opts[:opts] || []
    {gen_opts, init_opts} = Keyword.split(nested_opts, [:name])

    # Merge init_opts (like :agent_path) back into main opts, then remove :opts key
    merged_opts =
      opts
      |> Keyword.delete(:opts)
      |> Keyword.merge(init_opts)

    GenServer.start_link(__MODULE__, merged_opts, gen_opts)
  end

  @doc """
  Sends a JSON-RPC notification (one-way message) to the other party.

  Notifications do not have an `id` field and do not expect a response.

  ## Examples

      Connection.send_notification(conn, "session/update", %{
        "session_id" => "abc",
        "update" => %{"kind" => "thought", "content" => "Thinking..."}
      })

  """
  @spec send_notification(pid(), String.t(), map()) :: :ok
  def send_notification(pid, method, params) do
    GenServer.cast(pid, {:send_notification, method, params})
  end

  @doc """
  Sends a JSON-RPC request and asynchronously waits for the response.

  The request will have an `id` field and expects a response. This function
  blocks until the response is received or the timeout expires.

  ## Examples

      response = Connection.send_request(conn, "fs/read_text_file", %{
        "path" => "/etc/hosts"
      }, 10_000)

  """
  @spec send_request(pid(), String.t(), map(), timeout()) :: map()
  def send_request(pid, method, params, timeout \\ 5000) do
    GenServer.call(pid, {:send_request, method, params}, timeout)
  end

  # GenServer Callbacks

  @impl true
  def init(opts) do
    handler_module = Keyword.fetch!(opts, :handler_module)
    handler_args = Keyword.get(opts, :handler_args, [])
    role = Keyword.fetch!(opts, :role)

    case handler_module.init(handler_args) do
      {:ok, handler_state} ->
        with {:ok, transport_pid} <- start_transport(role, opts) do
          {:ok, session_sup} = SessionSupervisor.start_link(handler_module: handler_module)

          state = %__MODULE__{
            handler_module: handler_module,
            handler_state: handler_state,
            role: role,
            transport_pid: transport_pid,
            session_sup: session_sup
          }

          {:ok, state}
        end

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:send_request, method, params}, from, state) do
    id = state.next_id
    request = build_request(id, method, params)

    state = %{
      state
      | next_id: id + 1,
        pending_requests: Map.put(state.pending_requests, id, from)
    }

    send_message(state.transport_pid, request)

    {:noreply, state}
  end

  @impl true
  def handle_cast({:send_notification, method, params}, state) do
    notification = build_notification(method, params)
    send_message(state.transport_pid, notification)
    {:noreply, state}
  end

  @impl true
  def handle_info({:message, message}, state) do
    handle_incoming_message(message, state)
  end

  @impl true
  def handle_info({:transport_closed}, state) do
    Logger.info("ACP transport closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:session_started, session_id, session_pid}, state) do
    new_sessions = Map.put(state.sessions, session_id, session_pid)
    {:noreply, %{state | sessions: new_sessions}}
  end

  # Private Helpers

  defp start_transport(role, opts) do
    if transport_pid = opts[:transport_pid] do
      {:ok, transport_pid}
    else
      start_managed_transport(role, opts)
    end
  end

  defp start_managed_transport(:agent, opts) do
    transport_module = Keyword.get(opts, :transport, Ndjson)
    transport_module.start_link(self())
  end

  defp start_managed_transport(:client, opts) do
    transport_module = Keyword.get(opts, :transport, Ndjson)

    case Keyword.get(opts, :agent_path) do
      nil ->
        {:error, "agent_path must be provided for client role"}

      path ->
        # Get optional agent args (specific to each agent implementation)
        agent_args = Keyword.get(opts, :agent_args, [])

        # Resolve the actual executable and args
        {executable, full_args} = resolve_executable(path, agent_args)

        transport_opts = [
          port_opts: {:spawn_executable, executable},
          port_args: full_args
        ]

        Logger.debug(
          "Starting transport for executable=#{executable}, args=#{inspect(full_args)}"
        )

        transport_module.start_link(self(), transport_opts)
    end
  end

  # Resolve the executable path, handling Node.js scripts
  defp resolve_executable(path, args) do
    # Resolve symlinks to get the real path
    real_path =
      case File.read_link(path) do
        {:ok, target} ->
          # If it's a relative symlink, resolve it relative to the symlink's directory
          if String.starts_with?(target, "/") do
            target
          else
            path
            |> Path.dirname()
            |> Path.join(target)
            |> Path.expand()
          end

        {:error, _} ->
          # Not a symlink, use as-is
          path
      end

    # Check if it's a Node.js script (ends with .js or .mjs)
    cond do
      String.ends_with?(real_path, [".js", ".mjs"]) ->
        # It's a JavaScript file, need to run with node
        node_path = System.find_executable("node") || "node"
        {node_path, [real_path | args]}

      # Check if original path is a script with shebang
      is_script_with_shebang?(real_path) ->
        # Has shebang, but Erlang ports may not handle it, use the original path
        # and hope it's executable, otherwise this will fail with a clear error
        {path, args}

      true ->
        # Looks like a real binary executable
        {path, args}
    end
  end

  defp is_script_with_shebang?(path) do
    case File.open(path, [:read]) do
      {:ok, file} ->
        first_bytes = IO.binread(file, 2)
        File.close(file)
        first_bytes == "#!"

      {:error, _} ->
        false
    end
  end

  defp handle_incoming_message(%{"method" => "session/new"} = msg, state) do
    case SessionSupervisor.start_session(
           state.session_sup,
           state.handler_module,
           state.handler_state,
           state.transport_pid
         ) do
      {:ok, session_pid} ->
        send(session_pid, {:request, self(), msg})
        {:noreply, state}

      {:error, reason} ->
        Logger.error("Failed to start session: #{inspect(reason)}")
        error = %{code: -32_000, message: "Failed to start session"}
        response = build_error_response(msg["id"], error)
        send_message(state.transport_pid, response)
        {:noreply, state}
    end
  end

  # Handle both camelCase and snake_case session_id in params
  defp handle_incoming_message(%{"params" => %{"sessionId" => session_id}} = msg, state) do
    # Convert camelCase to snake_case and forward
    msg_with_snake_case = put_in(msg, ["params", "session_id"], session_id)
    handle_incoming_message(msg_with_snake_case, state)
  end

  defp handle_incoming_message(%{"params" => %{"session_id" => session_id}} = msg, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        Logger.error("Received message for unknown session_id: #{session_id}")
        error = %{code: -32_001, message: "Unknown session_id: #{session_id}"}
        response = build_error_response(msg["id"], error)
        send_message(state.transport_pid, response)
        {:noreply, state}

      session_pid ->
        send(session_pid, {:forward, msg})
        {:noreply, state}
    end
  end

  defp handle_incoming_message(%{"id" => id, "result" => _result} = msg, state) do
    handle_response(id, msg, state)
  end

  defp handle_incoming_message(%{"id" => id, "error" => _error} = msg, state) do
    handle_response(id, msg, state)
  end

  # Fallback for connection-level requests (initialize, etc.)
  defp handle_incoming_message(%{"id" => id, "method" => method, "params" => params}, state) do
    callback = method_to_callback(method)

    if function_exported?(state.handler_module, callback, 2) do
      case apply(state.handler_module, callback, [params, state.handler_state]) do
        {:ok, result, new_handler_state} ->
          response = build_response(id, result)
          send_message(state.transport_pid, response)
          {:noreply, %{state | handler_state: new_handler_state}}

        {:error, error, new_handler_state} ->
          response = build_error_response(id, error)
          send_message(state.transport_pid, response)
          {:noreply, %{state | handler_state: new_handler_state}}
      end
    else
      error = %{code: -32_601, message: "Method not found: #{method}"}
      response = build_error_response(id, error)
      send_message(state.transport_pid, response)
      {:noreply, state}
    end
  end

  defp handle_response(id, response_message, state) do
    case Map.pop(state.pending_requests, id) do
      {from, new_pending} when from != nil ->
        GenServer.reply(from, response_message)
        {:noreply, %{state | pending_requests: new_pending}}

      _ ->
        Logger.warning("Received response for unknown request ID: #{id}")
        {:noreply, state}
    end
  end

  defp method_to_callback(method) do
    ("handle_" <> String.replace(method, "/", "_"))
    |> String.to_atom()
  end

  defp build_request(id, method, params) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => method,
      "params" => params
    }
  end

  defp build_notification(method, params) do
    %{
      "jsonrpc" => "2.0",
      "method" => method,
      "params" => params
    }
  end

  defp build_error_response(id, error) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => error
    }
  end

  defp build_response(id, result) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => result
    }
  end

  defp send_message(transport_pid, message) do
    send(transport_pid, {:send_message, message})
  end
end
