defmodule ACPex.Transport.Stdio do
  @moduledoc """
  Manages stdio transport for ACP communication using an Erlang port.

  This module handles non-blocking I/O with the agent process over
  standard input/output streams.
  """

  use GenServer
  require Logger

  defstruct [:port, :parent]

  def start_link(parent) do
    GenServer.start_link(__MODULE__, parent)
  end

  @impl true
  def init(parent) do
    port = Port.open({:fd, 0, 1}, [:binary, :eof])
    {:ok, %__MODULE__{port: port, parent: parent}}
  end

  @impl true
  def handle_info({:send_data, data}, state) do
    Port.command(state.port, data)
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, {:data, data}}, state) do
    send(state.parent, {:stdio_data, data})
    {:noreply, state}
  end

  @impl true
  def handle_info({_port, :eof}, state) do
    send(state.parent, {:stdio_closed})
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.port do
      Port.close(state.port)
    end

    :ok
  end
end
