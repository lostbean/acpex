defmodule ACPex.Schema.Types.SessionUpdate.ToolCallUpdate do
  @moduledoc """
  Tool call update.

  Status update for an existing tool call.

  ## Required Fields

    * `type` - Always "tool_call_update" for this variant
    * `session_update` - Update identifier
    * `tool_call_id` - Unique identifier for the tool call being updated

  ## Optional Fields

    * `status` - Updated status of the tool call (string)
    * `title` - Updated title for the tool call (string)
    * `kind` - Updated kind of tool (string)
    * `content` - Updated tool call content blocks (list of maps)
    * `raw_input` - Updated raw input parameters (map)
    * `raw_output` - Updated raw output data (map)
    * `locations` - Updated file locations related to this tool call (list of maps)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.SessionUpdate.ToolCallUpdate{
        type: "tool_call_update",
        session_update: "update-124",
        tool_call_id: "tool-456",
        status: "completed",
        content: [%{"type" => "text", "text" => "File read successfully"}]
      }

  ## JSON Representation

      {
        "type": "tool_call_update",
        "sessionUpdate": "update-124",
        "toolCallId": "tool-456",
        "status": "completed",
        "content": [{"type": "text", "text": "File read successfully"}]
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "tool_call_update")
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
          title: String.t() | nil,
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

  The `type` field defaults to "tool_call_update".
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
    |> validate_required([:session_update, :tool_call_id])
    |> validate_inclusion(:type, ["tool_call_update"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
