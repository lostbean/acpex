# ACPex Usage Rules

ACPex is an Elixir implementation of the **Agent Client Protocol (ACP)** - a
JSON-RPC protocol for editor-to-agent communication over stdio.

## Critical Distinction

**This is NOT the Agent Communication Protocol
(agentcommunicationprotocol.dev)**. This implements the JSON-RPC based Agent
Client Protocol from agentclientprotocol.com for editor-to-AI-agent
communication.

## Core Architecture

### OTP Supervision Tree

```
ACPex.Application
└── ConnectionSupervisor
    └── Connection (GenServer)
        ├── Transport (Ndjson)
        └── SessionSupervisor
            └── Session (GenServer) per conversation
```

### Roles

- **Agent**: AI coding assistant (implements `ACPex.Agent`)
- **Client**: Code editor/IDE (implements `ACPex.Client`)

## Schema System

### Type-Safe Structs

All protocol messages use Ecto schemas from `ACPex.Schema.*`:

- Compile-time type checking via pattern matching
- Auto-completion support

### Case Conversion Rules

**Elixir (snake_case)** ↔ **JSON (camelCase)** handled automatically via
`:source` field mappings:

```elixir
# Elixir
%InitializeRequest{protocol_version: 1, client_info: %{}}

# JSON
{"protocolVersion": 1, "clientInfo": {}}
```

**Always use snake_case in Elixir code**. The codec handles JSON conversion.

## Implementation Patterns

### Starting an Agent

```elixir
defmodule MyAgent do
  @behaviour ACPex.Agent

  def init(_args), do: {:ok, %{}}

  def handle_initialize(request, state) do
    response = %ACPex.Schema.Connection.InitializeResponse{
      protocol_version: 1,
      agent_capabilities: %{"sessions" => %{"new" => true}}
    }
    {:ok, response, state}
  end

  # Implement other callbacks...
end

{:ok, pid} = ACPex.start_agent(MyAgent, [])
```

### Starting a Client

```elixir
defmodule MyClient do
  @behaviour ACPex.Client

  def init(_args), do: {:ok, %{}}

  def handle_session_update(notification, state) do
    # Process streaming updates
    {:noreply, state}
  end

  def handle_fs_read_text_file(request, state) do
    case File.read(request.path) do
      {:ok, content} ->
        response = %ACPex.Schema.Client.FsReadTextFileResponse{content: content}
        {:ok, response, state}
      {:error, _} ->
        {:error, %{code: -32001, message: "File not found"}, state}
    end
  end

  # Implement other callbacks...
end

{:ok, pid} = ACPex.start_client(MyClient, [],
  agent_path: "/path/to/agent",
  agent_args: []  # Optional agent-specific args
)
```

## Message Flow

### Connection Lifecycle

1. Client sends `initialize` request → Agent responds with capabilities
2. (Optional) Client sends `authenticate` request
3. Client creates sessions with `session/new`
4. Client sends prompts with `session/prompt`
5. Agent streams updates via `session/update` notifications

### Bidirectional Communication

**Client → Agent** (requests):

- `initialize`, `authenticate`, `session/new`, `session/prompt`

**Agent → Client** (requests):

- `fs/read_text_file`, `fs/write_text_file`
- `terminal/create`, `terminal/output`, `terminal/wait_for_exit`,
  `terminal/kill`, `terminal/release`

**Agent → Client** (notifications):

- `session/update` (streaming updates during processing)

## Common Operations

### Sending Requests (from handler code)

```elixir
# Must be called from within handler module (self() is Connection pid)
{:ok, response} = ACPex.Protocol.Connection.send_request(
  self(),
  "fs/read_text_file",
  %ACPex.Schema.Client.FsReadTextFileRequest{path: "/path/to/file"},
  30_000  # timeout in ms
)
```

### Sending Notifications (from agent)

```elixir
ACPex.Protocol.Connection.send_notification(
  self(),
  "session/update",
  %ACPex.Schema.Session.UpdateNotification{
    session_id: session_id,
    update: %{"kind" => "agent_thought_chunk", "content" => %{"thought" => "..."}}
  }
)
```

### Callback Return Values

**Requests** (return response or error):

```elixir
{:ok, response_struct, new_state}
{:error, %{code: integer, message: string}, new_state}
```

**Notifications** (no response):

```elixir
{:noreply, new_state}
```

## Update Types

Agents send these during `session/prompt` processing:

- `agent_thought_chunk` - Reasoning/planning
- `agent_message_chunk` - Response content
- `tool_call` - Tool usage announcement
- `tool_call_update` - Tool execution result
- `plan` - Multi-step plan
- `available_commands_update` - Available commands changed
- `current_mode_update` - Mode changed

## Error Codes

### Standard JSON-RPC

- `-32700`: Parse error
- `-32600`: Invalid request
- `-32601`: Method not found
- `-32602`: Invalid params
- `-32603`: Internal error

### Protocol-Specific

- `-32001`: Resource not found
- `-32002`: Permission denied
- `-32003`: Invalid state
- `-32004`: Capability not supported

## Best Practices

### For Agents

- Stream updates frequently during long operations via `session/update`
- Check capabilities before requesting client features
- Validate file paths before requesting reads/writes
- Handle `session/cancel` notifications to stop processing
- Return proper `stopReason` in `PromptResponse`: `"done"`, `"cancelled"`,
  `"length"`, `"error"`

### For Clients

- Validate all file/terminal requests before executing (sandbox to workspace)
- Implement permission checks for destructive operations
- Handle streaming updates efficiently (batch UI updates)
- Timeout long-running requests appropriately
- Implement all required callbacks (behaviour enforces this)

### General

- Use typed schemas for all protocol messages (not raw maps)
- Sessions maintain conversation state - one session per conversation thread

## Integration with MCP

ACP complements the Model Context Protocol (MCP):

- **ACP**: Editor ↔ Agent communication
- **MCP**: Agent ↔ Tools/Data communication

Agents may connect to MCP servers (specified in `session/new` via `mcpServers`
param).

## Content Blocks

Protocol supports multiple content types in prompts and responses:

- `text` - Plain text
- `image` - Base64 encoded images
- `audio` - Base64 encoded audio
- `resource` - File content with URI and MIME type
- `resource_link` - Reference to external resource

## Common Gotchas

1. **Don't use raw maps** - Always use typed schema structs
2. **self() is Connection pid** - When calling
   `send_request`/`send_notification` from handlers
3. **Requests need timeout** - Default is 5 seconds, long operations need
   explicit timeout
4. **Protocol version matters** - Always check in `handle_initialize`
5. **Sessions are isolated** - Each has its own process and state
6. **agent_args is optional** - Some agents (like Gemini CLI) need specific
   arguments
7. **Capabilities are negotiated** - Don't assume features are available

## Resources

- Spec: https://agentclientprotocol.com
- HexDocs: https://hexdocs.pm/acpex
- Livebook example: `livebooks/usage.livemd`
