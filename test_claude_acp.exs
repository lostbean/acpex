#!/usr/bin/env elixir

# Simple script to test Claude Code ACP transport
Mix.install([{:jason, "~> 1.4"}])

defmodule SimpleClient do
  @behaviour ACPex.Client

  def init(_args), do: {:ok, %{}}

  def handle_session_update(params, state) do
    IO.puts("📥 Session update: #{inspect(params)}")
    {:noreply, state}
  end

  def handle_fs_read_text_file(%{"path" => path}, state) do
    {:ok, %{"content" => "test"}, state}
  end

  def handle_fs_write_text_file(_params, state), do: {:ok, %{}, state}
  def handle_terminal_create(_params, state), do: {:ok, %{}, state}
  def handle_terminal_output(_params, state), do: {:ok, %{}, state}
  def handle_terminal_wait_for_exit(_params, state), do: {:ok, %{}, state}
  def handle_terminal_kill(_params, state), do: {:ok, %{}, state}
  def handle_terminal_release(_params, state), do: {:ok, %{}, state}
end

# Start the client
IO.puts("🚀 Starting Claude Code ACP client...")

claude_acp_path = System.find_executable("claude-code-acp")

assert claude_acp_path != nil

{:ok, conn} =
  ACPex.start_client(
    SimpleClient,
    [],
    agent_path: claude_acp_path
  )

IO.puts("✅ Client started: #{inspect(conn)}")

# Send initialize
IO.puts("\n📤 Sending initialize...")

response =
  ACPex.Protocol.Connection.send_request(
    conn,
    "initialize",
    %{
      "protocolVersion" => 1,
      "capabilities" => %{},
      "clientInfo" => %{"name" => "Test", "version" => "1.0"}
    },
    60_000
  )

IO.puts("📥 Initialize response: #{inspect(response)}")

# Create session
IO.puts("\n📤 Creating session...")

session_response =
  ACPex.Protocol.Connection.send_request(
    conn,
    "session/new",
    %{
      "cwd" => "/tmp",
      "mcpServers" => []
    },
    30_000
  )

IO.puts("📥 Session response: #{inspect(session_response)}")
session_id = session_response["result"]["sessionId"] || session_response["result"]["session_id"]
IO.puts("✅ Session ID: #{session_id}")

# Wait a bit to see any session updates
Process.sleep(2000)

IO.puts("\n✅ Test complete!")
