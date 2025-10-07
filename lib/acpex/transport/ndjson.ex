defmodule ACPex.Transport.Ndjson do
  @moduledoc """
  Newline-delimited JSON (ndjson) transport for ACP using Erlang Ports.

  The Agent Client Protocol uses newline-delimited JSON for message framing.
  Each JSON-RPC message is encoded as a single line terminated by `\\n`.

  This transport uses native Erlang Ports for robust external process management with:
  - Line-buffered I/O for automatic message framing
  - Non-blocking asynchronous message passing
  - Automatic process cleanup on termination
  - Bidirectional communication over stdin/stdout

  ## Message Format

  Messages are sent as complete JSON objects, one per line:

      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}\\n
      {"jsonrpc":"2.0","id":1,"result":{...}}\\n

  ## References

  - ACP Specification: https://agentclientprotocol.com
  - NDJSON Specification: https://github.com/ndjson/ndjson-spec
  - Erlang Ports: https://www.erlang.org/doc/tutorial/c_port.html
  """
  use GenServer
  require Logger

  defstruct parent: nil,
            port: nil

  @doc """
  Starts a new ndjson transport process.

  ## Parameters

    * `parent` - The parent process (typically ACPex.Protocol.Connection)
    * `opts` - Transport options (see below)

  ## Options

    * `:port_opts` - Port command specification (e.g., `{:spawn_executable, path}`)
    * `:port_args` - Command-line arguments to pass to the executable
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

    # Open a Port for bidirectional communication
    port =
      try do
        Port.open(cmd_spec, [
          {:args, args},
          :binary,
          :exit_status,
          {:line, 1024 * 1024},
          # Allow up to 1MB lines
          :use_stdio,
          :hide
        ])
      rescue
        e ->
          Logger.error("Failed to open port: #{inspect(e)}")
          reraise e, __STACKTRACE__
      end

    Logger.info("Port opened successfully")

    {:ok, %__MODULE__{parent: parent, port: port}}
  end

  @impl true
  def handle_info({:send_message, message}, state) do
    # Encode message as JSON and append newline
    json = Jason.encode!(message)

    Logger.debug(
      "→ Sending message: #{String.slice(json, 0, 200)}#{if String.length(json) > 200, do: "...", else: ""}"
    )

    # Send to the port
    Port.command(state.port, json <> "\n")
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:data, {:eol, data}}}, %{port: port} = state) do
    Logger.debug(
      "← Received data (#{byte_size(data)} bytes): #{String.slice(data, 0, 200)}#{if byte_size(data) > 200, do: "...", else: ""}"
    )

    # Port with {:packet, :line} gives us one complete line (without the \n)
    # Parse and send it directly
    parse_and_send(data, state.parent)
    {:noreply, state}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    case status do
      0 ->
        Logger.info("Agent process exited normally")

      code ->
        Logger.error("""
        Agent process exited with code: #{code}

        Common causes:
        - Agent timed out waiting for an 'initialize' message
        - Missing or invalid ANTHROPIC_API_KEY environment variable
        - Agent encountered an internal error
        - Agent binary is incompatible or corrupted
        """)
    end

    send(state.parent, {:transport_closed})
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Close the port if it's still open
    if state.port && Port.info(state.port) do
      Port.close(state.port)
    end

    :ok
  end

  # Private Functions - Message Processing

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
