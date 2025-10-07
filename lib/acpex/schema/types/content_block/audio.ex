defmodule ACPex.Schema.Types.ContentBlock.Audio do
  @moduledoc """
  Audio content block.

  Represents audio data in a prompt or message.

  ## Required Fields

    * `type` - Always "audio" for this variant
    * `data` - Base64-encoded audio data
    * `mime_type` - MIME type of the audio (e.g., "audio/wav")

  ## Optional Fields

    * `annotations` - Additional annotations (map)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.ContentBlock.Audio{
        type: "audio",
        data: "UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAAABkYXRhAAAAAA==",
        mime_type: "audio/wav"
      }

  ## JSON Representation

      {
        "type": "audio",
        "data": "UklGRiQAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAAABkYXRhAAAAAA==",
        "mimeType": "audio/wav"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "audio")
    field(:data, :string)
    field(:mime_type, :string, source: :mimeType)
    field(:annotations, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          data: String.t(),
          mime_type: String.t(),
          annotations: map() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `data` - Must be present
    * `mime_type` - Must be present

  The `type` field defaults to "audio".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :data, :mime_type, :annotations, :meta])
    |> validate_required([:data, :mime_type])
    |> validate_inclusion(:type, ["audio"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
