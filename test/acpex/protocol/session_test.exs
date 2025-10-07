defmodule ACPex.Protocol.SessionTest do
  use ExUnit.Case

  @moduletag capture_log: true

  alias ACPex.Protocol.Session
  alias ACPex.Test.MockTransport

  defmodule TestHandler do
    @behaviour ACPex.Agent

    alias ACPex.Schema.Connection.{InitializeResponse, AuthenticateResponse}
    alias ACPex.Schema.Session.{NewResponse, PromptResponse}

    def init(_args), do: {:ok, %{}}

    def handle_new_session(_params, state) do
      {:ok, %NewResponse{}, state}
    end

    def handle_session_prompt(_params, state) do
      {:ok, %PromptResponse{stop_reason: "done"}, state}
    end

    def handle_initialize(_params, state) do
      {:ok, %InitializeResponse{protocol_version: 1, agent_capabilities: %{}}, state}
    end

    def handle_load_session(_params, state) do
      {:error, %{code: -32_001, message: "Not supported"}, state}
    end

    def handle_prompt(_params, state) do
      {:ok, %PromptResponse{stop_reason: "done"}, state}
    end

    def handle_cancel(_params, state), do: {:noreply, state}

    def handle_authenticate(_params, state) do
      {:ok, %AuthenticateResponse{authenticated: true}, state}
    end
  end

  defmodule TestClientHandler do
    @behaviour ACPex.Client

    alias ACPex.Schema.Client.{FsReadTextFileResponse, FsWriteTextFileResponse}
    alias ACPex.Schema.Client.Terminal

    def init(_args), do: {:ok, %{}}
    def handle_session_update(_params, state), do: {:noreply, state}

    def handle_fs_read_text_file(request, state) do
      response = %FsReadTextFileResponse{
        content: "file content from #{request.path}"
      }

      {:ok, response, state}
    end

    def handle_fs_write_text_file(_request, state) do
      {:ok, %FsWriteTextFileResponse{}, state}
    end

    def handle_terminal_create(_request, state) do
      response = %Terminal.CreateResponse{terminal_id: "term-123"}
      {:ok, response, state}
    end

    def handle_terminal_output(_request, state) do
      response = %Terminal.OutputResponse{
        output: "command output",
        truncated: false
      }

      {:ok, response, state}
    end

    def handle_terminal_wait_for_exit(_request, state) do
      response = %Terminal.WaitForExitResponse{exit_code: 0}
      {:ok, response, state}
    end

    def handle_terminal_kill(_request, state) do
      {:ok, %Terminal.KillResponse{}, state}
    end

    def handle_terminal_release(_request, state) do
      {:ok, %Terminal.ReleaseResponse{}, state}
    end
  end

  setup do
    {:ok, transport_pid} = MockTransport.start_link(self())

    start_opts = %{
      handler_module: TestHandler,
      initial_handler_state: %{},
      transport_pid: transport_pid
    }

    {:ok, session_pid} = Session.start_link(start_opts)

    on_exit(fn ->
      # Stop session first (it may hold references to transport)
      if Process.alive?(session_pid) do
        try do
          GenServer.stop(session_pid)
        catch
          :exit, _ -> :ok
        end
      end

      # Then stop transport
      if Process.alive?(transport_pid) do
        try do
          GenServer.stop(transport_pid)
        catch
          :exit, _ -> :ok
        end
      end
    end)

    %{session: session_pid, transport: transport_pid, handler: TestHandler}
  end

  describe "session/new request" do
    test "creates new session and returns session_id", %{session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "new-session-req",
        "method" => "session/new",
        "params" => %{}
      }

      send(session, {:request, self(), request})

      assert_receive {:session_started, session_id, session_pid}
      assert is_binary(session_id)
      assert session_pid == session

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)
      assert response["id"] == "new-session-req"
      assert response["result"]["sessionId"] == session_id
    end
  end

  describe "session/prompt request" do
    test "handles session-level prompt request", %{session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "request-id-1",
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => "test-session-id",
          "prompt" => [%{"type" => "text", "text" => "Hello"}]
        }
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "request-id-1"
      assert response["result"]["stopReason"] == "done"
    end
  end

  describe "session/cancel notification" do
    test "handles cancel notification without id", %{session: session} do
      notification = %{
        "jsonrpc" => "2.0",
        "method" => "session/cancel",
        "params" => %{}
      }

      send(session, {:forward, notification})

      # Notification should not produce a response
      refute_receive {:transport_data, _}, 100
    end
  end

  describe "filesystem operations" do
    setup do
      {:ok, transport_pid} = MockTransport.start_link(self())

      start_opts = %{
        handler_module: TestClientHandler,
        initial_handler_state: %{},
        transport_pid: transport_pid
      }

      {:ok, session_pid} = Session.start_link(start_opts)
      %{client_session: session_pid, client_transport: transport_pid}
    end

    test "handles fs/read_text_file request", %{client_session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "read-req",
        "method" => "fs/read_text_file",
        "params" => %{"path" => "/tmp/test.txt"}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "read-req"
      assert response["result"]["content"] == "file content from /tmp/test.txt"
    end

    test "handles fs/write_text_file request", %{client_session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "write-req",
        "method" => "fs/write_text_file",
        "params" => %{"path" => "/tmp/output.txt", "content" => "Hello World"}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "write-req"
      # FsWriteTextFileResponse is empty
      assert response["result"] == %{}
    end
  end

  describe "terminal operations" do
    setup do
      {:ok, transport_pid} = MockTransport.start_link(self())

      start_opts = %{
        handler_module: TestClientHandler,
        initial_handler_state: %{},
        transport_pid: transport_pid
      }

      {:ok, session_pid} = Session.start_link(start_opts)
      %{client_session: session_pid, client_transport: transport_pid}
    end

    test "handles terminal/create request", %{client_session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "term-create",
        "method" => "terminal/create",
        "params" => %{"command" => "echo hello"}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "term-create"
      assert response["result"]["terminalId"] == "term-123"
    end

    test "handles terminal/output request", %{client_session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "term-output",
        "method" => "terminal/output",
        "params" => %{"terminal_id" => "term-123"}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "term-output"
      assert response["result"]["output"] == "command output"
    end

    test "handles terminal/wait_for_exit request", %{client_session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "term-wait",
        "method" => "terminal/wait_for_exit",
        "params" => %{"terminal_id" => "term-123"}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "term-wait"
      assert response["result"]["exitCode"] == 0
    end

    test "handles terminal/kill request", %{client_session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "term-kill",
        "method" => "terminal/kill",
        "params" => %{"terminal_id" => "term-123"}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "term-kill"
      assert response["result"] == %{}
    end

    test "handles terminal/release request", %{client_session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "term-release",
        "method" => "terminal/release",
        "params" => %{"terminal_id" => "term-123"}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "term-release"
      assert response["result"] == %{}
    end
  end

  describe "error handling" do
    test "returns error for unsupported method", %{session: session} do
      request = %{
        "jsonrpc" => "2.0",
        "id" => "unknown-method",
        "method" => "unknown/method",
        "params" => %{}
      }

      send(session, {:forward, request})

      assert_receive {:transport_data, response_payload}
      response = parse_response(response_payload)

      assert response["id"] == "unknown-method"
      assert response["error"]["code"] == -32_601
      assert response["error"]["message"] =~ "Method not found"
    end
  end

  # Helper function to parse response
  defp parse_response(response_payload) do
    response_payload
    |> String.trim()
    |> Jason.decode!()
  end
end
