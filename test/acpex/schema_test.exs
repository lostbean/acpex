defmodule ACPex.SchemaTest do
  @moduledoc """
  Tests demonstrating the new Ecto-based schema system.

  These tests show how to use the new schemas with automatic camelCase ↔ snake_case
  conversion via the ACPex.Schema.Codec module.
  """
  use ExUnit.Case, async: true

  alias ACPex.Schema.Codec
  alias ACPex.Schema.Connection.{InitializeRequest, InitializeResponse}
  alias ACPex.Schema.Session.{NewRequest, PromptRequest}

  describe "InitializeRequest with new schemas" do
    test "can create struct with snake_case fields" do
      request = %InitializeRequest{
        protocol_version: 1,
        client_capabilities: %{"sessions" => %{"new" => true}}
      }

      assert request.protocol_version == 1
      assert request.client_capabilities == %{"sessions" => %{"new" => true}}
    end

    test "encodes to JSON with camelCase keys" do
      request = %InitializeRequest{
        protocol_version: 1,
        client_capabilities: %{"sessions" => %{"new" => true}}
      }

      json = Codec.encode!(request)

      assert json =~ ~s("protocolVersion":1)
      assert json =~ ~s("clientCapabilities")
      refute json =~ "protocol_version"
      refute json =~ "client_capabilities"
    end

    test "decodes from JSON with camelCase keys" do
      json = ~s({"protocolVersion":1,"clientCapabilities":{"sessions":{"new":true}}})

      {:ok, request} = Codec.decode(json, InitializeRequest)

      assert request.protocol_version == 1
      assert request.client_capabilities == %{"sessions" => %{"new" => true}}
    end

    test "round-trip encode and decode preserves data" do
      original = %InitializeRequest{
        protocol_version: 1,
        client_capabilities: %{"test" => true}
      }

      json = Codec.encode!(original)
      {:ok, decoded} = Codec.decode(json, InitializeRequest)

      assert decoded.protocol_version == original.protocol_version
      assert decoded.client_capabilities == original.client_capabilities
    end
  end

  describe "InitializeResponse with new schemas" do
    test "can create struct with agent capabilities" do
      response = %InitializeResponse{
        protocol_version: 1,
        agent_capabilities: %{"sessions" => %{"new" => true, "load" => false}}
      }

      assert response.protocol_version == 1
      assert response.agent_capabilities["sessions"]["new"] == true
    end

    test "encodes and decodes correctly" do
      response = %InitializeResponse{
        protocol_version: 1,
        agent_capabilities: %{"sessions" => %{"new" => true}}
      }

      json = Codec.encode!(response)
      {:ok, decoded} = Codec.decode(json, InitializeResponse)

      assert decoded.protocol_version == response.protocol_version
      assert decoded.agent_capabilities == response.agent_capabilities
    end
  end

  describe "NewRequest with new schemas" do
    test "can create struct with required fields" do
      request = %NewRequest{
        cwd: "/path/to/project",
        mcp_servers: []
      }

      assert request.cwd == "/path/to/project"
      assert request.mcp_servers == []
    end

    test "encodes mcpServers field with camelCase" do
      request = %NewRequest{
        cwd: "/project",
        mcp_servers: [%{"name" => "test-server"}]
      }

      json = Codec.encode!(request)

      assert json =~ ~s("mcpServers")
      refute json =~ "mcp_servers"
    end
  end

  describe "PromptRequest with new schemas" do
    test "can create struct with prompt content" do
      request = %PromptRequest{
        session_id: "session-123",
        prompt: [%{"type" => "text", "text" => "Hello, agent!"}]
      }

      assert request.session_id == "session-123"
      assert length(request.prompt) == 1
    end

    test "encodes sessionId field with camelCase" do
      request = %PromptRequest{
        session_id: "session-123",
        prompt: [%{"type" => "text", "text" => "test"}]
      }

      json = Codec.encode!(request)

      assert json =~ ~s("sessionId":"session-123")
      refute json =~ "session_id"
    end

    test "round-trip encode and decode" do
      original = %PromptRequest{
        session_id: "abc-123",
        prompt: [%{"type" => "text", "text" => "Hello!"}]
      }

      json = Codec.encode!(original)
      {:ok, decoded} = Codec.decode(json, PromptRequest)

      assert decoded.session_id == original.session_id
      assert decoded.prompt == original.prompt
    end
  end

  describe "Codec module features" do
    test "encode_to_map! returns map with camelCase keys" do
      request = %InitializeRequest{
        protocol_version: 1,
        client_capabilities: %{}
      }

      map = Codec.encode_to_map!(request)

      assert is_map(map)
      assert map["protocolVersion"] == 1
      assert Map.has_key?(map, "clientCapabilities")
    end

    test "decode_from_map! converts map to struct" do
      map = %{
        "protocolVersion" => 1,
        "clientCapabilities" => %{"test" => true}
      }

      request = Codec.decode_from_map!(map, InitializeRequest)

      assert %InitializeRequest{} = request
      assert request.protocol_version == 1
      assert request.client_capabilities == %{"test" => true}
    end

    test "nil values are omitted from encoded output" do
      request = %InitializeRequest{
        protocol_version: 1,
        client_capabilities: nil,
        meta: nil
      }

      json = Codec.encode!(request)

      assert json =~ ~s("protocolVersion":1)
      refute json =~ "clientCapabilities"
      refute json =~ "meta"
    end
  end
end
