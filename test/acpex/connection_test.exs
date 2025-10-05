defmodule ACPex.ConnectionTest do
  use ExUnit.Case

  alias ACPex.Connection
  alias ACPex.Test.MockTransport

  defmodule TestClient do
    @behaviour ACPex.Client

    def init(test_pid: test_pid), do: {:ok, %{test_pid: test_pid}}

    def handle_session_update(params, state) do
      send(state.test_pid, {:session_update, params})
      {:noreply, state}
    end

    def handle_fs_read_text_file(%{"path" => "/foo.txt"}, state) do
      {:ok, %{"content" => "bar"}, state}
    end

    def handle_fs_write_text_file(_params, state),
      do: {:error, %{code: -32601, message: "Not implemented"}, state}

    def handle_terminal_create(_params, state),
      do: {:error, %{code: -32601, message: "Not implemented"}, state}

    def handle_terminal_output(_params, state),
      do: {:error, %{code: -32601, message: "Not implemented"}, state}

    def handle_terminal_wait_for_exit(_params, state),
      do: {:error, %{code: -32601, message: "Not implemented"}, state}

    def handle_terminal_kill(_params, state),
      do: {:error, %{code: -32601, message: "Not implemented"}, state}

    def handle_terminal_release(_params, state),
      do: {:error, %{code: -32601, message: "Not implemented"}, state}
  end

  setup do
    # Start the mock transport and link it to the test process
    {:ok, transport_pid} = MockTransport.start_link(self())

    # Ensure the transport process is terminated when the test exits
    on_exit(fn -> if Process.alive?(transport_pid), do: GenServer.stop(transport_pid) end)

    # Start the connection, passing the transport PID
    {:ok, conn} =
      Connection.start_link(
        handler_module: TestClient,
        handler_args: [test_pid: self()],
        role: :client,
        transport_pid: transport_pid,
        opts: []
      )

    %{conn: conn}
  end

  test "handles incoming notifications", %{conn: conn} do
    # Simulate a notification coming from the agent
    notification = %{
      "jsonrpc" => "2.0",
      "method" => "session/update",
      "params" => %{"session_id" => "123", "update" => %{"kind" => "test"}}
    }

    # Send the raw message to the connection process
    send(conn, {:stdio_data, encode_message(notification)})

    # Assert that the client's callback was called
    assert_receive {:session_update, %{"session_id" => "123", "update" => %{"kind" => "test"}}}
  end

  test "handles outgoing requests and receives responses", %{conn: conn} do
    # Simulate the agent making a request to the client
    request = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "fs/read_text_file",
      "params" => %{"path" => "/foo.txt"}
    }

    send(conn, {:stdio_data, encode_message(request)})

    # Assert that the mock transport received the response
    assert_receive {:transport_data, response_payload}

    response = Jason.decode!(response_payload |> String.split("\r\n\r\n", parts: 2) |> Enum.at(1))

    assert response["id"] == 1
    assert response["result"] == %{"content" => "bar"}
  end

  defp encode_message(message) do
    json = Jason.encode!(message)
    "Content-Length: " <> Integer.to_string(byte_size(json)) <> "\r\n\r\n" <> json
  end
end
