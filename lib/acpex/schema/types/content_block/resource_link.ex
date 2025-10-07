defmodule ACPex.Schema.Types.ContentBlock.ResourceLink do
  @moduledoc """
  Resource link content block.

  Represents a reference to an external resource in a prompt or message.

  ## Required Fields

    * `type` - Always "resource_link" for this variant
    * `uri` - URI of the resource
    * `name` - Name of the resource

  ## Optional Fields

    * `description` - Description of the resource
    * `mime_type` - MIME type of the resource
    * `size` - Size of the resource in bytes
    * `title` - Title of the resource
    * `annotations` - Additional annotations (map)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.ContentBlock.ResourceLink{
        type: "resource_link",
        uri: "file:///home/user/document.pdf",
        name: "document.pdf",
        title: "Important Document",
        description: "A PDF containing important information",
        mime_type: "application/pdf",
        size: 1024000
      }

  ## JSON Representation

      {
        "type": "resource_link",
        "uri": "file:///home/user/document.pdf",
        "name": "document.pdf",
        "title": "Important Document",
        "description": "A PDF containing important information",
        "mimeType": "application/pdf",
        "size": 1024000
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "resource_link")
    field(:uri, :string)
    field(:name, :string)
    field(:description, :string)
    field(:mime_type, :string, source: :mimeType)
    field(:size, :integer)
    field(:title, :string)
    field(:annotations, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          uri: String.t(),
          name: String.t(),
          description: String.t() | nil,
          mime_type: String.t() | nil,
          size: integer() | nil,
          title: String.t() | nil,
          annotations: map() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `uri` - Must be present
    * `name` - Must be present

  The `type` field defaults to "resource_link".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [
      :type,
      :uri,
      :name,
      :description,
      :mime_type,
      :size,
      :title,
      :annotations,
      :meta
    ])
    |> validate_required([:uri, :name])
    |> validate_inclusion(:type, ["resource_link"])
    |> validate_number(:size, greater_than_or_equal_to: 0)
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
