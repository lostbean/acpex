defmodule ACPex.Schema.Types.SessionUpdate.AgentMessageChunk do
  @moduledoc """
  Agent message chunk update.

  Represents a streaming chunk of agent response content.

  ## Required Fields

    * `type` - Always "agent_message_chunk" for this variant
    * `session_update` - Update identifier
    * `content` - Content block (ContentBlock struct or map)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.SessionUpdate.AgentMessageChunk{
        type: "agent_message_chunk",
        session_update: "update-456",
        content: %{"type" => "text", "text" => "Here's my response"}
      }

  ## JSON Representation

      {
        "type": "agent_message_chunk",
        "sessionUpdate": "update-456",
        "content": {
          "type": "text",
          "text": "Here's my response"
        }
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "agent_message_chunk")
    field(:session_update, :string, source: :sessionUpdate)
    # Note: content is a ContentBlock union type, kept as :map for flexibility
    field(:content, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          session_update: String.t(),
          content: map(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_update` - Must be present
    * `content` - Must be present

  The `type` field defaults to "agent_message_chunk".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :session_update, :content, :meta])
    |> validate_required([:session_update, :content])
    |> validate_inclusion(:type, ["agent_message_chunk"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
