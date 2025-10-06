defmodule ACPex.Protocol.SessionTest do
  use ExUnit.Case

  alias ACPex.Protocol.Session
  alias ACPex.Test.MockTransport

  defmodule TestHandler do
    @behaviour ACPex.Agent

    def init(_args), do: {:ok, %{}}
    def handle_new_session(params, state), do: {:ok, params, state}
    def handle_session_prompt(_params, state), do: {:ok, %{"content" => "response"}, state}
    def handle_initialize(params, state), do: {:ok, params, state}
    def handle_load_session(params, state), do: {:ok, params, state}
    def handle_prompt(params, state), do: {:ok, params, state}
    def handle_cancel(_params, state), do: {:noreply, state}
    def handle_authenticate(params, state), do: {:ok, params, state}
  end

  setup do
    {:ok, transport_pid} = MockTransport.start_link(self())

    on_exit(fn ->
      if Process.alive?(transport_pid), do: GenServer.stop(transport_pid)
    end)

    start_opts = %{
      handler_module: TestHandler,
      initial_handler_state: %{},
      transport_pid: transport_pid
    }

    {:ok, session_pid} = Session.start_link(start_opts)
    %{session: session_pid, transport: transport_pid}
  end

  test "handles session-level prompt request", %{session: session, transport: _transport} do
    request = %{
      "jsonrpc" => "2.0",
      "id" => "request-id-1",
      "method" => "session/prompt",
      "params" => %{"content" => "Hello"},
      "session_id" => "session-id-1"
    }

    # The connection would send this message
    send(session, {:forward, request})

    assert_receive {:transport_data, response_payload}

    response =
      response_payload
      |> String.split("\r\n\r\n", parts: 2)
      |> Enum.at(1)
      |> Jason.decode!()

    assert response["id"] == "request-id-1"
    assert response["result"] == %{"content" => "response"}
  end
end
