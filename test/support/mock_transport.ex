defmodule ACPex.Test.MockTransport do
  @moduledoc """
  A mock transport for testing ACPex.Connection.

  Instead of using stdio, this transport sends messages to the test process.
  It mimics the framing logic of the real Stdio transport.
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
  def handle_info({:send_message, message}, state) do
    json = Jason.encode!(message)
    frame = "Content-Length: " <> Integer.to_string(byte_size(json)) <> "\r\n\r\n" <> json
    send(state.parent, {:transport_data, frame})
    {:noreply, state}
  end
end
