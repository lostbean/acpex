defmodule ACPex.Transport.Stdio do
  @moduledoc """
  Manages stdio transport, message framing, and parsing.
  """
  use GenServer
  require Logger

  defstruct port: nil,
            parent: nil,
            buffer: ""

  def start_link(parent, opts \\ []) do
    GenServer.start_link(__MODULE__, {parent, opts})
  end

  @impl true
  def init({parent, opts}) do
    port_opts = Keyword.get(opts, :port_opts, {:fd, 0, 1})
    port = Port.open(port_opts, [:binary, :eof])
    {:ok, %__MODULE__{port: port, parent: parent}}
  end

  @impl true
  def handle_info({:send_message, message}, state) do
    json = Jason.encode!(message)
    frame = "Content-Length: " <> Integer.to_string(byte_size(json)) <> "\r\n\r\n" <> json
    Port.command(state.port, frame)
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    state = process_incoming_data(state, data)
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, :eof}, state) do
    send(state.parent, {:transport_closed})
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port do
      Port.close(state.port)
    end

    :ok
  end

  # Private Message Parsing

  defp process_incoming_data(state, new_data) do
    buffer = state.buffer <> new_data

    case parse_message(buffer) do
      {:ok, message, rest} ->
        send(state.parent, {:message, message})
        # Continue processing the rest of the buffer
        process_incoming_data(%{state | buffer: rest}, "")

      {:incomplete, _} ->
        %{state | buffer: buffer}

      {:error, reason} ->
        Logger.error("Failed to parse message: #{inspect(reason)}")
        # Clear buffer to prevent getting stuck
        %{state | buffer: ""}
    end
  end

  defp parse_message(buffer) do
    case :binary.split(buffer, "\r\n\r\n") do
      [headers, rest] ->
        parse_body(rest, parse_content_length(headers))

      [_] ->
        {:incomplete, buffer}
    end
  end

  defp parse_body(rest, {:ok, length}) when byte_size(rest) >= length do
    <<json::binary-size(length), remaining::binary>> = rest

    case Jason.decode(json) do
      {:ok, message} -> {:ok, message, remaining}
      {:error, reason} -> {:error, {:invalid_json, reason}}
    end
  end

  defp parse_body(_rest, {:ok, _length}), do: {:incomplete, nil}
  defp parse_body(_rest, :error), do: {:error, :invalid_headers}

  defp parse_content_length(headers) do
    headers
    |> String.split("\r\n")
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
end
