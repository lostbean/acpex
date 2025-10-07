defmodule ACPex.Schema.Types.SessionUpdate do
  @moduledoc """
  Session update union type.

  A SessionUpdate can be one of several variants, discriminated by the `type` field:

  - `"user_message_chunk"` - Streaming user message content
  - `"agent_message_chunk"` - Streaming agent response content
  - `"agent_thought_chunk"` - Streaming agent reasoning content
  - `"tool_call"` - Notification of a new tool call
  - `"tool_call_update"` - Status update for an existing tool call
  - `"plan"` - Agent's execution plan for complex tasks
  - `"available_commands_update"` - Changes in available commands
  - `"current_mode_update"` - Session mode changes

  ## Usage

  You can use any of the variant structs directly:

      # User message chunk
      %ACPex.Schema.Types.SessionUpdate.UserMessageChunk{
        session_update: "update-123",
        content: %{"type" => "text", "text" => "Hello"}
      }

      # Tool call
      %ACPex.Schema.Types.SessionUpdate.ToolCall{
        session_update: "update-456",
        tool_call_id: "tool-789",
        title: "Read File",
        status: "running"
      }

  Or use maps (which will be validated at runtime):

      %{
        "type" => "user_message_chunk",
        "sessionUpdate" => "update-123",
        "content" => %{"type" => "text", "text" => "Hello"}
      }

  ## Decoding from JSON

  Use the `decode/1` function to decode JSON into the appropriate variant struct:

      json = ~s({"type":"user_message_chunk","sessionUpdate":"u1","content":{"type":"text","text":"Hi"}})
      {:ok, %ACPex.Schema.Types.SessionUpdate.UserMessageChunk{}} = SessionUpdate.decode(json)

  ## Encoding to JSON

  All variant structs implement Jason.Encoder:

      update = %ACPex.Schema.Types.SessionUpdate.UserMessageChunk{
        session_update: "u1",
        content: %{"type" => "text", "text" => "Hi"}
      }
      Jason.encode!(update)

  """

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

  @type variant ::
          UserMessageChunk.t()
          | AgentMessageChunk.t()
          | AgentThoughtChunk.t()
          | ToolCall.t()
          | ToolCallUpdate.t()
          | Plan.t()
          | AvailableCommandsUpdate.t()
          | CurrentModeUpdate.t()

  @type t :: variant()

  @doc """
  Decodes a JSON string or map into the appropriate SessionUpdate variant struct.

  The `type` field is used as a discriminator to determine which variant to decode to.

  ## Examples

      iex> SessionUpdate.decode(~s({"type":"user_message_chunk","sessionUpdate":"u1","content":{"type":"text","text":"Hi"}}))
      {:ok, %SessionUpdate.UserMessageChunk{session_update: "u1", content: %{"type" => "text", "text" => "Hi"}}}

      iex> SessionUpdate.decode(%{"type" => "tool_call", "sessionUpdate" => "u2", "toolCallId" => "t1", "title" => "Read"})
      {:ok, %SessionUpdate.ToolCall{session_update: "u2", tool_call_id: "t1", title: "Read"}}

      iex> SessionUpdate.decode(%{"type" => "unknown"})
      {:error, "Unknown session update type: unknown"}

  """
  @spec decode(String.t() | map()) :: {:ok, variant()} | {:error, String.t()}
  def decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} -> decode(map)
      {:error, reason} -> {:error, "Invalid JSON: #{inspect(reason)}"}
    end
  end

  def decode(%{"type" => "user_message_chunk"} = map), do: decode_variant(map, UserMessageChunk)
  def decode(%{"type" => "agent_message_chunk"} = map), do: decode_variant(map, AgentMessageChunk)
  def decode(%{"type" => "agent_thought_chunk"} = map), do: decode_variant(map, AgentThoughtChunk)
  def decode(%{"type" => "tool_call"} = map), do: decode_variant(map, ToolCall)
  def decode(%{"type" => "tool_call_update"} = map), do: decode_variant(map, ToolCallUpdate)
  def decode(%{"type" => "plan"} = map), do: decode_variant(map, Plan)

  def decode(%{"type" => "available_commands_update"} = map),
    do: decode_variant(map, AvailableCommandsUpdate)

  def decode(%{"type" => "current_mode_update"} = map), do: decode_variant(map, CurrentModeUpdate)
  def decode(%{type: type} = map) when is_binary(type), do: decode(stringify_keys(map))
  def decode(%{"type" => type}), do: {:error, "Unknown session update type: #{type}"}
  def decode(_), do: {:error, "Missing type field"}

  @doc """
  Same as `decode/1` but raises on error.
  """
  @spec decode!(String.t() | map()) :: variant()
  def decode!(json) do
    case decode(json) do
      {:ok, struct} -> struct
      {:error, reason} -> raise ArgumentError, "SessionUpdate decode error: #{reason}"
    end
  end

  # Private helpers

  defp decode_variant(map, module) do
    case ACPex.Schema.Codec.decode_from_map(map, module) do
      {:ok, struct} -> {:ok, struct}
      {:error, reason} -> {:error, inspect(reason)}
    end
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
  end
end
