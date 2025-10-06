defmodule ACPex.Protocol.Connection do
  @moduledoc """
  GenServer that manages the state for a single agent-client connection.

  It handles the initial `initialize` and `authenticate` messages and is
  responsible for starting its own `SessionSupervisor`.
  """
  use GenServer
  require Logger

  alias ACPex.Protocol.SessionSupervisor
  alias ACPex.Transport.Stdio

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

  def start_link(opts) do
    {gen_opts, _init_opts} = Keyword.split(opts[:opts] || [], [:name])
    GenServer.start_link(__MODULE__, Keyword.delete(opts, :opts), gen_opts)
  end

  def send_notification(pid, method, params) do
    GenServer.cast(pid, {:send_notification, method, params})
  end

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
    transport_module = Keyword.get(opts, :transport, Stdio)
    transport_module.start_link(self())
  end

  defp start_managed_transport(:client, opts) do
    transport_module = Keyword.get(opts, :transport, Stdio)

    case Keyword.get(opts[:opts], :agent_path) do
      nil ->
        {:error, "agent_path must be provided for client role"}

      path ->
        transport_opts = [port_opts: {:spawn_executable, path}]
        transport_module.start_link(self(), transport_opts)
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
        error = %{code: -32000, message: "Failed to start session"}
        response = build_error_response(msg["id"], error)
        send_message(state.transport_pid, response)
        {:noreply, state}
    end
  end

  defp handle_incoming_message(%{"params" => %{"session_id" => session_id}} = msg, state) do
    case Map.get(state.sessions, session_id) do
      nil ->
        Logger.error("Received message for unknown session_id: #{session_id}")
        error = %{code: -32001, message: "Unknown session_id: #{session_id}"}
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
      error = %{code: -32601, message: "Method not found: #{method}"}
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
