defmodule ACPex.Protocol.ConnectionTest do
  use ExUnit.Case

  alias ACPex.Protocol.Connection
  alias ACPex.Test.MockTransport

  defmodule TestHandler do
    @behaviour ACPex.Agent

    def init(_args), do: {:ok, %{}}

    def handle_initialize(_params, state) do
      response = %{"protocol_version" => "1.0", "capabilities" => %{}}
      {:ok, response, state}
    end

    # Add other callbacks as needed for testing
    def handle_new_session(params, state), do: {:ok, params, state}
    def handle_load_session(params, state), do: {:ok, params, state}
    def handle_prompt(params, state), do: {:ok, params, state}
    def handle_session_prompt(_params, state), do: {:ok, %{"content" => "prompt response"}, state}
    def handle_cancel(_params, state), do: {:noreply, state}
    def handle_authenticate(params, state), do: {:ok, params, state}
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

    response =
      response_payload |> String.split("\r\n\r\n", parts: 2) |> Enum.at(1) |> Jason.decode!()

    assert response["id"] == 1
    assert response["result"] == %{"protocol_version" => "1.0", "capabilities" => %{}}
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

    response =
      response_payload |> String.split("\r\n\r\n", parts: 2) |> Enum.at(1) |> Jason.decode!()

    assert response["id"] == 2
    assert is_binary(response["result"]["session_id"])
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

    new_session_resp =
      new_session_payload
      |> String.split("\r\n\r\n", parts: 2)
      |> Enum.at(1)
      |> Jason.decode!()

    session_id = new_session_resp["result"]["session_id"]
    assert is_binary(session_id)

    # 2. Send a prompt to the new session
    prompt_req = %{
      "jsonrpc" => "2.0",
      "id" => "prompt-req",
      "method" => "session/prompt",
      "params" => %{"content" => "Hello there"},
      "session_id" => session_id
    }

    send(conn, {:message, prompt_req})
    assert_receive {:transport_data, prompt_payload}

    prompt_resp =
      prompt_payload |> String.split("\r\n\r\n", parts: 2) |> Enum.at(1) |> Jason.decode!()

    assert prompt_resp["id"] == "prompt-req"
    assert prompt_resp["result"] == %{"content" => "prompt response"}
  end

  test "properly extracts agent_path from nested opts for client role" do
    {:ok, transport_pid} = MockTransport.start_link(self())

    # This should not crash - agent_path should be extracted from nested opts
    result = Connection.start_link(
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
    result = Connection.start_link(
      handler_module: TestHandler,
      handler_args: [],
      role: :client,
      opts: []
    )

    # Should fail because agent_path is required when no transport_pid
    assert {:error, _reason} = result
  end
end
