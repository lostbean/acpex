defmodule ACPex.Schema.Types.ContentBlock.Image do
  @moduledoc """
  Image content block.

  Represents image data in a prompt or message.

  ## Required Fields

    * `type` - Always "image" for this variant
    * `data` - Base64-encoded image data
    * `mime_type` - MIME type of the image (e.g., "image/png")

  ## Optional Fields

    * `uri` - Optional URI for the image source
    * `annotations` - Additional annotations (map)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.ContentBlock.Image{
        type: "image",
        data: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
        mime_type: "image/png",
        uri: "file:///path/to/image.png"
      }

  ## JSON Representation

      {
        "type": "image",
        "data": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
        "mimeType": "image/png",
        "uri": "file:///path/to/image.png"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "image")
    field(:data, :string)
    field(:mime_type, :string, source: :mimeType)
    field(:uri, :string)
    field(:annotations, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          data: String.t(),
          mime_type: String.t(),
          uri: String.t() | nil,
          annotations: map() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `data` - Must be present
    * `mime_type` - Must be present

  The `type` field defaults to "image".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :data, :mime_type, :uri, :annotations, :meta])
    |> validate_required([:data, :mime_type])
    |> validate_inclusion(:type, ["image"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
