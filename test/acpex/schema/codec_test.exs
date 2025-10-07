defmodule ACPex.Schema.CodecTest do
  @moduledoc """
  Tests for the new Ecto-based schema system and Codec module.

  These tests verify that:
  1. Schemas can be encoded to JSON with camelCase keys
  2. JSON with camelCase keys can be decoded to schemas with snake_case fields
  3. The `:source` field mapping works correctly
  4. Nil values are omitted from encoded output
  5. Validation works via changesets
  """
  use ExUnit.Case, async: true

  alias ACPex.Schema.Codec
  alias ACPex.Schema.Connection.{InitializeRequest, InitializeResponse}
  alias ACPex.Schema.Session.{NewRequest, NewResponse, PromptRequest, PromptResponse}
  alias ACPex.Schema.Client.{FsReadTextFileRequest, FsReadTextFileResponse}

  describe "InitializeRequest" do
    test "encodes to JSON with camelCase keys" do
      request = %InitializeRequest{
        protocol_version: 1,
        client_capabilities: %{"sessions" => %{"new" => true}}
      }

      json = Codec.encode!(request)
      assert json =~ ~s("protocolVersion":1)
      assert json =~ ~s("clientCapabilities")
      refute json =~ "protocol_version"
    end

    test "decodes from JSON with camelCase keys" do
      json = ~s({"protocolVersion":1,"clientCapabilities":{"sessions":{"new":true}}})

      {:ok, request} = Codec.decode(json, InitializeRequest)

      assert request.protocol_version == 1
      assert request.client_capabilities == %{"sessions" => %{"new" => true}}
    end

    test "omits nil values when encoding" do
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

    test "validates required fields" do
      changeset = InitializeRequest.changeset(%{})
      refute changeset.valid?
      assert %{protocol_version: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates protocol_version is positive" do
      # Note: Ecto.embedded_load expects string keys for JSON format
      changeset =
        InitializeRequest.changeset(%InitializeRequest{protocol_version: 1}, %{
          protocol_version: 0
        })

      refute changeset.valid?
      assert %{protocol_version: ["must be greater than 0"]} = errors_on(changeset)
    end
  end

  describe "InitializeResponse" do
    test "encodes and decodes correctly" do
      response = %InitializeResponse{
        protocol_version: 1,
        agent_capabilities: %{"sessions" => %{"new" => true, "load" => false}}
      }

      json = Codec.encode!(response)
      assert json =~ ~s("protocolVersion":1)
      assert json =~ ~s("agentCapabilities")

      {:ok, decoded} = Codec.decode(json, InitializeResponse)
      assert decoded.protocol_version == 1
      assert decoded.agent_capabilities == %{"sessions" => %{"new" => true, "load" => false}}
    end
  end

  describe "NewRequest" do
    test "encodes mcpServers field correctly" do
      request = %NewRequest{
        cwd: "/path/to/project",
        mcp_servers: []
      }

      json = Codec.encode!(request)
      assert json =~ ~s("cwd":"/path/to/project")
      assert json =~ ~s("mcpServers":[])
      refute json =~ "mcp_servers"
    end

    test "decodes mcpServers field correctly" do
      json = ~s({"cwd":"/path/to/project","mcpServers":[]})

      {:ok, request} = Codec.decode(json, NewRequest)
      assert request.cwd == "/path/to/project"
      assert request.mcp_servers == []
    end

    test "validates required fields" do
      changeset = NewRequest.changeset(%{})
      refute changeset.valid?
      assert %{cwd: ["can't be blank"], mcp_servers: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "NewResponse" do
    test "encodes sessionId field correctly" do
      response = %NewResponse{
        session_id: "session-123"
      }

      json = Codec.encode!(response)
      assert json =~ ~s("sessionId":"session-123")
      refute json =~ "session_id"
    end

    test "decodes sessionId field correctly" do
      json = ~s({"sessionId":"session-123"})

      {:ok, response} = Codec.decode(json, NewResponse)
      assert response.session_id == "session-123"
    end
  end

  describe "PromptRequest" do
    test "encodes and decodes correctly" do
      request = %PromptRequest{
        session_id: "session-123",
        prompt: [%{"type" => "text", "text" => "Hello"}]
      }

      json = Codec.encode!(request)
      {:ok, decoded} = Codec.decode(json, PromptRequest)

      assert decoded.session_id == "session-123"
      assert decoded.prompt == [%{"type" => "text", "text" => "Hello"}]
    end
  end

  describe "PromptResponse" do
    test "validates stop_reason values" do
      valid_changeset = PromptResponse.changeset(%PromptResponse{}, %{stop_reason: "done"})
      assert valid_changeset.valid?

      invalid_changeset = PromptResponse.changeset(%PromptResponse{}, %{stop_reason: "invalid"})
      refute invalid_changeset.valid?
      assert %{stop_reason: ["is invalid"]} = errors_on(invalid_changeset)
    end

    test "encodes stopReason field correctly" do
      response = %PromptResponse{
        stop_reason: "done"
      }

      json = Codec.encode!(response)
      assert json =~ ~s("stopReason":"done")
      refute json =~ "stop_reason"
    end
  end

  describe "FsReadTextFileRequest" do
    test "encodes and decodes correctly" do
      request = %FsReadTextFileRequest{
        session_id: "session-123",
        path: "/path/to/file.txt",
        line: 10,
        limit: 100
      }

      json = Codec.encode!(request)
      assert json =~ ~s("sessionId":"session-123")
      assert json =~ ~s("path":"/path/to/file.txt")
      assert json =~ ~s("line":10)
      assert json =~ ~s("limit":100)

      {:ok, decoded} = Codec.decode(json, FsReadTextFileRequest)
      assert decoded.session_id == "session-123"
      assert decoded.path == "/path/to/file.txt"
      assert decoded.line == 10
      assert decoded.limit == 100
    end

    test "validates line and limit are positive" do
      changeset =
        FsReadTextFileRequest.changeset(%{
          "sessionId" => "s1",
          "path" => "/file.txt",
          "line" => -1,
          "limit" => 0
        })

      refute changeset.valid?

      assert %{line: ["must be greater than 0"], limit: ["must be greater than 0"]} =
               errors_on(changeset)
    end
  end

  describe "FsReadTextFileResponse" do
    test "encodes and decodes correctly" do
      response = %FsReadTextFileResponse{
        content: "File contents here"
      }

      json = Codec.encode!(response)
      {:ok, decoded} = Codec.decode(json, FsReadTextFileResponse)

      assert decoded.content == "File contents here"
    end
  end

  describe "Codec encode_to_map!" do
    test "returns map instead of JSON string" do
      request = %InitializeRequest{
        protocol_version: 1,
        client_capabilities: %{}
      }

      map = Codec.encode_to_map!(request)

      assert is_map(map)
      assert map["protocolVersion"] == 1
      assert map["clientCapabilities"] == %{}
    end
  end

  describe "Codec decode_from_map!" do
    test "decodes from map instead of JSON string" do
      map = %{
        "protocolVersion" => 1,
        "clientCapabilities" => %{"sessions" => %{"new" => true}}
      }

      request = Codec.decode_from_map!(map, InitializeRequest)

      assert request.protocol_version == 1
      assert request.client_capabilities == %{"sessions" => %{"new" => true}}
    end
  end

  # Helper function to convert changeset errors to a map
  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
