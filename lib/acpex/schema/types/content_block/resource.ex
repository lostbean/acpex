defmodule ACPex.Schema.Types.ContentBlock.Resource do
  @moduledoc """
  Embedded resource content block.

  Represents embedded resource contents in a prompt or message. The resource
  can be either text or binary data.

  ## Required Fields

    * `type` - Always "resource" for this variant
    * `resource` - Embedded resource contents (map with text or blob data)

  ## Optional Fields

    * `annotations` - Additional annotations (map)
    * `meta` - Additional metadata (map)

  ## Resource Structure

  The `resource` field should contain either:

  ### Text Resource
      %{
        "uri" => "file:///path/to/file.txt",
        "text" => "file contents...",
        "mimeType" => "text/plain"
      }

  ### Blob Resource
      %{
        "uri" => "file:///path/to/file.bin",
        "blob" => "base64-encoded-data...",
        "mimeType" => "application/octet-stream"
      }

  ## Example

      %ACPex.Schema.Types.ContentBlock.Resource{
        type: "resource",
        resource: %{
          "uri" => "file:///home/user/config.json",
          "text" => "{\\"setting\\": \\"value\\"}",
          "mimeType" => "application/json"
        }
      }

  ## JSON Representation

      {
        "type": "resource",
        "resource": {
          "uri": "file:///home/user/config.json",
          "text": "{\\"setting\\": \\"value\\"}",
          "mimeType": "application/json"
        }
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "resource")
    # Note: resource is a union type (TextResourceContents | BlobResourceContents)
    # Keeping as :map for flexibility
    field(:resource, :map)
    field(:annotations, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          resource: map(),
          annotations: map() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `resource` - Must be present and contain either text or blob data

  The `type` field defaults to "resource".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :resource, :annotations, :meta])
    |> validate_required([:resource])
    |> validate_inclusion(:type, ["resource"])
    |> validate_resource_contents()
  end

  defp validate_resource_contents(changeset) do
    case get_field(changeset, :resource) do
      %{"uri" => _, "text" => _} -> changeset
      %{"uri" => _, "blob" => _} -> changeset
      %{uri: _, text: _} -> changeset
      %{uri: _, blob: _} -> changeset
      nil -> changeset
      _ -> add_error(changeset, :resource, "must contain uri and either text or blob")
    end
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
