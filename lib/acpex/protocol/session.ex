defmodule ACPex.Protocol.Session do
  @moduledoc """
  The workhorse GenServer that manages the state for a single conversation session.
  """
  use GenServer
  require Logger

  defstruct handler_module: nil,
            handler_state: nil,
            session_id: nil,
            connection_pid: nil,
            transport_pid: nil

  # Public API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  # GenServer Callbacks

  @impl true
  def init(%{
        handler_module: handler_module,
        initial_handler_state: initial_handler_state,
        transport_pid: transport_pid
      }) do
    state = %__MODULE__{
      handler_module: handler_module,
      handler_state: initial_handler_state,
      transport_pid: transport_pid,
      session_id: Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:request, connection_pid, %{"method" => "session/new"} = request}, state) do
    # This is the first request this session will see.
    # We need to call the user's callback.
    case state.handler_module.handle_new_session(request["params"], state.handler_state) do
      {:ok, response_params, new_handler_state} ->
        # Tell the connection about us so it can route future messages
        send(connection_pid, {:session_started, state.session_id, self()})

        response =
          build_response(request["id"], Map.put(response_params, "session_id", state.session_id))

        send_message(state.transport_pid, response)

        {:noreply, %{state | handler_state: new_handler_state, connection_pid: connection_pid}}

      {:error, error, new_handler_state} ->
        response = build_error_response(request["id"], error)
        send_message(state.transport_pid, response)
        {:noreply, %{state | handler_state: new_handler_state, connection_pid: connection_pid}}
    end
  end

  @impl true
  def handle_info({:forward, %{"method" => method, "params" => params, "id" => id}}, state) do
    # A forwarded request from the connection
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

        {:noreply, new_handler_state} ->
          # This is for notifications, but we received an ID. Should we error?
          {:noreply, %{state | handler_state: new_handler_state}}
      end
    else
      # Method not found
      response =
        build_error_response(id, %{code: -32_601, message: "Method not found: #{method}"})

      send_message(state.transport_pid, response)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:forward, %{"method" => method, "params" => params}}, state) do
    # A forwarded notification from the connection
    callback = method_to_callback(method)

    if function_exported?(state.handler_module, callback, 2) do
      {:noreply, new_handler_state} =
        apply(state.handler_module, callback, [params, state.handler_state])

      {:noreply, %{state | handler_state: new_handler_state}}
    else
      # Notification for a method not found, just ignore
      {:noreply, state}
    end
  end

  # Private Helpers

  defp method_to_callback(method) do
    ("handle_" <> String.replace(method, "/", "_"))
    |> String.to_atom()
  end

  defp build_response(id, result) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "result" => result
    }
  end

  defp build_error_response(id, error) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "error" => error
    }
  end

  defp send_message(transport_pid, message) do
    send(transport_pid, {:send_message, message})
  end
end
