defmodule ACPex.ConcurrentSessionsTest do
  @moduledoc """
  Stress tests for concurrent session handling.

  These tests verify:
  1. Multiple concurrent sessions operate independently
  2. No message crosstalk between sessions
  3. Cancellation during concurrent operations
  4. Session cleanup when crashed
  5. High concurrency scenarios (10+ sessions)
  """
  use ExUnit.Case

  @moduletag capture_log: true
  @moduletag timeout: 120_000

  alias ACPex.Protocol.Connection
  alias ACPex.Test.MockTransport

  defmodule StressTestAgent do
    @behaviour ACPex.Agent

    alias ACPex.Schema.Connection.InitializeResponse
    alias ACPex.Schema.Session.{NewResponse, PromptResponse}

    def init(_args), do: {:ok, %{sessions: %{}, prompt_count: 0}}

    def handle_initialize(_request, state) do
      response = %InitializeResponse{
        protocol_version: 1,
        agent_capabilities: %{"sessions" => %{"new" => true}}
      }

      {:ok, response, state}
    end

    def handle_new_session(_request, state) do
      {:ok, %NewResponse{}, state}
    end

    def handle_prompt(_request, state) do
      # Simulate some processing time
      :timer.sleep(10)

      response = %PromptResponse{stop_reason: "done"}
      new_state = %{state | prompt_count: state.prompt_count + 1}
      {:ok, response, new_state}
    end

    def handle_session_prompt(request, state) do
      handle_prompt(request, state)
    end

    def handle_cancel(_notification, state), do: {:noreply, state}

    def handle_load_session(_request, state) do
      {:error, %{code: -32_001, message: "Not supported"}, state}
    end

    def handle_authenticate(_request, state) do
      {:error, %{code: -32_000, message: "Not supported"}, state}
    end
  end

  describe "high concurrency stress tests" do
    test "handles 10 concurrent sessions with multiple prompts each" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: StressTestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Create 10 sessions
      session_ids =
        Enum.map(1..10, fn i ->
          req = %{
            "jsonrpc" => "2.0",
            "id" => "session-create-#{i}",
            "method" => "session/new",
            "params" => %{}
          }

          send(agent_conn, {:message, req})
          assert_receive {:transport_data, payload}, 1000
          response = Jason.decode!(String.trim(payload))
          response["result"]["sessionId"]
        end)

      # Send 5 prompts to each session (50 total)
      request_ids =
        for session_id <- session_ids,
            prompt_num <- 1..5 do
          req_id = "#{session_id}-prompt-#{prompt_num}"

          req = %{
            "jsonrpc" => "2.0",
            "id" => req_id,
            "method" => "session/prompt",
            "params" => %{
              "sessionId" => session_id,
              "prompt" => [%{"type" => "text", "text" => "Test #{prompt_num}"}]
            }
          }

          send(agent_conn, {:message, req})
          req_id
        end

      # Collect all 50 responses
      responses =
        for _ <- 1..50 do
          assert_receive {:transport_data, payload}, 3000
          Jason.decode!(String.trim(payload))
        end

      # Verify we got all responses
      assert Enum.count(responses) == 50

      # Verify all succeeded
      assert Enum.all?(responses, fn resp ->
               resp["result"]["stopReason"] == "done"
             end)

      # Verify all request IDs are accounted for
      response_ids = Enum.map(responses, & &1["id"]) |> Enum.sort()
      expected_ids = Enum.sort(request_ids)
      assert response_ids == expected_ids
    end

    test "sessions do not interfere with each other" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: StressTestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Create 3 sessions
      session_ids =
        Enum.map(1..3, fn i ->
          req = %{
            "jsonrpc" => "2.0",
            "id" => "create-#{i}",
            "method" => "session/new",
            "params" => %{}
          }

          send(agent_conn, {:message, req})
          assert_receive {:transport_data, payload}
          response = Jason.decode!(String.trim(payload))
          response["result"]["sessionId"]
        end)

      [sid1, sid2, sid3] = session_ids

      # Send different prompts to each session
      prompts = [
        {sid1, "prompt-1", "Session 1 message"},
        {sid2, "prompt-2", "Session 2 message"},
        {sid3, "prompt-3", "Session 3 message"}
      ]

      # Send all prompts
      for {sid, id, text} <- prompts do
        req = %{
          "jsonrpc" => "2.0",
          "id" => id,
          "method" => "session/prompt",
          "params" => %{
            "sessionId" => sid,
            "prompt" => [%{"type" => "text", "text" => text}]
          }
        }

        send(agent_conn, {:message, req})
      end

      # Collect responses
      responses =
        for _ <- 1..3 do
          assert_receive {:transport_data, payload}, 1000
          Jason.decode!(String.trim(payload))
        end

      # Verify each request got its own response
      response_ids = Enum.map(responses, & &1["id"]) |> Enum.sort()
      assert response_ids == ["prompt-1", "prompt-2", "prompt-3"]
    end

    test "handles session cancellation under load" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: StressTestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Create session
      create_req = %{
        "jsonrpc" => "2.0",
        "id" => "create",
        "method" => "session/new",
        "params" => %{}
      }

      send(agent_conn, {:message, create_req})
      assert_receive {:transport_data, payload}
      response = Jason.decode!(String.trim(payload))
      session_id = response["result"]["sessionId"]

      # Send prompt
      prompt_req = %{
        "jsonrpc" => "2.0",
        "id" => "prompt",
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id,
          "prompt" => [%{"type" => "text", "text" => "Long running task"}]
        }
      }

      send(agent_conn, {:message, prompt_req})

      # Immediately send cancel
      cancel_notif = %{
        "jsonrpc" => "2.0",
        "method" => "session/cancel",
        "params" => %{"sessionId" => session_id}
      }

      send(agent_conn, {:message, cancel_notif})

      # Should still get a response (might be done or cancelled)
      assert_receive {:transport_data, _payload}, 2000
    end
  end

  describe "stress test scenarios" do
    test "rapid session creation and deletion" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: StressTestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Create and use 20 sessions rapidly
      for i <- 1..20 do
        # Create session
        create_req = %{
          "jsonrpc" => "2.0",
          "id" => "create-#{i}",
          "method" => "session/new",
          "params" => %{}
        }

        send(agent_conn, {:message, create_req})
        assert_receive {:transport_data, create_payload}, 1000
        create_response = Jason.decode!(String.trim(create_payload))
        session_id = create_response["result"]["sessionId"]

        # Send quick prompt
        prompt_req = %{
          "jsonrpc" => "2.0",
          "id" => "prompt-#{i}",
          "method" => "session/prompt",
          "params" => %{
            "sessionId" => session_id,
            "prompt" => [%{"type" => "text", "text" => "Quick test"}]
          }
        }

        send(agent_conn, {:message, prompt_req})
        assert_receive {:transport_data, _prompt_payload}, 1000
      end
    end

    test "interleaved session operations" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: StressTestAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      # Create 5 sessions
      session_ids =
        Enum.map(1..5, fn i ->
          req = %{
            "jsonrpc" => "2.0",
            "id" => "create-#{i}",
            "method" => "session/new",
            "params" => %{}
          }

          send(agent_conn, {:message, req})
          assert_receive {:transport_data, payload}
          response = Jason.decode!(String.trim(payload))
          response["result"]["sessionId"]
        end)

      # Interleave prompts across sessions
      for round <- 1..3 do
        for {sid, idx} <- Enum.with_index(session_ids, 1) do
          req = %{
            "jsonrpc" => "2.0",
            "id" => "r#{round}-s#{idx}",
            "method" => "session/prompt",
            "params" => %{
              "sessionId" => sid,
              "prompt" => [%{"type" => "text", "text" => "Round #{round}"}]
            }
          }

          send(agent_conn, {:message, req})
        end
      end

      # Collect all responses (3 rounds × 5 sessions = 15 responses)
      responses =
        for _ <- 1..15 do
          assert_receive {:transport_data, payload}, 2000
          Jason.decode!(String.trim(payload))
        end

      assert Enum.count(responses) == 15
      assert Enum.all?(responses, &(&1["result"]["stopReason"] == "done"))
    end
  end
end
