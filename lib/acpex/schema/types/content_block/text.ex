defmodule ACPex.Schema.Types.ContentBlock.Text do
  @moduledoc """
  Text content block.

  Represents plain text content in a prompt or message.

  ## Required Fields

    * `type` - Always "text" for this variant
    * `text` - The text content

  ## Optional Fields

    * `annotations` - Additional annotations (map)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.ContentBlock.Text{
        type: "text",
        text: "Hello, world!"
      }

  ## JSON Representation

      {
        "type": "text",
        "text": "Hello, world!"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "text")
    field(:text, :string)
    field(:annotations, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          text: String.t(),
          annotations: map() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `text` - Must be present

  The `type` field defaults to "text".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :text, :annotations, :meta])
    |> validate_required([:text])
    |> validate_inclusion(:type, ["text"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
