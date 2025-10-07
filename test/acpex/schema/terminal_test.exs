defmodule ACPex.Schema.TerminalTest do
  @moduledoc """
  Tests for terminal-related schemas.
  """
  use ExUnit.Case, async: true

  alias ACPex.Schema.Codec

  alias ACPex.Schema.Client.Terminal.{
    CreateRequest,
    CreateResponse,
    OutputRequest,
    OutputResponse,
    WaitForExitRequest,
    WaitForExitResponse,
    KillRequest,
    KillResponse,
    ReleaseRequest,
    ReleaseResponse
  }

  alias ACPex.Schema.Types.{EnvVariable, TerminalExitStatus}

  describe "CreateRequest" do
    test "encodes with camelCase keys" do
      request = %CreateRequest{
        session_id: "session-123",
        command: "/bin/bash",
        args: ["-c", "echo hello"],
        cwd: "/project",
        env: [%{"name" => "PATH", "value" => "/usr/bin"}],
        output_byte_limit: 1024
      }

      json = Codec.encode!(request)

      assert json =~ ~s("sessionId":"session-123")
      assert json =~ ~s("command":"/bin/bash")
      assert json =~ ~s("args":["-c","echo hello"])
      assert json =~ ~s("cwd":"/project")
      assert json =~ ~s("outputByteLimit":1024)
      refute json =~ "session_id"
      refute json =~ "output_byte_limit"
    end

    test "decodes from camelCase JSON" do
      json = ~s({"sessionId":"s1","command":"/bin/sh","args":["test"],"outputByteLimit":512})

      {:ok, request} = Codec.decode(json, CreateRequest)

      assert request.session_id == "s1"
      assert request.command == "/bin/sh"
      assert request.args == ["test"]
      assert request.output_byte_limit == 512
    end

    test "validates required fields" do
      changeset = CreateRequest.changeset(%{})
      refute changeset.valid?
      assert %{session_id: ["can't be blank"], command: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "CreateResponse" do
    test "encodes terminalId field" do
      response = %CreateResponse{terminal_id: "term-123"}

      json = Codec.encode!(response)

      assert json =~ ~s("terminalId":"term-123")
      refute json =~ "terminal_id"
    end

    test "decodes terminalId field" do
      json = ~s({"terminalId":"term-456"})

      {:ok, response} = Codec.decode(json, CreateResponse)

      assert response.terminal_id == "term-456"
    end
  end

  describe "OutputRequest" do
    test "encodes with both IDs in camelCase" do
      request = %OutputRequest{
        session_id: "session-123",
        terminal_id: "term-456"
      }

      json = Codec.encode!(request)

      assert json =~ ~s("sessionId":"session-123")
      assert json =~ ~s("terminalId":"term-456")
    end

    test "round-trip encode/decode" do
      original = %OutputRequest{
        session_id: "s1",
        terminal_id: "t1"
      }

      json = Codec.encode!(original)
      {:ok, decoded} = Codec.decode(json, OutputRequest)

      assert decoded.session_id == original.session_id
      assert decoded.terminal_id == original.terminal_id
    end
  end

  describe "OutputResponse" do
    test "encodes with exitStatus field" do
      response = %OutputResponse{
        output: "Hello\n",
        truncated: false,
        exit_status: %{"exitCode" => 0, "signal" => nil}
      }

      json = Codec.encode!(response)

      assert json =~ ~s("output":"Hello\\n")
      assert json =~ ~s("truncated":false)
      assert json =~ ~s("exitStatus")
      assert json =~ ~s("exitCode":0)
    end

    test "validates required fields" do
      changeset = OutputResponse.changeset(%{})
      refute changeset.valid?
      assert %{output: ["can't be blank"], truncated: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "WaitForExitRequest" do
    test "encodes correctly" do
      request = %WaitForExitRequest{
        session_id: "session-123",
        terminal_id: "term-123"
      }

      json = Codec.encode!(request)

      assert json =~ ~s("sessionId":"session-123")
      assert json =~ ~s("terminalId":"term-123")
    end
  end

  describe "WaitForExitResponse" do
    test "encodes exit_code in camelCase" do
      response = %WaitForExitResponse{
        exit_code: 0,
        signal: nil
      }

      json = Codec.encode!(response)

      assert json =~ ~s("exitCode":0)
      refute json =~ "exit_code"
    end

    test "validates exit_code is non-negative" do
      changeset = WaitForExitResponse.changeset(%{exit_code: -1})
      refute changeset.valid?
      assert %{exit_code: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end
  end

  describe "KillRequest" do
    test "encodes both IDs" do
      request = %KillRequest{
        session_id: "session-123",
        terminal_id: "term-123"
      }

      json = Codec.encode!(request)

      assert json =~ ~s("sessionId")
      assert json =~ ~s("terminalId")
    end
  end

  describe "KillResponse" do
    test "encodes as empty object when no metadata" do
      response = %KillResponse{}

      json = Codec.encode!(response)

      assert json == "{}"
    end
  end

  describe "ReleaseRequest" do
    test "round-trip encode/decode" do
      original = %ReleaseRequest{
        session_id: "s1",
        terminal_id: "t1"
      }

      json = Codec.encode!(original)
      {:ok, decoded} = Codec.decode(json, ReleaseRequest)

      assert decoded.session_id == original.session_id
      assert decoded.terminal_id == original.terminal_id
    end
  end

  describe "ReleaseResponse" do
    test "encodes as empty object" do
      response = %ReleaseResponse{}

      json = Codec.encode!(response)

      assert json == "{}"
    end
  end

  describe "EnvVariable" do
    test "encodes and decodes correctly" do
      env_var = %EnvVariable{
        name: "PATH",
        value: "/usr/bin:/bin"
      }

      json = Codec.encode!(env_var)
      {:ok, decoded} = Codec.decode(json, EnvVariable)

      assert decoded.name == env_var.name
      assert decoded.value == env_var.value
    end

    test "validates required fields" do
      changeset = EnvVariable.changeset(%{})
      refute changeset.valid?
      assert %{name: ["can't be blank"], value: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "TerminalExitStatus" do
    test "encodes exitCode in camelCase" do
      status = %TerminalExitStatus{
        exit_code: 0,
        signal: nil
      }

      json = Codec.encode!(status)

      assert json =~ ~s("exitCode":0)
      refute json =~ "exit_code"
    end

    test "allows null values" do
      status = %TerminalExitStatus{
        exit_code: nil,
        signal: "SIGTERM"
      }

      json = Codec.encode!(status)

      assert json =~ ~s("signal":"SIGTERM")
      refute json =~ "exitCode"
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
