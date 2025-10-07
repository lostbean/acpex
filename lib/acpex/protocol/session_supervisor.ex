defmodule ACPex.Protocol.SessionSupervisor do
  @moduledoc """
  DynamicSupervisor that manages all active sessions for a single connection.

  Each connection has its own SessionSupervisor instance, which dynamically
  spawns and monitors Session processes. This provides:

  - Isolated fault tolerance (a session crash doesn't affect other sessions)
  - Dynamic session creation as needed
  - Automatic cleanup of terminated sessions

  ## Supervision Strategy

  Uses a `:one_for_one` strategy, meaning if a session crashes, only that
  specific session is restarted, not all sessions.

  ## Session Lifecycle

  1. Connection receives `session/new` request
  2. Connection calls `start_session/4`
  3. SessionSupervisor spawns a new Session process
  4. Session registers itself with the Connection
  5. Session handles messages until terminated

  """
  use DynamicSupervisor

  alias ACPex.Protocol.Session

  @doc """
  Starts a new SessionSupervisor.

  Typically started automatically by a Connection process.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    DynamicSupervisor.start_link(__MODULE__, opts)
  end

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a new session under this supervisor.

  ## Parameters

    * `sup` - PID of the SessionSupervisor
    * `handler_module` - Module implementing the protocol handler
    * `initial_handler_state` - Initial state for the handler
    * `transport_pid` - PID of the transport process
    * `session_id` - (optional) Use this session_id instead of generating a new one

  ## Returns

  `{:ok, session_pid}` on success, or `{:error, reason}` on failure.
  """
  @spec start_session(pid(), module(), term(), pid(), String.t() | nil) ::
          DynamicSupervisor.on_start_child()
  def start_session(sup, handler_module, initial_handler_state, transport_pid, session_id \\ nil) do
    opts = %{
      handler_module: handler_module,
      initial_handler_state: initial_handler_state,
      transport_pid: transport_pid
    }

    # Add session_id only if provided
    opts = if session_id, do: Map.put(opts, :session_id, session_id), else: opts

    spec = {Session, opts}

    DynamicSupervisor.start_child(sup, spec)
  end
end
