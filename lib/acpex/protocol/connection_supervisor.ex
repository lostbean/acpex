defmodule ACPex.Protocol.ConnectionSupervisor do
  @moduledoc """
  DynamicSupervisor that manages all active ACP connections.

  This is the top-level supervisor for all connection processes in the ACPex
  application. It provides:

  - Dynamic creation of agent and client connections
  - Fault isolation between different connections
  - Named process for easy access throughout the application

  ## Supervision Tree

      ACPex.Application
      └── ConnectionSupervisor
          ├── Connection (agent_1)
          │   └── SessionSupervisor
          │       ├── Session
          │       └── ...
          ├── Connection (client_1)
          │   └── SessionSupervisor
          │       └── ...
          └── ...

  ## Usage

  The ConnectionSupervisor is automatically started by `ACPex.Application`.
  Connections are created via `ACPex.start_agent/3` or `ACPex.start_client/3`,
  which internally call `start_connection/1`.

  """
  use DynamicSupervisor

  alias ACPex.Protocol.Connection

  @doc """
  Starts the ConnectionSupervisor.

  This is typically called automatically by `ACPex.Application` during
  application startup.
  """
  @spec start_link(term()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new connection under this supervisor.

  ## Options

  See `ACPex.Protocol.Connection.start_link/1` for available options.

  ## Examples

      ConnectionSupervisor.start_connection(
        handler_module: MyAgent,
        handler_args: [],
        role: :agent
      )

  """
  @spec start_connection(keyword()) :: DynamicSupervisor.on_start_child()
  def start_connection(opts) do
    spec = {Connection, opts}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end
end
