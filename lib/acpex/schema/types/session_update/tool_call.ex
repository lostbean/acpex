defmodule ACPex.Schema.Types.SessionUpdate.ToolCall do
  @moduledoc """
  Tool call update.

  Notification of a new tool call being initiated.

  ## Required Fields

    * `type` - Always "tool_call" for this variant
    * `session_update` - Update identifier
    * `tool_call_id` - Unique identifier for this tool call
    * `title` - Human-readable title for the tool call

  ## Optional Fields

    * `status` - Current status of the tool call (string)
    * `kind` - Kind of tool (string)
    * `content` - Tool call content blocks (list of maps)
    * `raw_input` - Raw input parameters (map)
    * `raw_output` - Raw output data (map)
    * `locations` - File locations related to this tool call (list of maps)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.SessionUpdate.ToolCall{
        type: "tool_call",
        session_update: "update-123",
        tool_call_id: "tool-456",
        title: "Read File",
        status: "running",
        kind: "fs_read",
        content: [%{"type" => "text", "text" => "Reading file..."}]
      }

  ## JSON Representation

      {
        "type": "tool_call",
        "sessionUpdate": "update-123",
        "toolCallId": "tool-456",
        "title": "Read File",
        "status": "running",
        "kind": "fs_read",
        "content": [{"type": "text", "text": "Reading file..."}]
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "tool_call")
    field(:session_update, :string, source: :sessionUpdate)
    field(:tool_call_id, :string, source: :toolCallId)
    field(:title, :string)
    field(:status, :string)
    field(:kind, :string)
    field(:content, {:array, :map})
    field(:raw_input, :map, source: :rawInput)
    field(:raw_output, :map, source: :rawOutput)
    field(:locations, {:array, :map})
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          session_update: String.t(),
          tool_call_id: String.t(),
          title: String.t(),
          status: String.t() | nil,
          kind: String.t() | nil,
          content: [map()] | nil,
          raw_input: map() | nil,
          raw_output: map() | nil,
          locations: [map()] | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_update` - Must be present
    * `tool_call_id` - Must be present
    * `title` - Must be present

  The `type` field defaults to "tool_call".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :type,
      :session_update,
      :tool_call_id,
      :title,
      :status,
      :kind,
      :content,
      :raw_input,
      :raw_output,
      :locations,
      :meta
    ])
    |> validate_required([:session_update, :tool_call_id, :title])
    |> validate_inclusion(:type, ["tool_call"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
