defmodule ACPex.Connection do
  @moduledoc """
  GenServer that manages an ACP connection over stdio.

  This is the core of the library, handling:
  - Message framing and JSON-RPC protocol
  - Request/response correlation
  - Dispatching to user callbacks
  - State management
  """

  use GenServer
  require Logger

  alias ACPex.Transport.Stdio

  defstruct [
    :transport_pid,
    :handler_module,
    :handler_state,
    :role,
    :buffer,
    pending_requests: %{},
    sessions: %{},
    next_id: 1
  ]

  @type t :: %__MODULE__{
          transport_pid: pid() | nil,
          handler_module: module(),
          handler_state: term(),
          role: :client | :agent,
          buffer: binary(),
          pending_requests: %{integer() => GenServer.from()},
          sessions: %{String.t() => map()},
          next_id: integer()
        }

  # Client API

  def start_link(opts) do
    {gen_opts, _init_opts} = Keyword.split(opts[:opts] || [], [:name])
    GenServer.start_link(__MODULE__, Keyword.delete(opts, :opts), gen_opts)
  end

  @doc """
  Send a JSON-RPC notification (no response expected).
  """
  def send_notification(pid, method, params) do
    GenServer.cast(pid, {:send_notification, method, params})
  end

  @doc """
  Send a JSON-RPC request and wait for the response.
  """
  def send_request(pid, method, params, timeout \\ 5000) do
    GenServer.call(pid, {:send_request, method, params}, timeout)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    handler_module = Keyword.fetch!(opts, :handler_module)
    handler_args = Keyword.get(opts, :handler_args, [])
    role = Keyword.fetch!(opts, :role)

    case handler_module.init(handler_args) do
      {:ok, handler_state} ->
        transport_pid =
          if given_pid = opts[:transport_pid] do
            given_pid
          else
            transport_module = Keyword.get(opts, :transport, Stdio)
            {:ok, pid} = transport_module.start_link(self())
            pid
          end

        state = %__MODULE__{
          transport_pid: transport_pid,
          handler_module: handler_module,
          handler_state: handler_state,
          role: role,
          buffer: ""
        }

        {:ok, state}

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
  def handle_cast({:incoming_request, id, method, params}, state) do
    case dispatch_request(state, method, params) do
      {:ok, result, new_handler_state} ->
        response = build_response(id, result)
        send_message(state.transport_pid, response)
        {:noreply, %{state | handler_state: new_handler_state}}

      {:error, error, new_handler_state} ->
        response = build_error_response(id, error)
        send_message(state.transport_pid, response)
        {:noreply, %{state | handler_state: new_handler_state}}
    end
  end

  @impl true
  def handle_cast({:incoming_notification, method, params}, state) do
    case dispatch_notification(state, method, params) do
      {:noreply, new_handler_state} ->
        {:noreply, %{state | handler_state: new_handler_state}}
    end
  end

  @impl true
  def handle_info({:stdio_data, data}, state) do
    state = process_incoming_data(state, data)
    {:noreply, state}
  end

  @impl true
  def handle_info({:stdio_closed}, state) do
    Logger.info("ACP connection closed")
    {:stop, :normal, state}
  end

  # Private Functions

  defp process_incoming_data(state, new_data) do
    buffer = state.buffer <> new_data

    case parse_message(buffer) do
      {:ok, message, rest} ->
        handle_parsed_message(state, message)
        process_incoming_data(%{state | buffer: rest}, "")

      {:incomplete, _} ->
        %{state | buffer: buffer}

      {:error, reason} ->
        Logger.error("Failed to parse message: #{inspect(reason)}")
        state
    end
  end

  defp parse_message(buffer) do
    case :binary.split(buffer, "\n\n") do
      [headers, rest] ->
        parse_body(rest, parse_content_length(headers), buffer)

      [_] ->
        {:incomplete, buffer}
    end
  end

  defp parse_body(rest, {:ok, length}, buffer) when byte_size(rest) >= length do
    <<json::binary-size(length), remaining::binary>> = rest

    case Jason.decode(json) do
      {:ok, message} -> {:ok, message, remaining}
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  defp parse_body(_rest, {:ok, _length}, buffer), do: {:incomplete, buffer}
  defp parse_body(_rest, :error, _buffer), do: {:error, :invalid_headers}

  defp parse_content_length(headers) do
    headers
    |> String.split("\n")
    |> Enum.find_value(&extract_content_length/1)
    |> case do
      nil -> :error
      val -> val
    end
  end

  defp extract_content_length("Content-Length: " <> rest) do
    case Integer.parse(String.trim(rest)) do
      {length, _} -> {:ok, length}
      :error -> nil
    end
  end

  defp extract_content_length(_other_line), do: nil

  defp handle_parsed_message(state, %{"jsonrpc" => "2.0", "id" => id} = message) do
    cond do
      Map.has_key?(message, "result") ->
        handle_response(state, id, {:ok, message["result"]})

      Map.has_key?(message, "error") ->
        handle_response(state, id, {:error, message["error"]})

      Map.has_key?(message, "method") ->
        GenServer.cast(self(), {:incoming_request, id, message["method"], message["params"]})
    end
  end

  defp handle_parsed_message(_state, %{"jsonrpc" => "2.0", "method" => method} = message) do
    GenServer.cast(self(), {:incoming_notification, method, message["params"]})
  end

  defp handle_response(state, id, response) do
    case Map.pop(state.pending_requests, id) do
      {nil, _} ->
        Logger.warning("Received response for unknown request ID: #{id}")

      {from, pending} ->
        GenServer.reply(from, response)
        %{state | pending_requests: pending}
    end
  end

  defp dispatch_request(state, method, params) do
    callback = method_to_callback(method)

    if function_exported?(state.handler_module, callback, 2) do
      apply(state.handler_module, callback, [params || %{}, state.handler_state])
    else
      {:error, %{code: -32_601, message: "Method not found: #{method}"}, state.handler_state}
    end
  end

  defp dispatch_notification(state, method, params) do
    callback = method_to_callback(method)

    if function_exported?(state.handler_module, callback, 2) do
      apply(state.handler_module, callback, [params || %{}, state.handler_state])
    else
      {:noreply, state.handler_state}
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
    json = Jason.encode!(message)
    frame = "Content-Length: " <> Integer.to_string(byte_size(json)) <> "\r\n\r\n" <> json
    send(transport_pid, {:send_data, frame})
  end
end
