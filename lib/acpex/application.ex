defmodule ACPex.Application do
  @moduledoc """
  The main OTP application for ACPex.

  This application module starts the top-level supervision tree for the ACPex
  library. It is automatically started when the application is loaded.

  ## Supervision Tree

  The application starts a single supervisor that manages the
  `ConnectionSupervisor`, which in turn manages all active agent and client
  connections:

      ACPex.Application (Application)
      └── ACPex.Supervisor (Supervisor)
          └── ConnectionSupervisor (DynamicSupervisor)
              ├── Connection (GenServer)
              └── ...

  ## Starting the Application

  The application is started automatically when included as a dependency.
  No manual configuration is required unless you want to customize specific
  behaviors.

  ## Examples

      # In your mix.exs
      def deps do
        [
          {:acpex, "~> 0.1"}
        ]
      end

  """
  use Application

  alias ACPex.Protocol.ConnectionSupervisor

  @impl true
  @doc """
  Starts the ACPex application and its supervision tree.

  This callback is invoked automatically by the Erlang VM when the application
  starts. It initializes the ConnectionSupervisor, which will then be ready to
  spawn agent and client connections on demand.
  """
  @spec start(Application.start_type(), term()) ::
          {:ok, pid()} | {:ok, pid(), term()} | {:error, term()}
  def start(_type, _args) do
    children = [
      {ConnectionSupervisor, name: ConnectionSupervisor}
    ]

    opts = [strategy: :one_for_one, name: ACPex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
