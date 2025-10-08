# Building Clients with ACPex

This guide covers building ACP clients (typically code editors or IDE plugins)
using ACPex.

## Table of Contents

- [Overview](#overview)
- [The Client Behaviour](#the-client-behaviour)
- [Connecting to an Agent](#connecting-to-an-agent)
- [Handling Session Updates](#handling-session-updates)
- [File System Operations](#file-system-operations)
- [Terminal Management](#terminal-management)
- [User Interface Integration](#user-interface-integration)
- [Advanced Patterns](#advanced-patterns)

## Overview

An ACP client is typically a code editor or IDE plugin that:

1. Spawns an AI agent as a subprocess
2. Initializes the connection and negotiates capabilities
3. Creates sessions and sends user prompts to the agent
4. Handles streaming updates from the agent
5. Responds to agent requests for file access and terminal operations

## The Client Behaviour

Every client must implement the `ACPex.Client` behaviour:

```elixir
defmodule MyEditor.ACPClient do
  @behaviour ACPex.Client

  @impl true
  def init(args), do: {:ok, %{}}

  @impl true
  def handle_session_update(notification, state), do: {:noreply, state}

  @impl true
  def handle_fs_read_text_file(request, state), do: {:ok, response, state}

  @impl true
  def handle_fs_write_text_file(request, state), do: {:ok, response, state}

  @impl true
  def handle_terminal_create(request, state), do: {:ok, response, state}

  @impl true
  def handle_terminal_output(request, state), do: {:ok, response, state}

  @impl true
  def handle_terminal_wait_for_exit(request, state), do: {:ok, response, state}

  @impl true
  def handle_terminal_kill(request, state), do: {:ok, response, state}

  @impl true
  def handle_terminal_release(request, state), do: {:ok, response, state}
end
```

## Connecting to an Agent

### Starting a Connection

```elixir
# Start a client and connect to an agent
{:ok, connection_pid} = ACPex.start_client(
  MyEditor.ACPClient,
  [],  # Init args for your client
  agent_path: "/usr/local/bin/my-agent",
  agent_args: ["--model", "claude-3-5-sonnet"]  # Optional agent-specific args
)
```

### Initialization Flow

The client automatically handles the initialization handshake:

1. Client sends `initialize` request with capabilities
2. Agent responds with its capabilities
3. If needed, client sends `authenticate` request
4. Agent responds with authentication result

```elixir
def init(_args) do
  initial_state = %{
    # Client capabilities we'll advertise
    capabilities: %{
      "fileSystem" => %{
        "readTextFile" => true,
        "writeTextFile" => true
      },
      "terminal" => %{
        "create" => true,
        "output" => true,
        "waitForExit" => true,
        "kill" => true,
        "release" => true
      }
    },
    # Track active terminals
    terminals: %{},
    # Track active sessions
    sessions: %{}
  }

  {:ok, initial_state}
end
```

## Handling Session Updates

The agent sends real-time updates during prompt processing:

### Message Chunks

Display the agent's response as it's being generated:

```elixir
def handle_session_update(notification, state) do
  %{session_id: session_id, update: update} = notification

  case update["kind"] do
    "agent_message_chunk" ->
      # Stream the response to the UI
      content = update["content"]
      text = get_in(content, ["content", Access.at(0), "text"])

      # Update your UI (pseudo-code)
      UI.append_to_chat(session_id, text)

      {:noreply, state}

    _ ->
      {:noreply, state}
  end
end
```

### Thoughts

Display the agent's reasoning process:

```elixir
def handle_session_update(notification, state) do
  case notification.update["kind"] do
    "agent_thought_chunk" ->
      thought = notification.update["content"]["thought"]

      # Show in UI (e.g., a collapsible "thinking" section)
      UI.show_thought(notification.session_id, thought)

      {:noreply, state}

    _ ->
      {:noreply, state}
  end
end
```

### Tool Calls

Show what tools the agent is using:

```elixir
def handle_session_update(notification, state) do
  case notification.update["kind"] do
    "tool_call" ->
      %{
        "tool_call_id" => tool_id,
        "function" => %{"name" => name, "arguments" => args}
      } = notification.update["content"]

      # Show in UI
      UI.show_tool_call(notification.session_id, "Using #{name}...")

      {:noreply, state}

    "tool_call_update" ->
      %{
        "tool_call_id" => tool_id,
        "output" => output
      } = notification.update["content"]

      # Show result
      UI.update_tool_call(notification.session_id, tool_id, output)

      {:noreply, state}

    _ ->
      {:noreply, state}
  end
end
```

### Plans

Display multi-step plans:

```elixir
def handle_session_update(notification, state) do
  case notification.update["kind"] do
    "plan" ->
      steps = notification.update["content"]["steps"]

      # Show plan in UI
      UI.show_plan(notification.session_id, steps)

      {:noreply, state}

    _ ->
      {:noreply, state}
  end
end
```

### Complete Update Handler

```elixir
def handle_session_update(notification, state) do
  %{session_id: session_id, update: update} = notification

  case update["kind"] do
    "user_message_chunk" ->
      # Echo of user's message (optional to display)
      {:noreply, state}

    "agent_message_chunk" ->
      content = get_in(update, ["content", "content"])
      text = extract_text(content)
      UI.append_message(session_id, text)
      {:noreply, state}

    "agent_thought_chunk" ->
      thought = update["content"]["thought"]
      UI.show_thought(session_id, thought)
      {:noreply, state}

    "tool_call" ->
      name = get_in(update, ["content", "function", "name"])
      UI.show_tool_usage(session_id, name)
      {:noreply, state}

    "tool_call_update" ->
      output = update["content"]["output"]
      UI.show_tool_output(session_id, output)
      {:noreply, state}

    "plan" ->
      steps = update["content"]["steps"]
      UI.show_plan(session_id, steps)
      {:noreply, state}

    _ ->
      # Unknown update type - log but don't crash
      require Logger
      Logger.warning("Unknown update kind: #{update["kind"]}")
      {:noreply, state}
  end
end

defp extract_text(content) when is_list(content) do
  content
  |> Enum.filter(&match?(%{"type" => "text"}, &1))
  |> Enum.map(& &1["text"])
  |> Enum.join("")
end
```

## File System Operations

### Reading Files

```elixir
def handle_fs_read_text_file(request, state) do
  %{path: path} = request

  case File.read(expand_path(path, state)) do
    {:ok, content} ->
      response = %ACPex.Schema.Client.FsReadTextFileResponse{
        content: content
      }
      {:ok, response, state}

    {:error, :enoent} ->
      {:error, %{code: -32001, message: "File not found: #{path}"}, state}

    {:error, :eacces} ->
      {:error, %{code: -32002, message: "Permission denied: #{path}"}, state}

    {:error, reason} ->
      {:error, %{code: -32000, message: "Error reading file: #{reason}"}, state}
  end
end

defp expand_path(path, state) do
  # Resolve relative to workspace root
  Path.join(state.workspace_root, path)
end
```

### Writing Files

```elixir
def handle_fs_write_text_file(request, state) do
  %{path: path, content: content} = request

  full_path = expand_path(path, state)

  # Optional: Ask user for permission
  case ask_user_permission("Write to #{path}?") do
    :allow ->
      case File.write(full_path, content) do
        :ok ->
          # Optional: Refresh file in editor
          UI.refresh_file(path)

          response = %ACPex.Schema.Client.FsWriteTextFileResponse{}
          {:ok, response, state}

        {:error, reason} ->
          {:error, %{code: -32000, message: "Error writing file: #{reason}"}, state}
      end

    :deny ->
      {:error, %{code: -32003, message: "User denied permission"}, state}
  end
end
```

### Security Considerations

```elixir
def handle_fs_read_text_file(request, state) do
  %{path: path} = request

  # Validate path is within workspace
  if path_allowed?(path, state) do
    # ... proceed with read
  else
    {:error, %{code: -32004, message: "Path outside workspace"}, state}
  end
end

defp path_allowed?(path, state) do
  full_path = Path.expand(path, state.workspace_root)
  workspace = Path.expand(state.workspace_root)

  String.starts_with?(full_path, workspace)
end
```

## Terminal Management

### Creating Terminals

```elixir
def handle_terminal_create(request, state) do
  %{command: command, args: args, env: env_vars} = request

  # Generate terminal ID
  terminal_id = "term_#{:erlang.unique_integer([:positive])}"

  # Build environment
  env = build_env(env_vars, state)

  # Spawn the command
  port = Port.open(
    {:spawn_executable, command},
    [
      {:args, args},
      {:env, env},
      :binary,
      :exit_status,
      {:line, 4096},
      :use_stdio,
      :hide
    ]
  )

  # Track the terminal
  terminal = %{
    id: terminal_id,
    port: port,
    command: command,
    output: [],
    exit_status: nil
  }

  new_state = put_in(state, [:terminals, terminal_id], terminal)

  response = %ACPex.Schema.Client.Terminal.CreateResponse{
    terminal_id: terminal_id
  }

  {:ok, response, new_state}
end

defp build_env(env_vars, state) do
  # Convert from schema format to Port format
  Enum.map(env_vars, fn %{name: name, value: value} ->
    {String.to_charlist(name), String.to_charlist(value)}
  end)
end
```

### Handling Terminal Output

```elixir
def handle_terminal_output(request, state) do
  %{terminal_id: terminal_id} = request

  case get_in(state, [:terminals, terminal_id]) do
    nil ->
      {:error, %{code: -32001, message: "Terminal not found"}, state}

    terminal ->
      # Collect all output so far
      output = Enum.join(terminal.output, "")

      response = %ACPex.Schema.Client.Terminal.OutputResponse{
        output: output
      }

      {:ok, response, state}
  end
end

# Handle port messages in a separate process or GenServer
def handle_info({port, {:data, {:eol, line}}}, state) do
  # Find terminal by port
  {terminal_id, terminal} =
    Enum.find(state.terminals, fn {_id, t} -> t.port == port end)

  # Append output
  new_terminal = update_in(terminal, [:output], &[&1 | [line <> "\n"]])
  new_state = put_in(state, [:terminals, terminal_id], new_terminal)

  {:noreply, new_state}
end

def handle_info({port, {:exit_status, code}}, state) do
  # Find terminal and update exit status
  {terminal_id, terminal} =
    Enum.find(state.terminals, fn {_id, t} -> t.port == port end)

  new_terminal = put_in(terminal, [:exit_status], code)
  new_state = put_in(state, [:terminals, terminal_id], new_terminal)

  {:noreply, new_state}
end
```

### Waiting for Terminal Exit

```elixir
def handle_terminal_wait_for_exit(request, state) do
  %{terminal_id: terminal_id} = request

  case get_in(state, [:terminals, terminal_id]) do
    nil ->
      {:error, %{code: -32001, message: "Terminal not found"}, state}

    terminal ->
      # If already exited, return immediately
      if terminal.exit_status do
        response = %ACPex.Schema.Client.Terminal.WaitForExitResponse{
          exit_status: %{code: terminal.exit_status}
        }
        {:ok, response, state}
      else
        # Wait for exit (this is blocking - see advanced patterns for async)
        wait_for_exit(terminal.port)

        # Port will send {:exit_status, code} message
        # This gets handled in handle_info above
        receive do
          {^port, {:exit_status, code}} ->
            response = %ACPex.Schema.Client.Terminal.WaitForExitResponse{
              exit_status: %{code: code}
            }
            {:ok, response, state}
        after
          30_000 ->
            {:error, %{code: -32002, message: "Wait timeout"}, state}
        end
      end
  end
end
```

### Killing and Releasing Terminals

```elixir
def handle_terminal_kill(request, state) do
  %{terminal_id: terminal_id} = request

  case get_in(state, [:terminals, terminal_id]) do
    nil ->
      {:error, %{code: -32001, message: "Terminal not found"}, state}

    terminal ->
      # Kill the port
      Port.close(terminal.port)

      response = %ACPex.Schema.Client.Terminal.KillResponse{}
      {:ok, response, state}
  end
end

def handle_terminal_release(request, state) do
  %{terminal_id: terminal_id} = request

  # Remove terminal from tracking
  new_state = update_in(state, [:terminals], &Map.delete(&1, terminal_id))

  response = %ACPex.Schema.Client.Terminal.ReleaseResponse{}
  {:ok, response, new_state}
end
```

## User Interface Integration

### Phoenix LiveView Example

```elixir
defmodule MyEditorWeb.ChatLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    # Start ACP client
    {:ok, client_pid} = ACPex.start_client(
      MyEditor.ACPClient,
      [ui_pid: self()],  # Pass LiveView PID to client
      agent_path: "/usr/local/bin/agent"
    )

    {:ok, assign(socket, client_pid: client_pid, messages: [])}
  end

  def handle_event("send_message", %{"text" => text}, socket) do
    # Send to agent (via client)
    send_prompt(socket.assigns.client_pid, text)

    {:noreply, socket}
  end

  # Receive updates from client
  def handle_info({:agent_update, update}, socket) do
    new_messages = socket.assigns.messages ++ [update]
    {:noreply, assign(socket, messages: new_messages)}
  end
end

# In your client:
def init([ui_pid: ui_pid]) do
  {:ok, %{ui_pid: ui_pid}}
end

def handle_session_update(notification, state) do
  # Forward to LiveView
  send(state.ui_pid, {:agent_update, notification.update})
  {:noreply, state}
end
```

### Desktop App Example (with Scenic)

```elixir
defmodule MyEditor.Scene.Chat do
  use Scenic.Scene

  def init(scene, _params, _opts) do
    # Start ACP client
    {:ok, client_pid} = ACPex.start_client(
      MyEditor.ACPClient,
      [scene_pid: self()],
      agent_path: "/usr/local/bin/agent"
    )

    graph = build_graph([])

    {:ok, assign(scene, client_pid: client_pid, messages: [], graph: graph)}
  end

  def handle_event({:send_message, text}, _from, scene) do
    send_prompt(scene.assigns.client_pid, text)
    {:noreply, scene}
  end

  def handle_info({:agent_update, update}, scene) do
    # Update graph with new message
    new_messages = scene.assigns.messages ++ [update]
    new_graph = build_graph(new_messages)

    {:noreply, assign(scene, messages: new_messages, graph: new_graph)}
  end
end
```

## Advanced Patterns

### Async Terminal Operations

Don't block the client while waiting for terminal exit:

```elixir
def handle_terminal_wait_for_exit(request, state) do
  %{terminal_id: terminal_id} = request
  terminal = get_in(state, [:terminals, terminal_id])

  if terminal.exit_status do
    # Already exited
    response = %ACPex.Schema.Client.Terminal.WaitForExitResponse{
      exit_status: %{code: terminal.exit_status}
    }
    {:ok, response, state}
  else
    # Spawn a task to wait
    caller = self()
    Task.start(fn ->
      wait_for_terminal_exit(terminal.port, caller, terminal_id)
    end)

    # Return immediately - response will be sent later
    {:pending, state}
  end
end

defp wait_for_terminal_exit(port, caller, terminal_id) do
  receive do
    {^port, {:exit_status, code}} ->
      # Send response to connection process
      ACPex.Protocol.Connection.send_response(
        caller,
        %ACPex.Schema.Client.Terminal.WaitForExitResponse{
          exit_status: %{code: code}
        }
      )
  end
end
```

### Request Queuing

Handle multiple file operations efficiently:

```elixir
def init(_args) do
  {:ok, %{
    file_queue: :queue.new(),
    file_queue_worker: spawn_link(&file_queue_worker/0)
  }}
end

def handle_fs_read_text_file(request, state) do
  # Add to queue instead of processing immediately
  new_queue = :queue.in({:read, request, self()}, state.file_queue)

  # Notify worker
  send(state.file_queue_worker, :process_queue)

  {:pending, %{state | file_queue: new_queue}}
end

defp file_queue_worker() do
  receive do
    :process_queue ->
      # Process queued file operations
      # ...
      file_queue_worker()
  end
end
```

### Permission System

Implement a comprehensive permission system:

```elixir
def handle_fs_write_text_file(request, state) do
  case check_permission(:write, request.path, state) do
    {:allowed, reason} ->
      # Proceed with write
      do_write_file(request, state)

    {:denied, reason} ->
      {:error, %{code: -32003, message: "Permission denied: #{reason}"}, state}

    {:ask_user, reason} ->
      case UI.ask_permission("Allow write to #{request.path}?", reason) do
        :allow ->
          # Remember this decision
          new_state = grant_permission(:write, request.path, state)
          do_write_file(request, new_state)

        :deny ->
          {:error, %{code: -32003, message: "User denied permission"}, state}
      end
  end
end

defp check_permission(action, path, state) do
  cond do
    # Check if permanently allowed
    Map.has_key?(state.permissions, {action, path}) ->
      {:allowed, "previously granted"}

    # Check if in safe directory
    safe_path?(path, state) ->
      {:allowed, "safe directory"}

    # Ask user
    true ->
      {:ask_user, "outside safe directories"}
  end
end
```

## Testing Your Client

### Unit Tests

```elixir
defmodule MyEditor.ACPClientTest do
  use ExUnit.Case

  test "reads files" do
    {:ok, state} = MyEditor.ACPClient.init([])

    request = %ACPex.Schema.Client.FsReadTextFileRequest{
      path: "test.txt"
    }

    # Mock file system
    with_mock File, [read: fn _ -> {:ok, "content"} end] do
      assert {:ok, response, _state} =
        MyEditor.ACPClient.handle_fs_read_text_file(request, state)

      assert response.content == "content"
    end
  end
end
```

### Integration Tests

```elixir
test "end-to-end agent interaction" do
  # Start a mock agent
  {:ok, agent} = start_mock_agent()

  # Start client
  {:ok, client} = ACPex.start_client(
    MyEditor.ACPClient,
    [],
    agent_path: agent.path
  )

  # Send prompt
  # Verify responses
end
```

## Best Practices

1. **Always validate agent requests** - Don't trust the agent blindly
2. **Implement permission systems** - Ask users before file writes or terminal
   commands
3. **Handle updates efficiently** - Batch UI updates to avoid flickering
4. **Provide good UX** - Show progress, thoughts, and tool usage
5. **Handle errors gracefully** - Show user-friendly error messages
6. **Sandbox operations** - Restrict file/terminal access to workspace
7. **Log security events** - Track what the agent requested and what was allowed

## Resources

- [Getting Started Guide](getting_started.md)
- [Building Agents Guide](building_agents.md)
- [Protocol Overview](protocol_overview.md)
- [Official ACP Specification](https://agentclientprotocol.com/)
