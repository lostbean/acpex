defmodule ACPex.Protocol.ConnectionSupervisor do
  @moduledoc """
  Supervises all active ACP connections.
  """
  use DynamicSupervisor

  alias ACPex.Protocol.Connection

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_connection(opts) do
    spec = {Connection, opts}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
