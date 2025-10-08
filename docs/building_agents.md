# Building Agents with ACPex

This guide covers advanced topics for building AI coding agents using ACPex.

## Table of Contents

- [Overview](#overview)
- [The Agent Behaviour](#the-agent-behaviour)
- [Protocol Lifecycle](#protocol-lifecycle)
- [Session Management](#session-management)
- [Streaming Updates](#streaming-updates)
- [Making Client Requests](#making-client-requests)
- [Error Handling](#error-handling)
- [Advanced Patterns](#advanced-patterns)

## Overview

An ACP agent is an AI coding assistant that runs as a subprocess and
communicates with a code editor (the client) over stdin/stdout using JSON-RPC.
The agent:

1. Receives prompts from the user via the client
2. Processes those prompts (e.g., using an LLM)
3. Sends back streaming updates and final responses
4. Can request file system access and terminal operations from the client

## The Agent Behaviour

Every agent must implement the `ACPex.Agent` behaviour, which defines callbacks
for handling protocol messages:

```elixir
defmodule MyAgent do
  @behaviour ACPex.Agent

  @impl true
  def init(args), do: {:ok, %{}}

  @impl true
  def handle_initialize(request, state), do: {:ok, response, state}

  @impl true
  def handle_authenticate(request, state), do: {:ok, response, state}

  @impl true
  def handle_new_session(request, state), do: {:ok, response, state}

  @impl true
  def handle_load_session(request, state), do: {:error, error, state}

  @impl true
  def handle_prompt(request, state), do: {:ok, response, state}

  @impl true
  def handle_cancel(notification, state), do: {:noreply, state}
end
```

## Protocol Lifecycle

### 1. Initialization

The first message your agent receives will be `initialize`:

```elixir
def handle_initialize(request, state) do
  # request.protocol_version - The protocol version (currently 1)
  # request.client_info - Information about the client (name, version, etc.)
  # request.capabilities - What the client can do

  response = %ACPex.Schema.Connection.InitializeResponse{
    protocol_version: 1,
    agent_capabilities: %{
      "sessions" => %{
        "new" => true,      # Can create new sessions
        "load" => false     # Cannot load previous sessions
      },
      "mcp" => nil          # No MCP support
    },
    meta: %{
      "name" => "MyAgent",
      "version" => "1.0.0",
      "description" => "An example agent"
    }
  }

  {:ok, response, state}
end
```

### 2. Authentication (Optional)

If your agent requires authentication, advertise it in capabilities and handle
the `authenticate` request:

```elixir
def handle_initialize(request, state) do
  response = %ACPex.Schema.Connection.InitializeResponse{
    protocol_version: 1,
    agent_capabilities: %{...},
    authentication_methods: [
      %ACPex.Schema.Types.AuthMethod{
        id: "api_key",
        name: "API Key",
        description: "Provide your API key"
      }
    ]
  }
  {:ok, response, state}
end

def handle_authenticate(request, state) do
  # request.method_id - Which auth method was chosen
  # request.data - Authentication data (e.g., API key)

  case validate_api_key(request.data["api_key"]) do
    :ok ->
      response = %ACPex.Schema.Connection.AuthenticateResponse{}
      {:ok, response, state}

    :error ->
      {:error, %{code: -32001, message: "Invalid API key"}, state}
  end
end
```

### 3. Session Creation

After initialization, the client will create a session:

```elixir
def handle_new_session(request, state) do
  # request.cwd - The current working directory from the client
  # request.mcp_servers - List of MCP server configurations

  # Generate a unique session ID
  session_id = "session_#{:erlang.unique_integer([:positive])}"

  # Initialize session state
  session_state = %{
    history: [],
    context: %{},
    cwd: request.cwd,
    mcp_servers: request.mcp_servers
  }

  # Store session state
  new_state = put_in(state, [:sessions, session_id], session_state)

  response = %ACPex.Schema.Session.NewResponse{
    session_id: session_id
  }

  {:ok, response, new_state}
end
```

## Session Management

### Multiple Sessions

An agent can maintain multiple concurrent sessions:

```elixir
def init(_args) do
  {:ok, %{sessions: %{}}}
end

def handle_prompt(request, state) do
  session_id = request.session_id
  session_state = get_in(state, [:sessions, session_id])

  # Process the prompt with session context
  # ...

  # Update session state
  new_session_state = Map.update!(session_state, :history, &[request | &1])
  new_state = put_in(state, [:sessions, session_id], new_session_state)

  {:ok, response, new_state}
end
```

### Loading Previous Sessions

If your agent supports persisting sessions:

```elixir
def handle_initialize(request, state) do
  response = %ACPex.Schema.Connection.InitializeResponse{
    # ...
    agent_capabilities: %{
      "sessions" => %{
        "new" => true,
        "load" => true  # Advertise load support
      }
    }
  }
  {:ok, response, state}
end

def handle_load_session(request, state) do
  # request.session_id - The session to load

  case load_from_database(request.session_id) do
    {:ok, session_data} ->
      new_state = put_in(state, [:sessions, request.session_id], session_data)
      response = %{session_id: request.session_id}
      {:ok, response, new_state}

    {:error, :not_found} ->
      {:error, %{code: -32001, message: "Session not found"}, state}
  end
end
```

## Streaming Updates

Agents can send real-time updates while processing a prompt:

### Message Chunks

Stream the LLM's response as it's generated:

```elixir
def handle_prompt(request, state) do
  # Start streaming
  stream_llm_response(request.content, fn chunk ->
    send_update(request.session_id, %{
      kind: "agent_message_chunk",
      content: %{
        role: "assistant",
        content: [%{text: chunk}]
      }
    })
  end)

  # Final response
  response = %ACPex.Schema.Session.PromptResponse{
    content: [%ACPex.Schema.Types.ContentBlock.Text{text: "Done"}],
    stop_reason: "done"
  }

  {:ok, response, state}
end

defp send_update(session_id, update) do
  ACPex.Protocol.Connection.send_notification(
    self(),
    "session/update",
    %ACPex.Schema.Session.UpdateNotification{
      session_id: session_id,
      update: update
    }
  )
end
```

### Thoughts

Show the agent's reasoning process:

```elixir
def handle_prompt(request, state) do
  send_update(request.session_id, %{
    kind: "agent_thought_chunk",
    content: %{
      thought: "I need to analyze the code structure first..."
    }
  })

  # Process...

  send_update(request.session_id, %{
    kind: "agent_thought_chunk",
    content: %{
      thought: "Found 3 potential issues. Let me fix them one by one."
    }
  })

  # ...
end
```

### Tool Calls

Inform the client about tool usage:

```elixir
def handle_prompt(request, state) do
  tool_call_id = "call_#{:erlang.unique_integer([:positive])}"

  # Announce the tool call
  send_update(request.session_id, %{
    kind: "tool_call",
    content: %{
      tool_call_id: tool_call_id,
      type: "function",
      function: %{
        name: "read_file",
        arguments: Jason.encode!(%{path: "/src/main.ex"})
      }
    }
  })

  # Execute the tool (via client request)
  {:ok, file_content} = read_file_from_client("/src/main.ex")

  # Send tool result
  send_update(request.session_id, %{
    kind: "tool_call_update",
    content: %{
      tool_call_id: tool_call_id,
      output: file_content
    }
  })

  # Continue processing...
end
```

### Plans

Show a multi-step plan:

```elixir
def handle_prompt(request, state) do
  send_update(request.session_id, %{
    kind: "plan",
    content: %{
      steps: [
        "1. Read the current implementation",
        "2. Identify the bug",
        "3. Propose a fix",
        "4. Write tests"
      ]
    }
  })

  # Execute the plan...
end
```

## Making Client Requests

Agents can request operations from the client:

### Reading Files

```elixir
defp read_file_from_client(path) do
  request = %ACPex.Schema.Client.FsReadTextFileRequest{path: path}

  case ACPex.Protocol.Connection.send_request(self(), "fs/read_text_file", request) do
    {:ok, %{content: content}} ->
      {:ok, content}

    {:error, error} ->
      {:error, error}
  end
end
```

### Writing Files

```elixir
defp write_file_to_client(path, content) do
  request = %ACPex.Schema.Client.FsWriteTextFileRequest{
    path: path,
    content: content
  }

  case ACPex.Protocol.Connection.send_request(self(), "fs/write_text_file", request) do
    {:ok, _response} ->
      :ok

    {:error, error} ->
      {:error, error}
  end
end
```

### Terminal Operations

```elixir
defp run_command(command, args) do
  # Create terminal
  create_req = %ACPex.Schema.Client.Terminal.CreateRequest{
    command: command,
    args: args,
    env: [%{name: "PATH", value: System.get_env("PATH")}]
  }

  {:ok, %{terminal_id: terminal_id}} =
    ACPex.Protocol.Connection.send_request(self(), "terminal/create", create_req)

  # Wait for exit
  wait_req = %ACPex.Schema.Client.Terminal.WaitForExitRequest{
    terminal_id: terminal_id
  }

  {:ok, %{exit_status: exit_status}} =
    ACPex.Protocol.Connection.send_request(self(), "terminal/wait_for_exit", wait_req)

  # Get output
  output_req = %ACPex.Schema.Client.Terminal.OutputRequest{
    terminal_id: terminal_id
  }

  {:ok, %{output: output}} =
    ACPex.Protocol.Connection.send_request(self(), "terminal/output", output_req)

  # Release terminal
  release_req = %ACPex.Schema.Client.Terminal.ReleaseRequest{
    terminal_id: terminal_id
  }

  ACPex.Protocol.Connection.send_request(self(), "terminal/release", release_req)

  {:ok, output, exit_status}
end
```

## Error Handling

### Returning Errors

```elixir
def handle_prompt(request, state) do
  case process_safely(request) do
    {:ok, result} ->
      response = %ACPex.Schema.Session.PromptResponse{
        content: result,
        stop_reason: "done"
      }
      {:ok, response, state}

    {:error, reason} ->
      # Return an error response
      {:error, %{code: -32000, message: "Processing failed: #{reason}"}, state}
  end
end
```

### Handling Cancellation

```elixir
def handle_prompt(request, state) do
  # Start a long-running task
  task = Task.async(fn ->
    process_long_running_request(request)
  end)

  # Store the task so we can cancel it
  new_state = Map.put(state, :current_task, task)

  # Wait for result (will be cancelled if cancel notification arrives)
  result = Task.await(task, :infinity)

  {:ok, result, Map.delete(new_state, :current_task)}
end

def handle_cancel(notification, state) do
  # Cancel the current task if one exists
  if task = state[:current_task] do
    Task.shutdown(task, :brutal_kill)
  end

  {:noreply, Map.delete(state, :current_task)}
end
```

## Advanced Patterns

### Async Processing with GenServer

For complex agents, use a GenServer to manage async work:

```elixir
defmodule MyAgent.Worker do
  use GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def process_prompt(pid, request, callback) do
    GenServer.cast(pid, {:process, request, callback})
  end

  @impl true
  def init(_args) do
    {:ok, %{}}
  end

  @impl true
  def handle_cast({:process, request, callback}, state) do
    # Do heavy processing
    result = heavy_llm_call(request)

    # Notify the agent via callback
    callback.(result)

    {:noreply, state}
  end
end

# In your agent:
def init(_args) do
  {:ok, worker} = MyAgent.Worker.start_link([])
  {:ok, %{worker: worker}}
end

def handle_prompt(request, state) do
  caller = self()

  MyAgent.Worker.process_prompt(state.worker, request, fn result ->
    # Send result back to connection process
    send(caller, {:llm_result, result})
  end)

  # Wait for result
  receive do
    {:llm_result, result} ->
      response = %ACPex.Schema.Session.PromptResponse{
        content: result,
        stop_reason: "done"
      }
      {:ok, response, state}
  end
end
```

### Context Management

Track conversation context across multiple prompts:

```elixir
def handle_prompt(request, state) do
  session_id = request.session_id
  session = get_session(state, session_id)

  # Build context from history
  context = build_context(session.history, request)

  # Add current prompt to history
  new_session = update_in(session, [:history], &[request | &1])
  new_state = put_session(state, session_id, new_session)

  # Process with full context
  response = process_with_context(context)

  {:ok, response, new_state}
end

defp build_context(history, current_request) do
  # Combine historical context with current request
  history
  |> Enum.reverse()
  |> Enum.map(&extract_text/1)
  |> Kernel.++([extract_text(current_request)])
  |> Enum.join("\n")
end
```

### Integration with MCP

Many agents will want to use MCP (Model Context Protocol) for tool access:

```elixir
defmodule MyAgent do
  @behaviour ACPex.Agent

  def init(_args) do
    # Connect to MCP servers
    {:ok, mcp_client} = MCPex.Client.start_link(...)

    {:ok, %{mcp: mcp_client}}
  end

  def handle_prompt(request, state) do
    # List available MCP tools
    {:ok, tools} = MCPex.Client.list_tools(state.mcp)

    # Let LLM decide which tools to use
    tool_calls = llm_choose_tools(request, tools)

    # Execute tools via MCP
    results = Enum.map(tool_calls, fn call ->
      MCPex.Client.call_tool(state.mcp, call.name, call.arguments)
    end)

    # Generate final response
    response = llm_synthesize(request, results)

    {:ok, response, state}
  end
end
```

## Testing Your Agent

### Unit Tests

```elixir
defmodule MyAgentTest do
  use ExUnit.Case

  test "handles initialize" do
    {:ok, state} = MyAgent.init([])

    request = %ACPex.Schema.Connection.InitializeRequest{
      protocol_version: 1,
      capabilities: %{}
    }

    assert {:ok, response, _state} = MyAgent.handle_initialize(request, state)
    assert response.protocol_version == 1
    assert response.agent_capabilities["sessions"]["new"] == true
  end

  test "handles prompt" do
    {:ok, state} = MyAgent.init([])

    # Create a session first
    new_req = %ACPex.Schema.Session.NewRequest{
      cwd: "/tmp/test",
      mcp_servers: []
    }
    {:ok, new_resp, state} = MyAgent.handle_new_session(new_req, state)

    # Send a prompt
    prompt_req = %ACPex.Schema.Session.PromptRequest{
      session_id: new_resp.session_id,
      content: [%ACPex.Schema.Types.ContentBlock.Text{text: "Hello"}]
    }

    assert {:ok, response, _state} = MyAgent.handle_prompt(prompt_req, state)
    assert response.stop_reason == "done"
  end
end
```

### Integration Tests

```elixir
test "full protocol flow" do
  {:ok, agent_pid} = ACPex.start_agent(MyAgent, [])

  # Send initialize
  # Send new session
  # Send prompt
  # Verify responses
end
```

## Best Practices

1. **Always validate input** - Use Ecto changesets to validate request data
2. **Handle errors gracefully** - Return proper JSON-RPC error responses
3. **Stream updates** - Keep the client informed of progress
4. **Respect cancellation** - Always implement `handle_cancel` properly
5. **Keep state minimal** - Store only what's necessary in state
6. **Use typed schemas** - Leverage ACPex's schema system for type safety
7. **Log appropriately** - Use `Logger` for debugging, but avoid excessive
   logging

## Resources

- [Getting Started Guide](getting_started.md)
- [Protocol Overview](protocol_overview.md)
- [Official ACP Specification](https://agentclientprotocol.com/)
- [ACPex API Documentation](https://hexdocs.pm/acpex)
