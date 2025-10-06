defmodule ACPex do
  @moduledoc """
  ACP (Agent Client Protocol) implementation for Elixir.

  ## Which ACP Is This?

  **IMPORTANT**: There are two different protocols that use the "ACP" acronym:

  1. **Agent Communication Protocol** (agentcommunicationprotocol.dev) - A REST-based
     protocol for inter-agent communication across distributed AI systems.

  2. **Agent Client Protocol** (agentclientprotocol.com) - A JSON-RPC based protocol
     for communication between code editors and local AI coding agents.

  **This library implements #2** - the JSON-RPC based protocol from Zed Industries
  for editor-to-agent communication over stdio. If you're looking to build distributed
  AI agent networks, this is not the library you need.

  ## Overview

  The Agent Client Protocol enables code editors to communicate with AI coding agents
  through a standardized interface, similar to how the Language Server Protocol (LSP)
  works for language servers.

  ## Usage

  To create a client that connects to an agent:

      defmodule MyEditor.ACPClient do
        @behaviour ACPex.Client

        def init(_args) do
          {:ok, %{sessions: %{}}}
        end

        def handle_session_update(notification, state) do
          # Handle updates from the agent
          IO.inspect(notification, label: "Agent update")
          {:noreply, state}
        end

        def handle_read_text_file(request, state) do
          case File.read(request.path) do
            {:ok, content} ->
              response = %{content: content}
              {:ok, response, state}
            {:error, reason} ->
              {:error, %{code: -32001, message: "File read error"}, state}
          end
        end

        # Implement other required callbacks...
      end

      # Start the client
      {:ok, pid} = ACPex.start_client(MyEditor.ACPClient, [])

  """

  alias ACPex.Protocol.ConnectionSupervisor

  @type start_option :: {:name, atom()} | {:agent_path, String.t()} | {:agent_args, [String.t()]}
  @type start_result :: {:ok, pid()} | {:error, term()}

  @doc """
  Starts a new ACP client connection.

  The client will spawn an agent process and communicate with it over stdio.

  ## Options

    * `:name` - Register the connection with a name
    * `:agent_path` - Path to the agent executable (required)
    * `:agent_args` - List of command-line arguments to pass to the agent (optional, agent-specific)

  ## Examples

      # Basic usage
      {:ok, pid} = ACPex.start_client(MyClient, [],
        agent_path: "/path/to/agent"
      )

      # With agent-specific arguments (e.g., Gemini CLI)
      {:ok, pid} = ACPex.start_client(MyClient, [],
        agent_path: "/usr/bin/gemini",
        agent_args: ["--experimental-acp"]
      )

  """
  @spec start_client(module(), term(), [start_option()]) :: start_result()
  def start_client(client_module, init_args, opts \\ []) do
    ConnectionSupervisor.start_connection(
      handler_module: client_module,
      handler_args: init_args,
      role: :client,
      opts: opts
    )
  end

  @doc """
  Starts a new ACP agent connection.

  The agent will communicate with a client (typically a code editor) over stdio.

  ## Examples

      {:ok, pid} = ACPex.start_agent(MyAgent, [])

  """
  @spec start_agent(module(), term(), [start_option()]) :: start_result()
  def start_agent(agent_module, init_args, opts \\ []) do
    ConnectionSupervisor.start_connection(
      handler_module: agent_module,
      handler_args: init_args,
      role: :agent,
      opts: opts
    )
  end
end
