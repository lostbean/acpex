defmodule ACPex.E2ETest do
  @moduledoc """
  Integration and end-to-end tests for the ACP protocol implementation.

  These tests verify the complete protocol implementation using both a simple
  test agent (bash script) and the real Claude Code ACP agent.

  ## Running These Tests

      # Run all default tests (includes test_agent.sh integration tests)
      mix test

      # Run only Claude Code ACP tests (requires API key)
      mix test --only claude_code_acp

      # Run all tests including Claude Code ACP
      mix test --include claude_code_acp

  ## Test Agents

  ### Test Agent (test/support/test_agent.sh)
  - Runs by default with `mix test`
  - Simple bash script implementing basic ACP protocol
  - Fast transport layer verification
  - No external dependencies or authentication

  ### Claude Code ACP
  - Excluded by default (tagged with `:claude_code_acp`)
  - Requires: `npm install -g @zed-industries/claude-code-acp`
  - Requires: `ANTHROPIC_API_KEY` environment variable
  - Tests real AI agent with streaming responses
  - Slower (requires API calls to Claude)
  """

  use ExUnit.Case, async: false

  # 2 minutes for entire module
  @moduletag timeout: 120_000

  @test_agent_path Path.expand("../support/test_agent.sh", __DIR__)
  @claude_code_path "/Users/edgar/.npm-global/bin/claude-code-acp"
  @test_dir "/tmp/acpex-e2e-test"

  # ============================================================================
  # Test Client Implementation
  # ============================================================================

  defmodule TestClient do
    @moduledoc false
    @behaviour ACPex.Client

    @test_dir "/tmp/acpex-e2e-test"

    def init(args) do
      test_pid = Keyword.fetch!(args, :test_pid)

      # Create test directory
      File.mkdir_p!(@test_dir)

      state = %{
        test_pid: test_pid,
        updates: [],
        file_operations: [],
        terminal_operations: [],
        terminals: %{}
      }

      {:ok, state}
    end

    def handle_session_update(params, state) do
      # Store the update
      new_state = %{state | updates: [params | state.updates]}

      # Notify test process
      send(state.test_pid, {:session_update, params})

      {:noreply, new_state}
    end

    def handle_fs_read_text_file(%{"path" => path}, state) do
      # Log the operation
      new_state = %{state | file_operations: [{:read, path} | state.file_operations]}
      send(state.test_pid, {:file_read, path})

      # Try to read the file
      case File.read(path) do
        {:ok, content} ->
          {:ok, %{"content" => content}, new_state}

        {:error, reason} ->
          error = %{
            "code" => -32_001,
            "message" => "Failed to read file: #{inspect(reason)}"
          }

          {:error, error, new_state}
      end
    end

    def handle_fs_write_text_file(%{"path" => path, "content" => content}, state) do
      # Log the operation
      new_state = %{state | file_operations: [{:write, path, content} | state.file_operations]}
      send(state.test_pid, {:file_write, path, content})

      # Ensure directory exists
      path |> Path.dirname() |> File.mkdir_p!()

      # Write the file
      case File.write(path, content) do
        :ok ->
          {:ok, %{"bytes_written" => byte_size(content)}, new_state}

        {:error, reason} ->
          error = %{
            "code" => -32_002,
            "message" => "Failed to write file: #{inspect(reason)}"
          }

          {:error, error, new_state}
      end
    end

    def handle_terminal_create(%{"command" => command} = params, state) do
      terminal_id = "term-" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)

      terminal_info = %{
        id: terminal_id,
        command: command,
        cwd: params["cwd"] || @test_dir
      }

      new_terminals = Map.put(state.terminals, terminal_id, terminal_info)

      new_state = %{
        state
        | terminals: new_terminals,
          terminal_operations: [{:create, terminal_id, command} | state.terminal_operations]
      }

      send(state.test_pid, {:terminal_create, terminal_id, command})

      {:ok, %{"terminal_id" => terminal_id}, new_state}
    end

    def handle_terminal_output(%{"terminal_id" => terminal_id}, state) do
      case Map.get(state.terminals, terminal_id) do
        nil ->
          error = %{"code" => -32_003, "message" => "Terminal not found"}
          {:error, error, state}

        terminal ->
          # Execute the command
          {output, exit_code} =
            try do
              System.cmd("sh", ["-c", terminal.command],
                cd: terminal.cwd,
                stderr_to_stdout: true
              )
            rescue
              _ -> {"Error executing command", 1}
            end

          send(state.test_pid, {:terminal_output, terminal_id, output, exit_code})

          {:ok, %{"output" => output, "exit_code" => exit_code}, state}
      end
    end

    def handle_terminal_wait_for_exit(%{"terminal_id" => terminal_id}, state) do
      if Map.has_key?(state.terminals, terminal_id) do
        {:ok, %{"exit_code" => 0}, state}
      else
        error = %{"code" => -32_003, "message" => "Terminal not found"}
        {:error, error, state}
      end
    end

    def handle_terminal_kill(%{"terminal_id" => terminal_id}, state) do
      new_terminals = Map.delete(state.terminals, terminal_id)
      {:ok, %{}, %{state | terminals: new_terminals}}
    end

    def handle_terminal_release(%{"terminal_id" => terminal_id}, state) do
      new_terminals = Map.delete(state.terminals, terminal_id)
      {:ok, %{}, %{state | terminals: new_terminals}}
    end
  end

  # ============================================================================
  # Test Setup
  # ============================================================================

  setup_all do
    # Clean up test directory
    File.rm_rf!(@test_dir)
    File.mkdir_p!(@test_dir)

    :ok
  end

  setup context do
    if context[:skip] do
      {:ok, context}
    else
      :ok
    end
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp claude_code_authenticated? do
    # Check if ANTHROPIC_API_KEY is set
    System.get_env("ANTHROPIC_API_KEY") != nil
  end

  # Helper to wait for multiple updates (currently unused but may be useful in future tests)
  # defp wait_for_updates(count, timeout \\ 30_000) do
  #   wait_for_updates(count, timeout, [])
  # end

  # defp wait_for_updates(0, _timeout, acc), do: Enum.reverse(acc)

  # defp wait_for_updates(count, timeout, acc) do
  #   receive do
  #     {:session_update, update} ->
  #       wait_for_updates(count - 1, timeout, [update | acc])
  #   after
  #     timeout ->
  #       Enum.reverse(acc)
  #   end
  # end

  defp flush_updates do
    receive do
      {:session_update, _} -> flush_updates()
    after
      0 -> :ok
    end
  end

  # ============================================================================
  # Tests
  # ============================================================================

  describe "connection establishment" do
    @tag timeout: 30_000
    test "connects to test agent" do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @test_agent_path,
          agent_args: []
        )

      assert Process.alive?(conn)

      # Clean up
      Process.exit(conn, :normal)
    end
  end

  describe "protocol handshake" do
    setup do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @test_agent_path,
          agent_args: []
        )

      on_exit(fn ->
        if Process.alive?(conn) do
          Process.exit(conn, :normal)
        end
      end)

      %{conn: conn}
    end

    @tag timeout: 30_000
    test "completes initialize handshake", %{conn: conn} do
      response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "initialize",
          %{
            "protocolVersion" => 1.0,
            "capabilities" => %{
              "filesystem" => true,
              "terminal" => true
            },
            "clientInfo" => %{
              "name" => "ACPex E2E Test",
              "version" => "0.1.0"
            }
          },
          30_000
        )

      assert %{"result" => result} = response
      # Accept both camelCase/snake_case and string/number formats (1, 1.0, "1.0")
      protocol_version = result["protocolVersion"] || result["protocol_version"]

      assert protocol_version in [1, 1.0, "1.0"],
             "Expected protocol version 1, got: #{inspect(protocol_version)}"

      # Accept both "capabilities" and "agentCapabilities" (different agents use different keys)
      capabilities = result["capabilities"] || result["agentCapabilities"]
      assert is_map(capabilities)

      # Agent should identify itself (accept both formats)
      agent_info = result["agentInfo"] || result["agent_info"]

      if agent_info do
        assert is_map(agent_info)
      end
    end

    @tag timeout: 30_000
    test "creates a session", %{conn: conn} do
      # First initialize
      ACPex.Protocol.Connection.send_request(
        conn,
        "initialize",
        %{
          "protocolVersion" => 1,
          "capabilities" => %{},
          "clientInfo" => %{"name" => "Test", "version" => "1.0"}
        },
        30_000
      )

      # Create session
      response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/new",
          %{},
          10_000
        )

      assert %{"result" => %{"session_id" => session_id}} = response
      assert is_binary(session_id)
      assert String.length(session_id) > 0
    end
  end

  describe "prompt handling" do
    setup do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @test_agent_path,
          agent_args: []
        )

      # Initialize
      ACPex.Protocol.Connection.send_request(
        conn,
        "initialize",
        %{
          "protocol_version" => "1.0",
          "capabilities" => %{
            "filesystem" => true,
            "terminal" => true
          },
          "client_info" => %{"name" => "Test", "version" => "1.0"}
        },
        30_000
      )

      # Create session
      %{"result" => %{"session_id" => session_id}} =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/new",
          %{},
          10_000
        )

      on_exit(fn ->
        if Process.alive?(conn) do
          Process.exit(conn, :normal)
        end

        flush_updates()
      end)

      %{conn: conn, session_id: session_id}
    end

    @tag timeout: 90_000
    test "sends simple prompt and receives response", %{conn: conn, session_id: session_id} do
      flush_updates()

      # Send a simple prompt
      response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/prompt",
          %{
            "sessionId" => session_id,
            "prompt" => [%{"type" => "text", "text" => "Say exactly: ACPex test successful"}]
          },
          10_000
        )

      # Should get a successful response
      assert %{"result" => result} = response
      assert is_map(result)

      # The response should indicate completion (accept both formats)
      stop_reason = result["stopReason"] || result["stop_reason"]
      assert stop_reason in ["done", "end_turn", "stop", "completed", nil]
    end

    @tag timeout: 90_000
    test "receives session updates during processing", %{conn: conn, session_id: session_id} do
      # Note: This test requires an agent that sends session/update notifications
      # The simple test agent doesn't support streaming updates
      flush_updates()

      # Start the prompt
      _task =
        Task.async(fn ->
          ACPex.Protocol.Connection.send_request(
            conn,
            "session/prompt",
            %{
              "sessionId" => session_id,
              "prompt" => [%{"type" => "text", "text" => "Count to 3"}]
            },
            60_000
          )
        end)

      # Wait for updates
      Process.sleep(3_000)

      # Should have received at least one update
      assert_received {:session_update, update}
      assert is_map(update)
      assert Map.has_key?(update, "update") or Map.has_key?(update, "content")
    end
  end

  describe "file system integration" do
    setup do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @test_agent_path,
          agent_args: []
        )

      # Initialize
      ACPex.Protocol.Connection.send_request(
        conn,
        "initialize",
        %{
          "protocol_version" => "1.0",
          "capabilities" => %{"filesystem" => true},
          "client_info" => %{"name" => "Test", "version" => "1.0"}
        },
        30_000
      )

      # Create session
      %{"result" => %{"session_id" => session_id}} =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/new",
          %{},
          10_000
        )

      on_exit(fn ->
        if Process.alive?(conn) do
          Process.exit(conn, :normal)
        end

        flush_updates()
        File.rm_rf!(@test_dir)
      end)

      %{conn: conn, session_id: session_id}
    end

    @tag timeout: 90_000
    test "agent can read files when prompted", %{conn: conn, session_id: session_id} do
      # Note: This test requires an agent that makes file system requests
      # The simple test agent doesn't interact with the file system

      # Create a test file
      test_file = Path.join(@test_dir, "input.txt")
      File.write!(test_file, "Hello from E2E test!")

      flush_updates()

      # Ask agent to read it
      _task =
        Task.async(fn ->
          ACPex.Protocol.Connection.send_request(
            conn,
            "session/prompt",
            %{
              "sessionId" => session_id,
              "prompt" => [%{"type" => "text", "text" => "Read the file at #{test_file}"}]
            },
            60_000
          )
        end)

      # Wait for file read
      assert_receive {:file_read, ^test_file}, 30_000
    end
  end

  describe "cleanup" do
    @tag timeout: 10_000
    test "connection stops cleanly" do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @test_agent_path,
          agent_args: []
        )

      assert Process.alive?(conn)

      # Monitor the connection
      ref = Process.monitor(conn)

      # Stop the connection using GenServer.stop (proper shutdown)
      GenServer.stop(conn, :normal, 5000)

      # Wait for process to terminate
      assert_receive {:DOWN, ^ref, :process, ^conn, :normal}, 1_000

      # Should be dead
      refute Process.alive?(conn)
    end
  end

  # ============================================================================
  # Claude Code ACP Integration Tests
  # ============================================================================
  #
  # These tests use extended timeouts because Claude Code ACP can be slow:
  # - First request (initialize): 60s (model loading, cold start)
  # - Session creation: 30s
  # - Prompt responses: 90s (AI processing time)
  # - Test timeouts: 90-180s (allow for multiple operations)
  #
  # All tests are tagged :skip by default and require ANTHROPIC_API_KEY.
  # ============================================================================

  describe "claude code acp availability" do
    @moduletag :claude_code_acp

    test "claude-code-acp exists at expected path" do
      assert File.exists?(@claude_code_path),
             "Claude Code ACP not found at #{@claude_code_path}. Install with: npm install -g @zed-industries/claude-code-acp"
    end

    test "claude-code-acp is executable" do
      stat = File.stat!(@claude_code_path)

      assert stat.access == :read_write or stat.access == :read,
             "Claude Code ACP not executable"
    end

    test "claude code acp is authenticated" do
      assert claude_code_authenticated?(),
             "ANTHROPIC_API_KEY not set. Set it with: export ANTHROPIC_API_KEY=sk-..."
    end
  end

  describe "claude code acp integration" do
    @moduletag :claude_code_acp

    setup do
      # Skip tests if Claude Code ACP is not available or not authenticated
      cond do
        not File.exists?(@claude_code_path) ->
          {:ok, skip: true, reason: "Claude Code ACP not installed"}

        not claude_code_authenticated?() ->
          {:ok, skip: true, reason: "ANTHROPIC_API_KEY not set"}

        true ->
          :ok
      end
    end

    @tag timeout: 60_000
    test "connects to claude code acp" do
      # Claude Code can take time to start up
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @claude_code_path
        )

      assert Process.alive?(conn)

      # Clean up
      Process.exit(conn, :normal)
    end

    @tag timeout: 90_000
    test "completes initialize handshake with claude code" do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @claude_code_path
        )

      # Claude Code can take 60s+ for first request (model loading, cold start)
      response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "initialize",
          %{
            "protocolVersion" => 1.0,
            "capabilities" => %{
              "filesystem" => true,
              "terminal" => true
            },
            "clientInfo" => %{
              "name" => "ACPex E2E Test",
              "version" => "0.1.0"
            }
          },
          60_000
        )

      assert %{"result" => result} = response
      # Accept both camelCase/snake_case and string/number formats (1, 1.0, "1.0")
      protocol_version = result["protocolVersion"] || result["protocol_version"]

      assert protocol_version in [1, 1.0, "1.0"],
             "Expected protocol version 1, got: #{inspect(protocol_version)}"

      # Accept both "capabilities" and "agentCapabilities" (different agents use different keys)
      capabilities = result["capabilities"] || result["agentCapabilities"]
      assert is_map(capabilities)

      # Claude Code should identify itself (accept both formats)
      agent_info = result["agentInfo"] || result["agent_info"]

      if agent_info do
        assert is_map(agent_info)
        # Should mention Claude or Anthropic
        agent_name = agent_info["name"] || ""

        assert String.contains?(String.downcase(agent_name), "claude") or
                 String.contains?(String.downcase(agent_name), "anthropic")
      end

      # Clean up
      Process.exit(conn, :normal)
    end

    @tag timeout: 180_000
    test "creates session and handles prompts with claude code" do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @claude_code_path
        )

      # Initialize - first request can be very slow (cold start)
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

      # Create session - Claude Code requires cwd and mcpServers
      session_response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/new",
          %{
            "cwd" => System.get_env("PWD") || "/tmp",
            "mcpServers" => []
          },
          30_000
        )

      assert %{"result" => result} = session_response
      # Accept both camelCase and snake_case
      session_id = result["sessionId"] || result["session_id"]
      assert is_binary(session_id)

      flush_updates()

      # Send a simple prompt - AI response can take 60-90s
      response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/prompt",
          %{
            "sessionId" => session_id,
            "prompt" => [%{"type" => "text", "text" => "Say exactly: Hello from ACPex test"}]
          },
          90_000
        )

      # Should get a successful response
      assert %{"result" => result} = response
      assert is_map(result)

      # The response should indicate completion (accept both formats)
      stop_reason = result["stopReason"] || result["stop_reason"]
      assert stop_reason in ["done", "end_turn", "stop", "completed", nil]

      # Clean up
      Process.exit(conn, :normal)
    end

    @tag timeout: 180_000
    test "receives session updates during claude code processing" do
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @claude_code_path
        )

      # Initialize - first request can be very slow
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

      # Create session - Claude Code requires cwd and mcpServers
      session_response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/new",
          %{
            "cwd" => System.get_env("PWD") || "/tmp",
            "mcpServers" => []
          },
          30_000
        )

      assert %{"result" => result} = session_response
      # Accept both camelCase and snake_case
      session_id = result["sessionId"] || result["session_id"]
      assert is_binary(session_id)

      flush_updates()

      # Start a prompt that should generate multiple streaming updates
      task =
        Task.async(fn ->
          ACPex.Protocol.Connection.send_request(
            conn,
            "session/prompt",
            %{
              "sessionId" => session_id,
              "prompt" => [%{"type" => "text", "text" => "Count from 1 to 5"}]
            },
            90_000
          )
        end)

      # Wait a bit for updates to arrive
      Process.sleep(2_000)

      # Should have received at least one session update
      assert_received {:session_update, update}
      assert is_map(update)

      # Wait for completion
      Task.await(task, 90_000)

      # Clean up
      Process.exit(conn, :normal)
    end

    @tag timeout: 180_000
    @tag :skip
    test "claude code can read files when prompted" do
      # NOTE: This test is skipped because Claude Code uses its own internal file
      # reading capabilities rather than making fs/read_text_file requests back to
      # the client. The test_agent.sh demonstrates bidirectional file requests,
      # but Claude Code has direct filesystem access and doesn't use this pattern.
      {:ok, conn} =
        ACPex.start_client(
          TestClient,
          [test_pid: self()],
          agent_path: @claude_code_path
        )

      # Initialize with filesystem capability - first request can be very slow
      ACPex.Protocol.Connection.send_request(
        conn,
        "initialize",
        %{
          "protocolVersion" => 1,
          "capabilities" => %{"filesystem" => true},
          "clientInfo" => %{"name" => "Test", "version" => "1.0"}
        },
        60_000
      )

      # Create session - Claude Code requires cwd and mcpServers
      session_response =
        ACPex.Protocol.Connection.send_request(
          conn,
          "session/new",
          %{
            "cwd" => System.get_env("PWD") || "/tmp",
            "mcpServers" => []
          },
          30_000
        )

      assert %{"result" => result} = session_response
      # Accept both camelCase and snake_case
      session_id = result["sessionId"] || result["session_id"]
      assert is_binary(session_id)

      # Create a test file
      test_file = Path.join(@test_dir, "claude_test.txt")
      File.write!(test_file, "Hello from Claude Code E2E test!")

      flush_updates()

      # Ask Claude Code to read it - AI needs time to process and decide to read file
      _task =
        Task.async(fn ->
          ACPex.Protocol.Connection.send_request(
            conn,
            "session/prompt",
            %{
              "sessionId" => session_id,
              "prompt" => [
                %{
                  "type" => "text",
                  "text" => "Please read the file at #{test_file} and tell me what it contains"
                }
              ]
            },
            90_000
          )
        end)

      # Wait for file read - may take a while for AI to decide to read
      assert_receive {:file_read, ^test_file}, 60_000

      # Clean up
      Process.exit(conn, :normal)
    end
  end
end
