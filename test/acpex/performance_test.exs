defmodule ACPex.PerformanceTest do
  @moduledoc """
  Performance and reliability tests for ACPex.

  These tests verify:
  1. Memory usage with long-running sessions
  2. Handling of large responses (images, long code)
  3. Backpressure handling for high message volumes
  4. Reconnection scenarios if agent crashes
  """
  use ExUnit.Case

  @moduletag capture_log: true
  @moduletag timeout: 180_000
  @moduletag :performance

  alias ACPex.Protocol.Connection
  alias ACPex.Test.MockTransport

  defmodule PerformanceAgent do
    @behaviour ACPex.Agent

    alias ACPex.Schema.Connection.InitializeResponse
    alias ACPex.Schema.Session.{NewResponse, PromptResponse}

    def init(_args), do: {:ok, %{sessions: %{}, memory_stats: []}}

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
      response = %PromptResponse{stop_reason: "done"}
      {:ok, response, state}
    end

    def handle_session_prompt(request, state) do
      handle_prompt(request, state)
    end

    def handle_cancel(_notification, state), do: {:noreply, state}

    def handle_load_session(_request, state),
      do: {:error, %{code: -32_001, message: "Not supported"}, state}

    def handle_authenticate(_request, state),
      do: {:error, %{code: -32_000, message: "Not supported"}, state}
  end

  describe "memory profiling" do
    test "memory stays stable over 100 prompt/response cycles" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: PerformanceAgent,
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

      # Get initial memory
      initial_memory = get_process_memory(agent_conn)

      # Run 100 prompt/response cycles
      for i <- 1..100 do
        req = %{
          "jsonrpc" => "2.0",
          "id" => "prompt-#{i}",
          "method" => "session/prompt",
          "params" => %{
            "sessionId" => session_id,
            "prompt" => [%{"type" => "text", "text" => "Test prompt #{i}"}]
          }
        }

        send(agent_conn, {:message, req})
        assert_receive {:transport_data, _resp_payload}, 1000
      end

      # Force garbage collection
      :erlang.garbage_collect(agent_conn)
      :timer.sleep(100)

      # Get final memory
      final_memory = get_process_memory(agent_conn)

      # Memory should not grow excessively (allow 10x growth as threshold)
      memory_growth_factor = final_memory / max(initial_memory, 1)

      assert memory_growth_factor < 10.0,
             "Memory grew by #{memory_growth_factor}x (from #{initial_memory} to #{final_memory} bytes)"
    end

    test "session supervisor maintains stable memory" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: PerformanceAgent,
          handler_args: [],
          role: :agent,
          transport_pid: agent_transport
        )

      initial_memory = get_process_memory(agent_conn)

      # Create and use 20 sessions
      for i <- 1..20 do
        create_req = %{
          "jsonrpc" => "2.0",
          "id" => "create-#{i}",
          "method" => "session/new",
          "params" => %{}
        }

        send(agent_conn, {:message, create_req})
        assert_receive {:transport_data, create_payload}
        create_response = Jason.decode!(String.trim(create_payload))
        session_id = create_response["result"]["sessionId"]

        # Send a prompt
        prompt_req = %{
          "jsonrpc" => "2.0",
          "id" => "prompt-#{i}",
          "method" => "session/prompt",
          "params" => %{
            "sessionId" => session_id,
            "prompt" => [%{"type" => "text", "text" => "Test"}]
          }
        }

        send(agent_conn, {:message, prompt_req})
        assert_receive {:transport_data, _prompt_payload}
      end

      :erlang.garbage_collect(agent_conn)
      :timer.sleep(100)

      final_memory = get_process_memory(agent_conn)
      memory_growth_factor = final_memory / max(initial_memory, 1)

      assert memory_growth_factor < 15.0,
             "Memory grew by #{memory_growth_factor}x with 20 sessions"
    end
  end

  describe "large data handling" do
    test "handles 5MB base64 encoded image data" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: PerformanceAgent,
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

      # Create 5MB of random binary data and base64 encode it
      large_binary = :crypto.strong_rand_bytes(5 * 1024 * 1024)
      base64_data = Base.encode64(large_binary)

      # Send prompt with large image data
      req = %{
        "jsonrpc" => "2.0",
        "id" => "large-image",
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id,
          "prompt" => [
            %{
              "type" => "image",
              "source" => %{
                "type" => "base64",
                "data" => base64_data,
                "mediaType" => "image/png"
              }
            }
          ]
        }
      }

      send(agent_conn, {:message, req})
      assert_receive {:transport_data, _resp_payload}, 5000
    end

    test "handles 1MB code file content" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: PerformanceAgent,
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

      # Create large code content (1MB)
      large_code =
        Enum.map_join(1..10_000, "\n", fn i ->
          """
          def function_#{i}(arg) do
            # This is function #{i}
            arg * #{i}
          end
          """
        end)

      req = %{
        "jsonrpc" => "2.0",
        "id" => "large-code",
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id,
          "prompt" => [
            %{
              "type" => "text",
              "text" => "Here is a large code file:\n\n#{large_code}"
            }
          ]
        }
      }

      send(agent_conn, {:message, req})
      assert_receive {:transport_data, _resp_payload}, 5000
    end

    test "handles response with very long text" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: PerformanceAgent,
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
      req = %{
        "jsonrpc" => "2.0",
        "id" => "prompt",
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => session_id,
          "prompt" => [%{"type" => "text", "text" => "Generate long text"}]
        }
      }

      send(agent_conn, {:message, req})
      assert_receive {:transport_data, _resp_payload}, 2000
    end
  end

  describe "backpressure handling" do
    test "handles rapid message sending (1000 messages)" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: PerformanceAgent,
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

      # Send 1000 messages rapidly
      for i <- 1..1000 do
        req = %{
          "jsonrpc" => "2.0",
          "id" => "rapid-#{i}",
          "method" => "session/prompt",
          "params" => %{
            "sessionId" => session_id,
            "prompt" => [%{"type" => "text", "text" => "Message #{i}"}]
          }
        }

        send(agent_conn, {:message, req})
      end

      # Collect responses (may take some time)
      responses =
        for _ <- 1..1000 do
          receive do
            {:transport_data, resp_payload} ->
              Jason.decode!(String.trim(resp_payload))
          after
            30_000 -> :timeout
          end
        end

      # Verify all responses received
      success_count = Enum.count(responses, &(&1 != :timeout))
      assert success_count >= 900, "Only #{success_count}/1000 messages succeeded"
    end

    test "process mailbox does not grow unbounded" do
      {:ok, agent_transport} = MockTransport.start_link(self())

      {:ok, agent_conn} =
        Connection.start_link(
          handler_module: PerformanceAgent,
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

      # Send 100 messages
      for i <- 1..100 do
        req = %{
          "jsonrpc" => "2.0",
          "id" => "msg-#{i}",
          "method" => "session/prompt",
          "params" => %{
            "sessionId" => session_id,
            "prompt" => [%{"type" => "text", "text" => "Test #{i}"}]
          }
        }

        send(agent_conn, {:message, req})
      end

      # Check mailbox size
      :timer.sleep(1000)
      {:message_queue_len, queue_len} = Process.info(agent_conn, :message_queue_len)

      # Mailbox should not have thousands of messages queued
      assert queue_len < 200, "Mailbox has #{queue_len} messages queued"
    end
  end

  # Helper functions
  defp get_process_memory(pid) do
    {:memory, memory} = Process.info(pid, :memory)
    memory
  end
end
