defmodule ACPex.Schema.SessionUpdateTest do
  @moduledoc """
  Tests for SessionUpdate union type and its variants.
  """
  use ExUnit.Case, async: true

  alias ACPex.Schema.Codec
  alias ACPex.Schema.Types.SessionUpdate

  alias ACPex.Schema.Types.SessionUpdate.{
    UserMessageChunk,
    AgentMessageChunk,
    AgentThoughtChunk,
    ToolCall,
    ToolCallUpdate,
    Plan,
    AvailableCommandsUpdate,
    CurrentModeUpdate
  }

  describe "UserMessageChunk" do
    test "encodes with sessionUpdate in camelCase" do
      chunk = %UserMessageChunk{
        session_update: "update-123",
        content: %{"type" => "text", "text" => "Hello"}
      }

      json = Codec.encode!(chunk)

      assert json =~ ~s("type":"user_message_chunk")
      assert json =~ ~s("sessionUpdate":"update-123")
      assert json =~ ~s("content":)
      refute json =~ "session_update"
    end

    test "validates required fields" do
      changeset = UserMessageChunk.changeset(%{})
      refute changeset.valid?
      assert %{session_update: [_], content: [_]} = errors_on(changeset)
    end
  end

  describe "AgentMessageChunk" do
    test "encodes correctly" do
      chunk = %AgentMessageChunk{
        session_update: "update-456",
        content: %{"type" => "text", "text" => "Response"}
      }

      json = Codec.encode!(chunk)

      assert json =~ ~s("type":"agent_message_chunk")
      assert json =~ ~s("sessionUpdate":"update-456")
    end
  end

  describe "AgentThoughtChunk" do
    test "encodes correctly" do
      chunk = %AgentThoughtChunk{
        session_update: "update-789",
        content: %{"type" => "text", "text" => "Thinking..."}
      }

      json = Codec.encode!(chunk)

      assert json =~ ~s("type":"agent_thought_chunk")
      assert json =~ ~s("sessionUpdate":"update-789")
    end
  end

  describe "ToolCall" do
    test "encodes with toolCallId in camelCase" do
      tool_call = %ToolCall{
        session_update: "update-1",
        tool_call_id: "tool-123",
        title: "Read File",
        status: "running",
        kind: "fs_read",
        content: [%{"type" => "text", "text" => "Reading..."}],
        raw_input: %{"path" => "/file.txt"},
        locations: [%{"file" => "/file.txt", "line" => 10}]
      }

      json = Codec.encode!(tool_call)

      assert json =~ ~s("type":"tool_call")
      assert json =~ ~s("sessionUpdate":"update-1")
      assert json =~ ~s("toolCallId":"tool-123")
      assert json =~ ~s("title":"Read File")
      assert json =~ ~s("status":"running")
      assert json =~ ~s("kind":"fs_read")
      assert json =~ ~s("rawInput":)
      refute json =~ "tool_call_id"
      refute json =~ "raw_input"
    end

    test "validates required fields" do
      changeset = ToolCall.changeset(%{})
      refute changeset.valid?
      assert %{session_update: [_], tool_call_id: [_], title: [_]} = errors_on(changeset)
    end
  end

  describe "ToolCallUpdate" do
    test "encodes correctly" do
      update = %ToolCallUpdate{
        session_update: "update-2",
        tool_call_id: "tool-456",
        status: "completed",
        content: [%{"type" => "text", "text" => "Done"}]
      }

      json = Codec.encode!(update)

      assert json =~ ~s("type":"tool_call_update")
      assert json =~ ~s("toolCallId":"tool-456")
      assert json =~ ~s("status":"completed")
    end

    test "validates required fields (only session_update and tool_call_id)" do
      changeset = ToolCallUpdate.changeset(%{session_update: "u1", tool_call_id: "t1"})
      assert changeset.valid?

      changeset = ToolCallUpdate.changeset(%{})
      refute changeset.valid?
      assert %{session_update: [_], tool_call_id: [_]} = errors_on(changeset)
    end
  end

  describe "Plan" do
    test "encodes with entries array" do
      plan = %Plan{
        session_update: "update-3",
        entries: [
          %{"id" => "step-1", "description" => "First step", "status" => "completed"},
          %{"id" => "step-2", "description" => "Second step", "status" => "in_progress"}
        ]
      }

      json = Codec.encode!(plan)

      assert json =~ ~s("type":"plan")
      assert json =~ ~s("sessionUpdate":"update-3")
      assert json =~ ~s("entries":)
      assert json =~ ~s("step-1")
      assert json =~ ~s("First step")
    end

    test "validates required fields" do
      changeset = Plan.changeset(%{})
      refute changeset.valid?
      assert %{session_update: [_], entries: [_]} = errors_on(changeset)
    end
  end

  describe "AvailableCommandsUpdate" do
    test "encodes with availableCommands in camelCase" do
      update = %AvailableCommandsUpdate{
        session_update: "update-4",
        available_commands: [
          %{"id" => "cmd-1", "name" => "analyze", "description" => "Analyze code"},
          %{"id" => "cmd-2", "name" => "refactor", "description" => "Refactor code"}
        ]
      }

      json = Codec.encode!(update)

      assert json =~ ~s("type":"available_commands_update")
      assert json =~ ~s("availableCommands":)
      assert json =~ ~s("analyze")
      # Check that the field name is in camelCase, not snake_case
      refute json =~ ~s("available_commands":)
    end

    test "validates required fields" do
      changeset = AvailableCommandsUpdate.changeset(%{})
      refute changeset.valid?
      assert %{session_update: [_], available_commands: [_]} = errors_on(changeset)
    end
  end

  describe "CurrentModeUpdate" do
    test "encodes with currentModeId in camelCase" do
      update = %CurrentModeUpdate{
        session_update: "update-5",
        current_mode_id: "debug_mode"
      }

      json = Codec.encode!(update)

      assert json =~ ~s("type":"current_mode_update")
      assert json =~ ~s("currentModeId":"debug_mode")
      refute json =~ "current_mode_id"
    end

    test "validates required fields" do
      changeset = CurrentModeUpdate.changeset(%{})
      refute changeset.valid?
      assert %{session_update: [_], current_mode_id: [_]} = errors_on(changeset)
    end
  end

  describe "SessionUpdate union decoder" do
    test "decodes user_message_chunk variant" do
      json =
        ~s({"type":"user_message_chunk","sessionUpdate":"u1","content":{"type":"text","text":"Hi"}})

      {:ok, update} = SessionUpdate.decode(json)

      assert %UserMessageChunk{session_update: "u1"} = update
    end

    test "decodes agent_message_chunk variant" do
      json =
        ~s({"type":"agent_message_chunk","sessionUpdate":"u2","content":{"type":"text","text":"Hello"}})

      {:ok, update} = SessionUpdate.decode(json)

      assert %AgentMessageChunk{session_update: "u2"} = update
    end

    test "decodes agent_thought_chunk variant" do
      json =
        ~s({"type":"agent_thought_chunk","sessionUpdate":"u3","content":{"type":"text","text":"Thinking"}})

      {:ok, update} = SessionUpdate.decode(json)

      assert %AgentThoughtChunk{session_update: "u3"} = update
    end

    test "decodes tool_call variant" do
      json = ~s({"type":"tool_call","sessionUpdate":"u4","toolCallId":"t1","title":"Test"})

      {:ok, update} = SessionUpdate.decode(json)

      assert %ToolCall{tool_call_id: "t1", title: "Test"} = update
    end

    test "decodes tool_call_update variant" do
      json = ~s({"type":"tool_call_update","sessionUpdate":"u5","toolCallId":"t2"})

      {:ok, update} = SessionUpdate.decode(json)

      assert %ToolCallUpdate{tool_call_id: "t2"} = update
    end

    test "decodes plan variant" do
      json = ~s({"type":"plan","sessionUpdate":"u6","entries":[{"id":"s1"}]})

      {:ok, update} = SessionUpdate.decode(json)

      assert %Plan{entries: [%{"id" => "s1"}]} = update
    end

    test "decodes available_commands_update variant" do
      json = ~s({"type":"available_commands_update","sessionUpdate":"u7","availableCommands":[]})

      {:ok, update} = SessionUpdate.decode(json)

      assert %AvailableCommandsUpdate{available_commands: []} = update
    end

    test "decodes current_mode_update variant" do
      json = ~s({"type":"current_mode_update","sessionUpdate":"u8","currentModeId":"mode1"})

      {:ok, update} = SessionUpdate.decode(json)

      assert %CurrentModeUpdate{current_mode_id: "mode1"} = update
    end

    test "returns error for unknown type" do
      {:error, msg} = SessionUpdate.decode(%{"type" => "unknown"})
      assert msg =~ "Unknown session update type"
    end

    test "returns error for missing type" do
      {:error, msg} = SessionUpdate.decode(%{"sessionUpdate" => "u1"})
      assert msg =~ "Missing type field"
    end

    test "decode! raises on error" do
      assert_raise ArgumentError, fn ->
        SessionUpdate.decode!(%{"type" => "unknown"})
      end
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
