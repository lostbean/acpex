defmodule ACPex.Transport.Ndjson do
  @moduledoc """
  Newline-delimited JSON (ndjson) transport for ACP using Exile.

  The Agent Client Protocol uses newline-delimited JSON for message framing.
  Each JSON-RPC message is encoded as a single line terminated by `\\n`.

  This transport uses the Exile library for robust external process management with:
  - Automatic back-pressure to prevent memory exhaustion
  - Non-blocking asynchronous I/O
  - Prevention of zombie processes
  - Proper stream handling for bidirectional communication

  ## Message Format

  Messages are sent as complete JSON objects, one per line:

      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}\\n
      {"jsonrpc":"2.0","id":1,"result":{...}}\\n

  ## References

  - ACP Specification: https://agentclientprotocol.com
  - NDJSON Specification: https://github.com/ndjson/ndjson-spec
  - Exile Library: https://github.com/akash-akya/exile
  """
  use GenServer
  require Logger

  defstruct parent: nil,
            buffer: "",
            stream_task: nil,
            input_collector: nil

  @doc """
  Starts a new ndjson transport process.

  ## Parameters

    * `parent` - The parent process (typically ACPex.Protocol.Connection)
    * `opts` - Transport options (see below)

  ## Options

    * `:port_opts` - Command specification for Exile
    * `:port_args` - Command-line arguments
  """
  def start_link(parent, opts \\ []) do
    GenServer.start_link(__MODULE__, {parent, opts})
  end

  @impl true
  def init({parent, opts}) do
    # Get command and args
    cmd_spec = Keyword.get(opts, :port_opts)
    args = Keyword.get(opts, :port_args, [])

    Logger.debug("Transport initializing with cmd=#{inspect(cmd_spec)}, args=#{inspect(args)}")

    # Build command list for Exile
    cmd =
      case cmd_spec do
        {:spawn_executable, executable} ->
          [executable | args]

        {:fd, _, _} ->
          # For stdio mode (agent), use cat to pass through stdin/stdout
          ["cat"]

        _ ->
          raise "Unsupported port_opts: #{inspect(cmd_spec)}"
      end

    Logger.debug("Starting Exile stream with command: #{inspect(cmd)}")

    transport_pid = self()

    # Create an input collector that can receive messages
    {:ok, input_collector} = Agent.start_link(fn -> [] end)

    # Start the stream in a separate task
    stream_task =
      Task.async(fn ->
        run_exile_stream(transport_pid, input_collector, cmd)
      end)

    Logger.info("Exile stream started successfully")

    {:ok, %__MODULE__{parent: parent, stream_task: stream_task, input_collector: input_collector}}
  end

  @impl true
  def handle_info({:send_message, message}, state) do
    # Encode message as JSON and append newline
    json = Jason.encode!(message)

    Logger.debug(
      "→ Sending message: #{String.slice(json, 0, 200)}#{if String.length(json) > 200, do: "...", else: ""}"
    )

    # Add to input queue
    Agent.update(state.input_collector, fn queue -> queue ++ [json <> "\n"] end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:exile_data, data}, state) do
    Logger.debug(
      "← Received data (#{byte_size(data)} bytes): #{String.slice(data, 0, 200)}#{if byte_size(data) > 200, do: "...", else: ""}"
    )

    new_state = process_incoming_data(state, data)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:exile_closed, status}, state) do
    Logger.info("Exile stream closed with status: #{inspect(status)}")
    send(state.parent, {:transport_closed})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    # Task completed
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.error("Exile stream task died: #{inspect(reason)}")
    send(state.parent, {:transport_closed})
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.input_collector do
      Agent.stop(state.input_collector)
    end

    :ok
  end

  # Run the Exile stream with bidirectional communication
  defp run_exile_stream(transport_pid, input_collector, cmd) do
    # Create an input stream that pulls from the collector
    input_stream = create_input_stream(input_collector)

    try do
      # Start the Exile stream with input
      cmd
      |> Exile.stream!(input: input_stream, stderr: :disable)
      |> Stream.each(fn data ->
        send(transport_pid, {:exile_data, data})
      end)
      |> Stream.run()

      send(transport_pid, {:exile_closed, 0})
    rescue
      e in Exile.Stream.AbnormalExit ->
        Logger.error("Exile process exited abnormally: #{inspect(e)}")
        send(transport_pid, {:exile_closed, e.exit_status})
    catch
      kind, reason ->
        Logger.error("Exile stream error: #{kind} - #{inspect(reason)}")
        send(transport_pid, {:exile_closed, :error})
    end
  end

  defp create_input_stream(input_collector) do
    Stream.resource(
      fn -> input_collector end,
      fn collector ->
        collector
        |> Agent.get_and_update(fn
          [item | rest] -> {item, rest}
          [] -> {nil, []}
        end)
        |> handle_input_item(collector)
      end,
      fn _ -> :ok end
    )
  end

  defp handle_input_item(nil, collector) do
    # No data available, wait a bit
    Process.sleep(10)
    {[], collector}
  end

  defp handle_input_item(item, collector) do
    {[item], collector}
  end

  # Private Functions - Message Processing

  defp process_incoming_data(state, new_data) do
    buffer = state.buffer <> new_data

    # Split by newlines - last element may be incomplete
    lines = String.split(buffer, "\n")
    {complete_lines, remaining} = Enum.split(lines, -1)

    # Process each complete line
    Enum.each(complete_lines, fn line ->
      # Skip empty lines
      unless line == "" do
        parse_and_send(line, state.parent)
      end
    end)

    # Keep the incomplete line in buffer
    %{state | buffer: List.first(remaining) || ""}
  end

  defp parse_and_send(line, parent) do
    case Jason.decode(line) do
      {:ok, message} ->
        Logger.debug(
          "✓ Parsed message: #{inspect(Map.take(message, ["id", "method", "jsonrpc"]))}"
        )

        send(parent, {:message, message})

      {:error, reason} ->
        Logger.error("Failed to parse JSON line: #{inspect(reason)}")
        Logger.debug("Invalid line: #{line}")
    end
  end
end
