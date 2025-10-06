defmodule ACPex.Transport.Ndjson do
  @moduledoc """
  Newline-delimited JSON (ndjson) transport for ACP over stdio.

  The Agent Client Protocol uses newline-delimited JSON for message framing.
  Each JSON-RPC message is encoded as a single line terminated by `\\n`.

  This is the official ACP transport mechanism as specified in the protocol.

  ## Message Format

  Messages are sent as complete JSON objects, one per line:

      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}\\n
      {"jsonrpc":"2.0","id":1,"result":{...}}\\n

  ## References

  - ACP Specification: https://agentclientprotocol.com
  - NDJSON Specification: https://github.com/ndjson/ndjson-spec
  """
  use GenServer
  require Logger

  defstruct port: nil,
            parent: nil,
            buffer: ""

  @doc """
  Starts a new ndjson transport process.

  ## Parameters

    * `parent` - The parent process (typically ACPex.Protocol.Connection)
    * `opts` - Transport options (see below)

  ## Options

    * `:port_opts` - Erlang port options (default: `{:fd, 0, 1}` for stdio)
    * `:port_args` - Command-line arguments when spawning executable
  """
  def start_link(parent, opts \\ []) do
    GenServer.start_link(__MODULE__, {parent, opts})
  end

  @impl true
  def init({parent, opts}) do
    port_opts = Keyword.get(opts, :port_opts, {:fd, 0, 1})
    port_args = Keyword.get(opts, :port_args, [])

    Logger.debug(
      "Transport initializing with port_opts=#{inspect(port_opts)}, port_args=#{inspect(port_args)}"
    )

    # Build port options
    # - :binary for binary data mode
    # - :eof to receive EOF notifications
    # - :exit_status to get process exit codes
    # NOTE: We do NOT use :stderr_to_stdout because agents may output debug
    # messages to stderr that would pollute the JSON-RPC protocol stream
    base_opts = [:binary, :eof, :exit_status]

    arg_opts = if port_args != [], do: [{:args, port_args}], else: []

    # Inherit environment variables when spawning executable
    env_opts =
      case port_opts do
        {:spawn_executable, _} ->
          current_env =
            System.get_env()
            |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

          [{:env, current_env}]

        _ ->
          []
      end

    full_opts = base_opts ++ arg_opts ++ env_opts

    Logger.debug("Opening port with opts: #{inspect(full_opts)}")
    port = Port.open(port_opts, full_opts)
    Logger.info("Transport port opened successfully: #{inspect(port)}")

    {:ok, %__MODULE__{port: port, parent: parent}}
  end

  @impl true
  def handle_info({:send_message, message}, state) do
    # Encode message as JSON and append newline
    json = Jason.encode!(message)

    Logger.debug(
      "→ Sending message: #{String.slice(json, 0, 200)}#{if String.length(json) > 200, do: "...", else: ""}"
    )

    Port.command(state.port, json <> "\n")
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    Logger.debug(
      "← Received data (#{byte_size(data)} bytes): #{String.slice(data, 0, 200)}#{if byte_size(data) > 200, do: "...", else: ""}"
    )

    state = process_incoming_data(state, data)
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, :eof}, state) do
    Logger.warning("Port EOF received")
    send(state.parent, {:transport_closed})
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({port, {:exit_status, status}}, state) when port == state.port do
    Logger.error("Port exited with status: #{status}")
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

  # Private Functions

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
