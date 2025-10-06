defmodule ACPex.Protocol.SessionSupervisor do
  @moduledoc """
  Supervises all active sessions for a single connection.
  """
  use DynamicSupervisor

  alias ACPex.Protocol.Session

  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__)
  end

  @impl true
  def init(handler_module: handler_module) do
    spec = {
      __MODULE__,
      strategy: :one_for_one, extra_arguments: [handler_module: handler_module]
    }

    DynamicSupervisor.init(spec)
  end

  def start_session(sup, initial_handler_state) do
    # The handler_module was passed down from the Connection
    [handler_module: handler_module] = DynamicSupervisor.get_init_args(sup)

    spec = {
      Session,
      %{handler_module: handler_module, initial_handler_state: initial_handler_state}
    }

    DynamicSupervisor.start_child(sup, spec)
  end
end
