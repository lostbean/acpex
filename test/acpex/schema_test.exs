defmodule ACPex.SchemaTest do
  use ExUnit.Case, async: true

  alias ACPex.Schema

  test "can create InitializeRequest struct" do
    params = %{
      protocol_version: "1.0",
      capabilities: %{},
      client_info: %{
        name: "test-client"
      }
    }

    struct = struct(Schema.InitializeRequest, params)
    assert struct.protocol_version == "1.0"
    assert struct.capabilities == %{}
    assert struct.client_info == %{name: "test-client"}
  end

  test "can create InitializeResponse struct" do
    params = %{
      protocol_version: "1.0",
      capabilities: %{},
      agent_info: %{
        name: "test-agent"
      }
    }

    struct = struct(Schema.InitializeResponse, params)
    assert struct.protocol_version == "1.0"
    assert struct.capabilities == %{}
    assert struct.agent_info == %{name: "test-agent"}
  end

  test "can create NewSessionRequest struct" do
    struct = struct(Schema.NewSessionRequest, %{session_id: "abc-123"})
    assert struct.session_id == "abc-123"
  end

  test "can create PromptRequest struct" do
    params = %{
      session_id: "abc-123",
      prompt: "Hello, agent!",
      context: %{}
    }

    struct = struct(Schema.PromptRequest, params)
    assert struct.session_id == "abc-123"
    assert struct.prompt == "Hello, agent!"
  end
end
