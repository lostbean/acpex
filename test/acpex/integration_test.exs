defmodule ACPex.IntegrationTest do
  @moduledoc """
  Integration tests for the full message flow through Transport -> Connection -> Session.

  These tests verify that the complete protocol lifecycle works correctly
  with all layers of the OTP architecture interacting properly.
  """
  use ExUnit.Case

  alias ACPex.Protocol.Connection
  alias ACPex.Test.MockTransport

  defmodule TestAgent do
    @behaviour ACPex.Agent

    def init(_args), do: {:ok, %{sessions: %{}}}

    def handle_initialize(_params, state) do
      response = %{
        "protocol_version" => "1.0",
        "capabilities" => %{
          "sessions" => %{"new" => true, "load" => false}
        },
        "agent_info" => %{
          "name" => "TestAgent",
          "version" => "1.0.0"
        }
      }

      {:ok, response, state}
    end

    def handle_authenticate(%{"token" => token}, state) do
      if token == "valid_token" do
        {:ok, %{"authenticated" => true}, state}
      else
        {:error, %{"code" => -32_000, "message" => "Invalid token"}, state}
      end
    end

    def handle_new_session(_params, state) do
      session_state = %{messages: []}
      {:ok, %{}, Map.put(state, :session_state, session_state)}
    end

    def handle_prompt(params, state) do
      # Fallback handler
      handle_session_prompt(params, state)
    end

    def handle_session_prompt(params, state) do
      # Simulate processing and return response
      content = params["content"]

      response = %{
        "stop_reason" => "done",
        "content" => "Processed: #{content}"
      }

      {:ok, response, state}
    end

    def handle_session_cancel(_params, state) do
      {:noreply, state}
    end

    def handle_cancel(_params, state) do
      {:noreply, state}
    end

    def handle_load_session(_params, state) do
      {:error, %{"code" => -32_001, "message" => "Session not found"}, state}
    end
  end

  defmodule TestClient do
    @behaviour ACPex.Client

    def init(args) do
      test_pid = Keyword.fetch!(args, :test_pid)
      {:ok, %{test_pid: test_pid, files: %{"/test.txt" => "test content"}}}
    end

    def handle_session_update(params, state) do
      send(state.test_pid, {:session_update, params})
      {:noreply, state}
    end

    def handle_fs_read_text_file(%{"path" => path}, state) do
      case Map.get(state.files, path) do
        nil ->
          {:error, %{"code" => -32_001, "message" => "File not found"}, state}

        content ->
          {:ok, %{"content" => content}, state}
      end
    end

    def handle_fs_write_text_file(%{"path" => path, "content" => content}, state) do
      new_files = Map.put(state.files, path, content)
      {:ok, %{"bytes_written" => byte_size(content)}, %{state | files: new_files}}
    end

    def handle_terminal_create(%{"command" => _command}, state) do
      terminal_id = "term-" <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
      {:ok, %{"terminal_id" => terminal_id}, state}
    end

    def handle_terminal_output(%{"terminal_id" => _id}, state) do
      {:ok, %{"output" => "command output"}, state}
    end

    def handle_terminal_wait_for_exit(%{"terminal_id" => _id}, state) do
      {:ok, %{"exit_code" => 0}, state}
    end

    def handle_terminal_kill(%{"terminal_id" => _id}, state) do
      {:ok, %{}, state}
    end

    def handle_terminal_release(%{"terminal_id" => _id}, state) do
      {:ok, %{}, state}
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
      assert init_response["result"]["protocol_version"] == "1.0"
      assert init_response["result"]["agent_info"]["name"] == "TestAgent"

      # Step 2: Authenticate
      auth_req = %{
        "jsonrpc" => "2.0",
        "id" => 2,
        "method" => "authenticate",
        "params" => %{"token" => "valid_token"}
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
      session_id = session_response["result"]["session_id"]
      assert is_binary(session_id)

      # Step 4: Send prompt
      prompt_req = %{
        "jsonrpc" => "2.0",
        "id" => 4,
        "method" => "session/prompt",
        "params" => %{
          "session_id" => session_id,
          "content" => "Hello, agent!"
        }
      }

      send(agent_conn, {:message, prompt_req})
      assert_receive {:transport_data, prompt_response_payload}
      prompt_response = parse_response(prompt_response_payload)

      assert prompt_response["id"] == 4
      assert prompt_response["result"]["stop_reason"] == "done"
      assert prompt_response["result"]["content"] == "Processed: Hello, agent!"
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
        "params" => %{"token" => "invalid_token"}
      }

      send(agent_conn, {:message, auth_req})
      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == 1
      assert response["error"]["code"] == -32_000
      assert response["error"]["message"] == "Invalid token"
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
          "session_id" => "non-existent-session",
          "content" => "Hello"
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
      terminal_id = create_response["result"]["terminal_id"]
      assert String.starts_with?(terminal_id, "term-")

      # Agent reads terminal output
      output_req = %{
        "jsonrpc" => "2.0",
        "id" => 201,
        "method" => "terminal/output",
        "params" => %{"terminal_id" => terminal_id}
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
      session_id1 = session1_response["result"]["session_id"]

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
      session_id2 = session2_response["result"]["session_id"]

      # Verify different session IDs
      assert session_id1 != session_id2

      # Send prompts to both sessions
      prompt_req1 = %{
        "jsonrpc" => "2.0",
        "id" => 12,
        "method" => "session/prompt",
        "params" => %{"session_id" => session_id1, "content" => "Session 1"}
      }

      prompt_req2 = %{
        "jsonrpc" => "2.0",
        "id" => 13,
        "method" => "session/prompt",
        "params" => %{"session_id" => session_id2, "content" => "Session 2"}
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

      assert prompt1_response["result"]["content"] =~ "Session 1"
      assert prompt2_response["result"]["content"] =~ "Session 2"
    end
  end

  # Helper to parse transport response (ndjson format)
  defp parse_response(response_payload) do
    response_payload
    |> String.trim()
    |> Jason.decode!()
  end
end
