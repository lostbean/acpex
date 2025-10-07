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
  import Bitwise
  require Logger

  alias ACPex.Protocol.SessionSupervisor
  alias ACPex.Transport.Ndjson
  alias ACPex.Schema.Codec
  alias ACPex.Schema.Connection.InitializeRequest
  alias ACPex.Schema.Connection.AuthenticateRequest
  alias ACPex.Schema.Client.{FsReadTextFileRequest, FsWriteTextFileRequest}
  alias ACPex.Schema.Client.Terminal

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
    Logger.debug(
      "Connection received message: #{inspect(Map.take(message, ["id", "method", "jsonrpc"]))}"
    )

    Logger.debug("Full message keys: #{inspect(Map.keys(message))}")
    handle_incoming_message(message, state)
  end

  @impl true
  def handle_info({:transport_closed}, state) do
    Logger.info("ACP transport closed")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:session_started, session_id, session_pid}, state) do
    # This message is now redundant since we register sessions synchronously
    # But we keep the handler for backwards compatibility
    Logger.debug("Received redundant :session_started notification for #{session_id}")

    # Check if already registered
    if Map.has_key?(state.sessions, session_id) do
      {:noreply, state}
    else
      Logger.warning("Session #{session_id} not already registered, registering now")
      new_sessions = Map.put(state.sessions, session_id, session_pid)
      {:noreply, %{state | sessions: new_sessions}}
    end
  end

  # Private Helpers

  # Decode connection-level request params to appropriate struct
  defp decode_connection_request("initialize", params) do
    Codec.decode_from_map!(params, InitializeRequest)
  end

  defp decode_connection_request("authenticate", params) do
    Codec.decode_from_map!(params, AuthenticateRequest)
  end

  # Client request methods (agent → client communication)
  defp decode_connection_request("fs/read_text_file", params) do
    Codec.decode_from_map!(params, FsReadTextFileRequest)
  end

  defp decode_connection_request("fs/write_text_file", params) do
    Codec.decode_from_map!(params, FsWriteTextFileRequest)
  end

  defp decode_connection_request("terminal/create", params) do
    Codec.decode_from_map!(params, Terminal.CreateRequest)
  end

  defp decode_connection_request("terminal/output", params) do
    Codec.decode_from_map!(params, Terminal.OutputRequest)
  end

  defp decode_connection_request("terminal/wait_for_exit", params) do
    Codec.decode_from_map!(params, Terminal.WaitForExitRequest)
  end

  defp decode_connection_request("terminal/kill", params) do
    Codec.decode_from_map!(params, Terminal.KillRequest)
  end

  defp decode_connection_request("terminal/release", params) do
    Codec.decode_from_map!(params, Terminal.ReleaseRequest)
  end

  # For any unknown connection-level methods, pass through as-is
  defp decode_connection_request(_method, params), do: params

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
        case resolve_executable(path, agent_args) do
          {:ok, {executable, full_args}} ->
            transport_opts = [
              port_opts: {:spawn_executable, executable},
              port_args: full_args
            ]

            Logger.debug(
              "Starting transport for executable=#{executable}, args=#{inspect(full_args)}"
            )

            transport_module.start_link(self(), transport_opts)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # Resolve the executable path
  #
  # This function validates that the given path points to an executable file.
  # The OS handles all executable types uniformly (binaries, scripts with shebangs, symlinks).
  #
  # Returns {:ok, {executable_path, args}} or {:error, reason}
  defp resolve_executable(path, args) do
    # If path is not absolute, try to resolve it from PATH
    resolved_path =
      if Path.type(path) == :absolute do
        path
      else
        System.find_executable(path)
      end

    case resolved_path do
      nil ->
        {:error, "Executable not found in PATH: #{path}"}

      abs_path ->
        cond do
          not File.exists?(abs_path) ->
            {:error, "Executable does not exist: #{abs_path}"}

          not executable?(abs_path) ->
            {:error, "File is not executable: #{abs_path}"}

          true ->
            {:ok, {abs_path, args}}
        end
    end
  end

  # Check if a file is executable
  # On Unix systems, checks the execute permission bit
  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode}} ->
        # Check if any execute bit is set (owner, group, or other)
        # Execute bits are 0o111 (owner=0o100, group=0o010, other=0o001)
        band(mode, 0o111) != 0

      {:ok, %File.Stat{type: :symlink}} ->
        # For symlinks, check the target
        case File.stat(path, time: :posix) do
          {:ok, %File.Stat{mode: mode}} ->
            band(mode, 0o111) != 0

          _ ->
            false
        end

      _ ->
        # If we can't stat it, assume it's not executable
        false
    end
  end

  defp handle_incoming_message(%{"method" => "session/new"} = msg, state) do
    Logger.debug("→ Pattern matched: session/new request")

    case SessionSupervisor.start_session(
           state.session_sup,
           state.handler_module,
           state.handler_state,
           state.transport_pid
         ) do
      {:ok, session_pid} ->
        # Get the session ID synchronously and register it immediately
        # This prevents race conditions where session/update notifications
        # arrive before the session is registered
        session_id = ACPex.Protocol.Session.get_session_id(session_pid)

        Logger.debug(
          "  Session started: #{inspect(session_pid)}, session_id: #{session_id}, registering and forwarding request"
        )

        # Register the session immediately
        new_sessions = Map.put(state.sessions, session_id, session_pid)
        new_state = %{state | sessions: new_sessions}

        # Now forward the request
        send(session_pid, {:request, self(), msg})
        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Failed to start session: #{inspect(reason)}")
        error = %{code: -32_000, message: "Failed to start session"}
        response = build_error_response(msg["id"], error)
        send_message(state.transport_pid, response)
        {:noreply, state}
    end
  end

  # Session-level messages (check for both camelCase and snake_case for compatibility)
  defp handle_incoming_message(%{"params" => %{"sessionId" => session_id}} = msg, state) do
    Logger.debug(
      "→ Pattern matched: session-level message (session_id: #{session_id}, method: #{msg["method"]}, has_id: #{!!msg["id"]})"
    )

    case Map.get(state.sessions, session_id) do
      nil ->
        handle_missing_session(msg, session_id, state)

      session_pid ->
        Logger.debug("  Forwarding to session #{inspect(session_pid)}")
        send(session_pid, {:forward, msg})
        {:noreply, state}
    end
  end

  # Also handle snake_case for backward compatibility
  defp handle_incoming_message(%{"params" => params} = msg, state)
       when is_map_key(params, "session_id") do
    session_id = params["session_id"]

    Logger.debug(
      "→ Pattern matched: session-level message (session_id: #{session_id}, method: #{msg["method"]}, has_id: #{!!msg["id"]})"
    )

    case Map.get(state.sessions, session_id) do
      nil ->
        handle_missing_session(msg, session_id, state)

      session_pid ->
        Logger.debug("  Forwarding to session #{inspect(session_pid)}")
        send(session_pid, {:forward, msg})
        {:noreply, state}
    end
  end

  defp handle_incoming_message(%{"id" => id, "result" => _result} = msg, state) do
    Logger.debug("→ Pattern matched: response with result (id: #{id})")
    handle_response(id, msg, state)
  end

  defp handle_incoming_message(%{"id" => id, "error" => _error} = msg, state) do
    Logger.debug("→ Pattern matched: response with error (id: #{id})")
    handle_response(id, msg, state)
  end

  # Fallback for connection-level requests (initialize, authenticate, etc.)
  defp handle_incoming_message(%{"id" => id, "method" => method, "params" => params}, state) do
    Logger.debug("→ Pattern matched: connection-level request (method: #{method}, id: #{id})")
    callback = method_to_callback(method)

    if function_exported?(state.handler_module, callback, 2) do
      Logger.debug("  Calling handler: #{state.handler_module}.#{callback}/2")

      # Decode params to appropriate struct based on method
      request_struct = decode_connection_request(method, params)

      case apply(state.handler_module, callback, [request_struct, state.handler_state]) do
        {:ok, result_struct, new_handler_state} ->
          # Encode struct response back to map for JSON-RPC transport
          result_map = Codec.encode_to_map!(result_struct)
          response = build_response(id, result_map)
          send_message(state.transport_pid, response)
          {:noreply, %{state | handler_state: new_handler_state}}

        {:error, error, new_handler_state} ->
          response = build_error_response(id, error)
          send_message(state.transport_pid, response)
          {:noreply, %{state | handler_state: new_handler_state}}
      end
    else
      Logger.warning("  Method not found: #{method}, handler doesn't export #{callback}/2")
      error = %{code: -32_601, message: "Method not found: #{method}"}
      response = build_error_response(id, error)
      send_message(state.transport_pid, response)
      {:noreply, state}
    end
  end

  # Catch-all for any messages that don't match the above patterns
  defp handle_incoming_message(msg, state) do
    Logger.warning("→ Pattern matched: UNHANDLED message type")
    Logger.warning("  Message: #{inspect(msg)}")
    Logger.warning("  This message doesn't match any expected pattern!")

    # If it has an id, send an error response
    if msg["id"] do
      error = %{code: -32_600, message: "Invalid request: message format not recognized"}
      response = build_error_response(msg["id"], error)
      send_message(state.transport_pid, response)
    end

    {:noreply, state}
  end

  # Handle missing session - only create on-demand for clients
  defp handle_missing_session(msg, session_id, %{role: :client} = state) do
    Logger.debug("Session not found, creating on-demand for session_id: #{session_id}")

    case SessionSupervisor.start_session(
           state.session_sup,
           state.handler_module,
           state.handler_state,
           state.transport_pid,
           session_id
         ) do
      {:ok, session_pid} ->
        Logger.debug("  Created session #{inspect(session_pid)}, forwarding message")
        new_sessions = Map.put(state.sessions, session_id, session_pid)
        send(session_pid, {:forward, msg})
        {:noreply, %{state | sessions: new_sessions}}

      {:error, reason} ->
        Logger.error("Failed to create session on-demand: #{inspect(reason)}")
        error = %{code: -32_000, message: "Failed to create session"}
        response = build_error_response(msg["id"], error)
        send_message(state.transport_pid, response)
        {:noreply, state}
    end
  end

  # Agents should error on unknown session_ids
  defp handle_missing_session(msg, session_id, state) do
    Logger.error("Received message for unknown session_id: #{session_id}")
    Logger.debug("  Known sessions: #{inspect(Map.keys(state.sessions))}")
    error = %{code: -32_001, message: "Unknown session_id: #{session_id}"}
    response = build_error_response(msg["id"], error)
    send_message(state.transport_pid, response)
    {:noreply, state}
  end

  defp handle_response(id, response_message, state) do
    Logger.debug("  Handling response for request id: #{id}")
    Logger.debug("  Pending requests: #{inspect(Map.keys(state.pending_requests))}")

    case Map.pop(state.pending_requests, id) do
      {from, new_pending} when from != nil ->
        Logger.debug("  ✓ Found pending request, replying to caller: #{inspect(from)}")
        GenServer.reply(from, response_message)
        {:noreply, %{state | pending_requests: new_pending}}

      _ ->
        Logger.warning("  ✗ Received response for unknown request ID: #{id}")
        Logger.warning("    This might indicate a timeout or duplicate response")
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
