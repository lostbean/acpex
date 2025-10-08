# Getting Started with ACPex

ACPex is an Elixir implementation of the Agent Client Protocol (ACP), enabling
code editors to communicate with AI coding agents through a standardized
interface.

## Which ACP Is This?

**IMPORTANT**: There are two different protocols with the "ACP" acronym:

1. **Agent Communication Protocol** (agentcommunicationprotocol.dev) - A
   REST-based protocol for inter-agent communication
2. **Agent Client Protocol** (agentclientprotocol.com) - A JSON-RPC based
   protocol for editor-to-agent communication

**ACPex implements #2** - the JSON-RPC based protocol from Zed Industries. If
you're building distributed AI agent networks, this is not the library you need.

## Installation

Add `acpex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:acpex, "~> 0.1"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Quick Start: Building a Simple Agent

Let's build a simple "echo" agent that responds to prompts by repeating them
back:

### 1. Create your agent module

```elixir
defmodule MyApp.EchoAgent do
  @behaviour ACPex.Agent

  # Initialize the agent with an empty state
  def init(_args) do
    {:ok, %{}}
  end

  # Handle the initialization handshake
  def handle_initialize(_request, state) do
    response = %ACPex.Schema.Connection.InitializeResponse{
      protocol_version: 1,
      agent_capabilities: %{
        "sessions" => %{"new" => true}
      },
      meta: %{
        "name" => "EchoAgent",
        "version" => "1.0.0"
      }
    }
    {:ok, response, state}
  end

  # Handle authentication (not required for this simple agent)
  def handle_authenticate(_request, state) do
    response = %ACPex.Schema.Connection.AuthenticateResponse{}
    {:ok, response, state}
  end

  # Handle session creation
  def handle_new_session(_request, state) do
    response = %ACPex.Schema.Session.NewResponse{
      session_id: "session_#{:erlang.unique_integer([:positive])}"
    }
    {:ok, response, state}
  end

  # Handle loading existing sessions (not implemented in this simple example)
  def handle_load_session(_request, state) do
    {:error, %{code: -32001, message: "Session loading not supported"}, state}
  end

  # Handle user prompts
  def handle_prompt(request, state) do
    # Extract the text from the prompt
    text = extract_text(request.content)

    # Echo it back
    response = %ACPex.Schema.Session.PromptResponse{
      content: [
        %ACPex.Schema.Types.ContentBlock.Text{
          text: "You said: #{text}"
        }
      ],
      stop_reason: "done"
    }

    {:ok, response, state}
  end

  # Handle cancellation
  def handle_cancel(_notification, state) do
    {:noreply, state}
  end

  # Helper to extract text from content blocks
  defp extract_text(content) when is_list(content) do
    content
    |> Enum.filter(&match?(%ACPex.Schema.Types.ContentBlock.Text{}, &1))
    |> Enum.map(& &1.text)
    |> Enum.join(" ")
  end
end
```

### 2. Start your agent

```elixir
# In your application or script
{:ok, pid} = ACPex.start_agent(MyApp.EchoAgent, [])
```

The agent will now communicate with a client over stdio using the Agent Client
Protocol.

### 3. Test with an ACP client

You can test your agent with any ACP-compatible client. For example, using the
claude-code-acp CLI:

```bash
# Install claude-code-acp (if you have Node.js/npm)
npm install -g @zed-industries/claude-code-acp

# Run your agent with an Elixir script
elixir -S mix run -e "ACPex.start_agent(MyApp.EchoAgent, [])" --no-halt
```

## Quick Start: Building a Simple Client

Now let's build a simple client that can connect to an agent:

### 1. Create your client module

```elixir
defmodule MyApp.EditorClient do
  @behaviour ACPex.Client

  # Initialize the client
  def init(_args) do
    {:ok, %{files: %{}, terminals: %{}}}
  end

  # Handle session updates from the agent
  def handle_session_update(notification, state) do
    IO.inspect(notification, label: "Session Update")
    {:noreply, state}
  end

  # Handle file read requests
  def handle_fs_read_text_file(request, state) do
    case File.read(request.path) do
      {:ok, content} ->
        response = %ACPex.Schema.Client.FsReadTextFileResponse{
          content: content
        }
        {:ok, response, state}

      {:error, _reason} ->
        {:error, %{code: -32001, message: "File not found"}, state}
    end
  end

  # Handle file write requests
  def handle_fs_write_text_file(request, state) do
    case File.write(request.path, request.content) do
      :ok ->
        response = %ACPex.Schema.Client.FsWriteTextFileResponse{}
        {:ok, response, state}

      {:error, _reason} ->
        {:error, %{code: -32002, message: "Failed to write file"}, state}
    end
  end

  # Handle terminal operations (stub implementations)
  def handle_terminal_create(_request, state) do
    terminal_id = "term_#{:erlang.unique_integer([:positive])}"
    response = %ACPex.Schema.Client.Terminal.CreateResponse{
      terminal_id: terminal_id
    }
    {:ok, response, state}
  end

  def handle_terminal_output(_request, state) do
    response = %ACPex.Schema.Client.Terminal.OutputResponse{output: ""}
    {:ok, response, state}
  end

  def handle_terminal_wait_for_exit(_request, state) do
    response = %ACPex.Schema.Client.Terminal.WaitForExitResponse{
      exit_status: %{code: 0}
    }
    {:ok, response, state}
  end

  def handle_terminal_kill(_request, state) do
    response = %ACPex.Schema.Client.Terminal.KillResponse{}
    {:ok, response, state}
  end

  def handle_terminal_release(_request, state) do
    response = %ACPex.Schema.Client.Terminal.ReleaseResponse{}
    {:ok, response, state}
  end
end
```

### 2. Start your client and connect to an agent

```elixir
# Connect to an agent executable
{:ok, pid} = ACPex.start_client(
  MyApp.EditorClient,
  [],
  agent_path: "/path/to/your/agent",
  agent_args: []  # Optional agent-specific arguments
)
```

## Next Steps

- **Building Agents**: See the [Building Agents](building_agents.md) guide for
  advanced agent features
- **Building Clients**: See the [Building Clients](building_clients.md) guide
  for advanced client features
- **Protocol Overview**: See the [Protocol Overview](protocol_overview.md) guide
  to understand the ACP protocol

## Key Concepts

### Behaviours

ACPex uses Elixir behaviours to define clear contracts:

- `ACPex.Agent` - Implement this to create an AI agent
- `ACPex.Client` - Implement this to create a client (e.g., code editor plugin)

### Schemas

All protocol messages use typed Ecto schemas from `ACPex.Schema.*`, providing:

- **Type safety** - Pattern matching on structs catches errors at compile time
- **Auto-completion** - IDEs can suggest field names
- **Automatic case conversion** - snake_case in Elixir ↔ camelCase in JSON

### OTP Architecture

ACPex is built on OTP principles:

- **GenServers** manage connection and session state
- **Supervisors** provide fault tolerance
- **Process isolation** ensures sessions don't interfere with each other

## Common Patterns

### Sending notifications from an agent

Agents can send streaming updates to clients during prompt processing:

```elixir
def handle_prompt(request, state) do
  # Send a thought notification
  ACPex.Protocol.Connection.send_notification(
    self(),
    "session/update",
    %ACPex.Schema.Session.UpdateNotification{
      session_id: request.session_id,
      update: %{kind: "thought", content: "Processing your request..."}
    }
  )

  # ... process the prompt ...

  {:ok, response, state}
end
```

### Making requests to the client from an agent

Agents can request file operations or terminal access:

```elixir
def handle_prompt(request, state) do
  # Request file content from the client
  {:ok, response} = ACPex.Protocol.Connection.send_request(
    self(),
    "fs/read_text_file",
    %ACPex.Schema.Client.FsReadTextFileRequest{
      path: "/path/to/file.txt"
    }
  )

  # Use the file content
  content = response.content

  # ... process the content ...
end
```

## Resources

- **Official ACP Specification**: https://agentclientprotocol.com/
- **API Documentation**: See the generated HexDocs
- **Examples**: Check the `examples/` directory in the repository

## Troubleshooting

### Agent not responding

- Verify the agent process is running
- Check logs with `Logger.debug/1` (set `config :logger, level: :debug`)
- Ensure the agent executable path is correct

### Protocol errors

- Verify protocol version compatibility (currently version 1)
- Check that all required callbacks are implemented
- Validate message structure against the official schema

## License

ACPex is released under the [Apache 2.0 License](../LICENSE).
