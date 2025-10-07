defmodule ACPex.IntegrationTest do
  @moduledoc """
  Integration tests for the full message flow through Transport -> Connection -> Session.

  These tests verify that the complete protocol lifecycle works correctly
  with all layers of the OTP architecture interacting properly.
  """
  use ExUnit.Case

  @moduletag capture_log: true

  alias ACPex.Protocol.Connection
  alias ACPex.Test.MockTransport

  defmodule TestAgent do
    @behaviour ACPex.Agent

    alias ACPex.Schema.Connection.{InitializeResponse, AuthenticateResponse}
    alias ACPex.Schema.Session.{NewResponse, PromptResponse}

    def init(_args), do: {:ok, %{sessions: %{}}}

    def handle_initialize(_request, state) do
      response = %InitializeResponse{
        protocol_version: 1,
        agent_capabilities: %{
          "sessions" => %{"new" => true, "load" => false}
        },
        meta: %{
          "name" => "TestAgent",
          "version" => "1.0.0"
        }
      }

      {:ok, response, state}
    end

    def handle_authenticate(request, state) do
      # Check if the method_id is valid
      if request.method_id == "token" or request.method_id == "api_key" do
        response = %AuthenticateResponse{
          authenticated: true
        }

        {:ok, response, state}
      else
        {:error, %{code: -32_000, message: "Invalid authentication method"}, state}
      end
    end

    def handle_new_session(_request, state) do
      session_state = %{messages: []}
      response = %NewResponse{}
      {:ok, response, Map.put(state, :session_state, session_state)}
    end

    def handle_prompt(request, state) do
      # Fallback handler
      handle_session_prompt(request, state)
    end

    def handle_session_prompt(_request, state) do
      # Simulate processing and return response
      # Note: In a real agent, you would send session/update notifications
      # with the actual content. PromptResponse only contains stop_reason.
      response = %PromptResponse{
        stop_reason: "done"
      }

      {:ok, response, state}
    end

    def handle_session_cancel(_notification, state) do
      {:noreply, state}
    end

    def handle_cancel(_notification, state) do
      {:noreply, state}
    end

    def handle_load_session(_request, state) do
      {:error, %{code: -32_001, message: "Session not found"}, state}
    end
  end

  defmodule TestClient do
    @behaviour ACPex.Client

    alias ACPex.Schema.Client.{FsReadTextFileResponse, FsWriteTextFileResponse}
    alias ACPex.Schema.Client.Terminal.{CreateResponse, OutputResponse}
    alias ACPex.Schema.Client.Terminal.{WaitForExitResponse, KillResponse, ReleaseResponse}

    def init(args) do
      test_pid = Keyword.fetch!(args, :test_pid)
      {:ok, %{test_pid: test_pid, files: %{"/test.txt" => "test content"}}}
    end

    def handle_session_update(notification, state) do
      send(state.test_pid, {:session_update, notification})
      {:noreply, state}
    end

    def handle_fs_read_text_file(request, state) do
      case Map.get(state.files, request.path) do
        nil ->
          {:error, %{code: -32_001, message: "File not found"}, state}

        content ->
          response = %FsReadTextFileResponse{content: content}
          {:ok, response, state}
      end
    end

    def handle_fs_write_text_file(request, state) do
      new_files = Map.put(state.files, request.path, request.content)
      response = %FsWriteTextFileResponse{}
      {:ok, response, %{state | files: new_files}}
    end

    def handle_terminal_create(_request, state) do
      terminal_id = "term-" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
      response = %CreateResponse{terminal_id: terminal_id}
      {:ok, response, state}
    end

    def handle_terminal_output(_request, state) do
      response = %OutputResponse{output: "command output"}
      {:ok, response, state}
    end

    def handle_terminal_wait_for_exit(_request, state) do
      response = %WaitForExitResponse{exit_code: 0}
      {:ok, response, state}
    end

    def handle_terminal_kill(_request, state) do
      response = %KillResponse{}
      {:ok, response, state}
    end

    def handle_terminal_release(_request, state) do
      response = %ReleaseResponse{}
      {:ok, response, state}
    end
  end

  describe "full agent lifecycle" do
    test "initialize -> authenticate -> new_session -> prompt -> response" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: TestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Step 1: Initialize
      initialize_req = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "initialize",
        "params" => %{
          "protocol_version" => "1.0",
          "capabilities" => %{}
        }
      }

      send(agent_conn, {:message, initialize_req})
      assert_receive {:transport_data, init_response_payload}
      init_response = parse_response(init_response_payload)

      assert init_response["id"] == 1
      assert init_response["result"]["protocolVersion"] == 1
      assert init_response["result"]["_meta"]["name"] == "TestAgent"

      # Step 2: Authenticate
      auth_req = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "authenticate",
        "params" => %{"methodId" => "token"}
      }

      send(agent_conn, {:message, auth_req})
      assert_receive {:transport_data, auth_response_payload}
      auth_response = parse_response(auth_response_payload)

      assert auth_response["id"] == 2
      assert auth_response["result"]["authenticated"] == true

      # Step 3: Create new session
      new_session_req = %{
        "jsonrpc" => "2.0",
        "id" => 3,
        "method" => "session/new",
        "params" => %{}
      }

      send(agent_conn, {:message, new_session_req})
      assert_receive {:transport_data, session_response_payload}
      session_response = parse_response(session_response_payload)

      assert session_response["id"] == 3
      session_id = session_response["result"]["sessionId"]
      assert is_binary(session_id)

      # Step 4: Send prompt
      prompt_req = %{
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id,
          "prompt" => [%{"type" => "text", "text" => "Hello, agent!"}]
        }
      }

      send(agent_conn, {:message, prompt_req})
      assert_receive {:transport_data, prompt_response_payload}
      prompt_response = parse_response(prompt_response_payload)

      assert prompt_response["id"] == 4
      assert prompt_response["result"]["stopReason"] == "done"
    end

    test "authentication failure returns error" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: TestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      auth_req = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "authenticate",
        "params" => %{"methodId" => "invalid_method"}
      }

      send(agent_conn, {:message, auth_req})
      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == 1
      assert response["error"]["code"] == -32_000
      assert response["error"]["message"] == "Invalid authentication method"
    end

    @tag capture_log: true
    test "unknown session_id returns error" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: TestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      prompt_req = %{
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => "non-existent-session",
          "prompt" => [%{"type" => "text", "text" => "Hello"}]
        }
      }

      send(agent_conn, {:message, prompt_req})
      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == 1
      assert response["error"]["code"] == -32_001
      assert response["error"]["message"] =~ "Unknown session_id"
    end
  end

  describe "bidirectional communication" do
    test "agent can send requests to client and receive responses" do
      {:ok, client_transport} = MockTransport.start_link(self())

      {:ok, client_conn} =
        Connection.start_link(
          handler_module: TestClient,
          handler_args: [test_pid: self()],
          role: :client,
          transport_pid: client_transport
        )

      # Simulate agent sending a fs/read_text_file request to client
      read_req = %{
        "jsonrpc" => "2.0",
        "id" => 100,
        "method" => "fs/read_text_file",
        "params" => %{"path" => "/test.txt"}
      }

      send(client_conn, {:message, read_req})
      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == 100
      assert response["result"]["content"] == "test content"
    end

    test "client can handle terminal operations from agent" do
      {:ok, client_transport} = MockTransport.start_link(self())

      {:ok, client_conn} =
        Connection.start_link(
          handler_module: TestClient,
          handler_args: [test_pid: self()],
          role: :client,
          transport_pid: client_transport
        )

      # Agent creates a terminal
      create_req = %{
        "jsonrpc" => "2.0",
        "id" => 200,
        "method" => "terminal/create",
        "params" => %{"command" => "ls -la"}
      }

      send(client_conn, {:message, create_req})
      assert_receive {:transport_data, create_response_payload}
      create_response = parse_response(create_response_payload)

      assert create_response["id"] == 200
      terminal_id = create_response["result"]["terminalId"]
      assert String.starts_with?(terminal_id, "term-")

      # Agent reads terminal output
      output_req = %{
        "jsonrpc" => "2.0",
        "id" => 201,
        "method" => "terminal/output",
        "params" => %{"terminalId" => terminal_id}
      }

      send(client_conn, {:message, output_req})
      assert_receive {:transport_data, output_response_payload}
      output_response = parse_response(output_response_payload)

      assert output_response["id"] == 201
      assert output_response["result"]["output"] == "command output"
    end
  end

  describe "error propagation" do
    test "protocol violations are properly reported" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: TestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Send request with unsupported method
      invalid_req = %{
        "jsonrpc" => "2.0",
        "id" => 999,
        "method" => "unsupported/method",
        "params" => %{}
      }

      send(agent_conn, {:message, invalid_req})
      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == 999
      assert response["error"]["code"] == -32_601
      assert response["error"]["message"] =~ "Method not found"
    end
  end

  describe "concurrent sessions" do
    test "multiple sessions can operate independently" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: TestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Create first session
      new_session_req1 = %{
        "jsonrpc" => "2.0",
        "id" => 10,
        "method" => "session/new",
        "params" => %{}
      }

      send(agent_conn, {:message, new_session_req1})
      assert_receive {:transport_data, session1_payload}
      session1_response = parse_response(session1_payload)
      session_id1 = session1_response["result"]["sessionId"]

      # Create second session
      new_session_req2 = %{
        "jsonrpc" => "2.0",
        "id" => 11,
        "method" => "session/new",
        "params" => %{}
      }

      send(agent_conn, {:message, new_session_req2})
      assert_receive {:transport_data, session2_payload}
      session2_response = parse_response(session2_payload)
      session_id2 = session2_response["result"]["sessionId"]

      # Verify different session IDs
      assert session_id1 != session_id2

      # Send prompts to both sessions
      prompt_req1 = %{
        "jsonrpc" => "2.0",
        "id" => 12,
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id1,
          "prompt" => [%{"type" => "text", "text" => "Session 1"}]
        }
      }

      prompt_req2 = %{
        "jsonrpc" => "2.0",
        "id" => 13,
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id2,
          "prompt" => [%{"type" => "text", "text" => "Session 2"}]
        }
      }

      send(agent_conn, {:message, prompt_req1})
      send(agent_conn, {:message, prompt_req2})

      # Both sessions should respond independently
      # Collect both responses (order not guaranteed)
      assert_receive {:transport_data, payload1}
      assert_receive {:transport_data, payload2}

      response1 = parse_response(payload1)
      response2 = parse_response(payload2)

      # Match responses to requests by ID
      responses_by_id = %{
        response1["id"] => response1,
        response2["id"] => response2
      }

      prompt1_response = responses_by_id[12]
      prompt2_response = responses_by_id[13]

      assert prompt1_response["result"]["stopReason"] == "done"
      assert prompt2_response["result"]["stopReason"] == "done"
    end
  end

  # Helper to parse transport response (ndjson format)
  defp parse_response(response_payload) do
    response_payload
    |> String.trim()
    |> Jason.decode!()
  end
end
