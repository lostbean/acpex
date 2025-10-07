defmodule ACPex.Schema.Client.FsReadTextFileResponse do
  @moduledoc """
  Response containing file contents.

  Sent by the client in response to a FsReadTextFileRequest, containing
  the requested file content.

  ## Required Fields

    * `content` - The file content (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.FsReadTextFileResponse{
        content: "File contents here..."
      }

  ## JSON Representation

      {
        "content": "File contents here..."
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:content, :string)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          content: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `content` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:content, :meta])
    |> validate_required([:content])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
