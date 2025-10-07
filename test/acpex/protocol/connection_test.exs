defmodule ACPex.Protocol.ConnectionTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias ACPex.Protocol.Connection
  alias ACPex.Test.MockTransport

  defmodule TestHandler do
    @behaviour ACPex.Agent

    alias ACPex.Schema.Connection.{InitializeResponse, AuthenticateResponse}
    alias ACPex.Schema.Session.{NewResponse, PromptResponse}

    def init(_args), do: {:ok, %{}}

    def handle_initialize(_params, state) do
      response = %InitializeResponse{
        protocol_version: 1,
        agent_capabilities: %{},
        meta: %{}
      }

      {:ok, response, state}
    end

    # Add other callbacks as needed for testing
    def handle_new_session(_params, state) do
      {:ok, %NewResponse{}, state}
    end

    def handle_load_session(_params, state) do
      {:error, %{code: -32_001, message: "Not supported"}, state}
    end

    def handle_prompt(_params, state) do
      {:ok, %PromptResponse{stop_reason: "done"}, state}
    end

    def handle_session_prompt(_params, state) do
      {:ok, %PromptResponse{stop_reason: "done"}, state}
    end

    def handle_cancel(_params, state), do: {:noreply, state}

    def handle_authenticate(_params, state) do
      {:ok, %AuthenticateResponse{authenticated: true}, state}
    end
  end

  setup do
    {:ok, transport_pid} = MockTransport.start_link(self())

    on_exit(fn ->
      if Process.alive?(transport_pid), do: GenServer.stop(transport_pid)
    end)

    {:ok, conn_pid} =
      Connection.start_link(
        handler_module: TestHandler,
        handler_args: [],
        role: :agent,
        transport_pid: transport_pid
      )

    %{conn: conn_pid, transport: transport_pid}
  end

  test "handles connection-level initialize request", %{conn: conn, transport: _transport} do
    # Simulate a client sending an initialize request
    request = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "initialize",
      "params" => %{"protocol_version" => "1.0", "capabilities" => %{}}
    }

    # The transport sends the parsed message to the connection
    send(conn, {:message, request})

    # Assert that the mock transport received the response
    assert_receive {:transport_data, response_payload}

    response = response_payload |> String.trim() |> Jason.decode!()

    assert response["id"] == 1
    assert response["result"]["protocolVersion"] == 1
    assert response["result"]["agentCapabilities"] == %{}
  end

  test "handles session/new request and creates a session", %{conn: conn} do
    request = %{
      "jsonrpc" => "2.0",
      "id" => 2,
      "method" => "session/new",
      "params" => %{}
    }

    send(conn, {:message, request})

    assert_receive {:transport_data, response_payload}

    response = response_payload |> String.trim() |> Jason.decode!()

    assert response["id"] == 2
    assert is_binary(response["result"]["sessionId"])
  end

  test "routes session messages to the correct session process", %{conn: conn} do
    # 1. Create a new session
    new_session_req = %{
      "jsonrpc" => "2.0",
      "id" => "new-session-req",
      "method" => "session/new",
      "params" => %{}
    }

    send(conn, {:message, new_session_req})
    assert_receive {:transport_data, new_session_payload}

    new_session_resp = new_session_payload |> String.trim() |> Jason.decode!()

    session_id = new_session_resp["result"]["sessionId"]
    assert is_binary(session_id)

    # 2. Send a prompt to the new session
    prompt_req = %{
      "jsonrpc" => "2.0",
      "id" => "prompt-req",
      "method" => "session/prompt",
      "params" => %{
        "sessionId" => session_id,
        "prompt" => [%{"type" => "text", "text" => "Hello there"}]
      }
    }

    send(conn, {:message, prompt_req})
    assert_receive {:transport_data, prompt_payload}

    prompt_resp = prompt_payload |> String.trim() |> Jason.decode!()

    assert prompt_resp["id"] == "prompt-req"
    assert prompt_resp["result"]["stopReason"] == "done"
  end

  test "properly extracts agent_path from nested opts for client role" do
    {:ok, transport_pid} = MockTransport.start_link(self())

    # This should not crash - agent_path should be extracted from nested opts
    result =
      Connection.start_link(
        handler_module: TestHandler,
        handler_args: [],
        role: :client,
        transport_pid: transport_pid,
        opts: [agent_path: "/usr/bin/gemini"]
      )

    # If the fix works, we should get a connection (transport_pid is provided so no spawn needed)
    assert {:ok, _pid} = result
  end

  test "returns error when agent_path missing for client role without transport_pid" do
    # Without transport_pid and without agent_path, should fail
    result =
      Connection.start_link(
        handler_module: TestHandler,
        handler_args: [],
        role: :client,
        opts: []
      )

    # Should fail because agent_path is required when no transport_pid
    assert {:error, _reason} = result
  end

  describe "executable resolution" do
    test "accepts absolute path to existing executable" do
      # Use a known system executable
      executable_path = System.find_executable("ls")
      assert executable_path != nil, "ls executable not found in PATH"

      result =
        Connection.start_link(
          handler_module: TestHandler,
          handler_args: [],
          role: :client,
          agent_path: executable_path,
          agent_args: []
        )

      # Should succeed - the connection will start (though the agent won't be a valid ACP agent)
      assert {:ok, pid} = result
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "rejects absolute path to non-existent file" do
      non_existent_path = "/tmp/acpex-test-nonexistent-executable-#{:rand.uniform(999_999)}"

      result =
        Connection.start_link(
          handler_module: TestHandler,
          handler_args: [],
          role: :client,
          agent_path: non_existent_path,
          agent_args: []
        )

      # Should fail with clear error message
      assert {:error, reason} = result
      assert reason =~ "does not exist" or reason =~ "not found"
    end

    test "rejects non-executable file" do
      # Create a temporary file without execute permissions
      tmp_file = "/tmp/acpex-test-non-executable-#{:rand.uniform(999_999)}"
      File.write!(tmp_file, "#!/bin/bash\necho 'test'")
      # Read/write but not execute
      File.chmod!(tmp_file, 0o644)

      on_exit(fn -> File.rm(tmp_file) end)

      result =
        Connection.start_link(
          handler_module: TestHandler,
          handler_args: [],
          role: :client,
          agent_path: tmp_file,
          agent_args: []
        )

      # Should fail with clear error message
      assert {:error, reason} = result
      assert reason =~ "not executable"
    end

    test "resolves command from PATH" do
      # Use a common command that should be in PATH
      result =
        Connection.start_link(
          handler_module: TestHandler,
          handler_args: [],
          role: :client,
          # Not an absolute path - should be resolved from PATH
          agent_path: "ls",
          agent_args: []
        )

      # Should succeed
      assert {:ok, pid} = result
      if Process.alive?(pid), do: GenServer.stop(pid)
    end

    test "rejects command not in PATH" do
      non_existent_command = "acpex-nonexistent-command-#{:rand.uniform(999_999)}"

      result =
        Connection.start_link(
          handler_module: TestHandler,
          handler_args: [],
          role: :client,
          agent_path: non_existent_command,
          agent_args: []
        )

      # Should fail with clear error message
      assert {:error, reason} = result
      assert reason =~ "not found in PATH" or reason =~ "not found"
    end
  end
end
