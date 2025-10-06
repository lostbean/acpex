defmodule ACPex.Protocol.SessionSupervisor do
  @moduledoc """
  Supervises all active sessions for a single connection.
  """
  use DynamicSupervisor

  alias ACPex.Protocol.Session

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_session(sup, handler_module, initial_handler_state, transport_pid) do
    spec = {
      Session,
      %{
        handler_module: handler_module,
        initial_handler_state: initial_handler_state,
        transport_pid: transport_pid
      }
    }

    DynamicSupervisor.start_child(sup, spec)
  end
end
