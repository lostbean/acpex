defmodule ACPex.Schema.TypesTest do
  @moduledoc """
  Tests for basic schema types (AuthMethod, Capabilities, etc.).
  """
  use ExUnit.Case, async: true

  alias ACPex.Schema.Codec

  alias ACPex.Schema.Types.{
    AuthMethod,
    AgentCapabilities,
    ClientCapabilities,
    PromptCapabilities,
    McpCapabilities,
    FileSystemCapability
  }

  describe "AuthMethod" do
    test "encodes with camelCase keys" do
      auth_method = %AuthMethod{
        id: "oauth2",
        name: "OAuth 2.0",
        description: "Authenticate with OAuth"
      }

      json = Codec.encode!(auth_method)

      assert json =~ ~s("id":"oauth2")
      assert json =~ ~s("name":"OAuth 2.0")
      assert json =~ ~s("description":"Authenticate with OAuth")
    end

    test "decodes from JSON" do
      json = ~s({"id":"bearer","name":"Bearer Token","description":"Use bearer token"})

      {:ok, auth_method} = Codec.decode(json, AuthMethod)

      assert auth_method.id == "bearer"
      assert auth_method.name == "Bearer Token"
      assert auth_method.description == "Use bearer token"
    end

    test "validates required fields" do
      changeset = AuthMethod.changeset(%{})
      refute changeset.valid?
      assert %{id: [_], name: [_]} = errors_on(changeset)
    end
  end

  describe "PromptCapabilities" do
    test "encodes embeddedContext in camelCase" do
      caps = %PromptCapabilities{
        image: true,
        audio: false,
        embedded_context: true
      }

      json = Codec.encode!(caps)

      assert json =~ ~s("image":true)
      assert json =~ ~s("audio":false)
      assert json =~ ~s("embeddedContext":true)
      refute json =~ "embedded_context"
    end

    test "decodes from camelCase JSON" do
      json = ~s({"image":true,"audio":true,"embeddedContext":false})

      {:ok, caps} = Codec.decode(json, PromptCapabilities)

      assert caps.image == true
      assert caps.audio == true
      assert caps.embedded_context == false
    end

    test "has default values" do
      caps = %PromptCapabilities{}

      assert caps.image == false
      assert caps.audio == false
      assert caps.embedded_context == false
    end
  end

  describe "McpCapabilities" do
    test "encodes correctly" do
      caps = %McpCapabilities{http: true, sse: false}

      json = Codec.encode!(caps)

      assert json =~ ~s("http":true)
      assert json =~ ~s("sse":false)
    end

    test "has default values" do
      caps = %McpCapabilities{}

      assert caps.http == false
      assert caps.sse == false
    end
  end

  describe "FileSystemCapability" do
    test "encodes with camelCase keys" do
      caps = %FileSystemCapability{
        read_text_file: true,
        write_text_file: true
      }

      json = Codec.encode!(caps)

      assert json =~ ~s("readTextFile":true)
      assert json =~ ~s("writeTextFile":true)
      refute json =~ "read_text_file"
    end

    test "decodes from camelCase JSON" do
      json = ~s({"readTextFile":true,"writeTextFile":false})

      {:ok, caps} = Codec.decode(json, FileSystemCapability)

      assert caps.read_text_file == true
      assert caps.write_text_file == false
    end
  end

  describe "ClientCapabilities" do
    test "encodes nested fs capability" do
      caps = %ClientCapabilities{
        fs: %{"readTextFile" => true, "writeTextFile" => true},
        terminal: true
      }

      json = Codec.encode!(caps)

      assert json =~ ~s("fs":)
      assert json =~ ~s("readTextFile":true)
      assert json =~ ~s("terminal":true)
    end

    test "decodes from JSON" do
      json = ~s({"fs":{"readTextFile":true},"terminal":false})

      {:ok, caps} = Codec.decode(json, ClientCapabilities)

      assert caps.fs["readTextFile"] == true
      assert caps.terminal == false
    end
  end

  describe "AgentCapabilities" do
    test "encodes with nested capabilities" do
      caps = %AgentCapabilities{
        load_session: true,
        mcp_capabilities: %{"http" => true, "sse" => false},
        prompt_capabilities: %{"image" => true, "audio" => false, "embeddedContext" => true}
      }

      json = Codec.encode!(caps)

      assert json =~ ~s("loadSession":true)
      assert json =~ ~s("mcpCapabilities":)
      assert json =~ ~s("promptCapabilities":)
      assert json =~ ~s("http":true)
      assert json =~ ~s("image":true)
      refute json =~ "load_session"
    end

    test "decodes from camelCase JSON" do
      json = ~s({
        "loadSession": false,
        "mcpCapabilities": {"http": true, "sse": false},
        "promptCapabilities": {"image": true, "audio": false, "embeddedContext": true}
      })

      {:ok, caps} = Codec.decode(json, AgentCapabilities)

      assert caps.load_session == false
      assert caps.mcp_capabilities["http"] == true
      assert caps.prompt_capabilities["image"] == true
      assert caps.prompt_capabilities["embeddedContext"] == true
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
