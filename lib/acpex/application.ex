defmodule ACPex.Application do
  @moduledoc """
  The main OTP application for ACPex.
  """
  use Application

  alias ACPex.Protocol.ConnectionSupervisor

  @impl true
  def start(_type, _args) do
    children = [
      {ConnectionSupervisor, name: ConnectionSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ACPex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
