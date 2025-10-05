defmodule ACPex.Test.MockTransport do
  @moduledoc """
  A mock transport for testing ACPex.Connection.

  Instead of using stdio, this transport sends messages to the test process.
  """
  use GenServer

  defstruct [:parent]

  def start_link(parent) do
    GenServer.start_link(__MODULE__, parent)
  end

  @impl true
  def init(parent) do
    {:ok, %__MODULE__{parent: parent}}
  end

  @impl true
  def handle_info({:send_data, data}, state) do
    send(state.parent, {:transport_data, data})
    {:noreply, state}
  end
end
