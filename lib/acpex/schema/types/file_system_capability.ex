defmodule ACPex.Schema.Types.FileSystemCapability do
  @moduledoc """
  File system capabilities supported by the client.

  Describes which file system operations the client supports.

  ## Optional Fields (all default to false)

    * `read_text_file` - Whether the client supports reading text files
    * `write_text_file` - Whether the client supports writing text files
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.FileSystemCapability{
        read_text_file: true,
        write_text_file: true
      }

  ## JSON Representation

      {
        "readTextFile": true,
        "writeTextFile": true
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:read_text_file, :boolean, default: false, source: :readTextFile)
    field(:write_text_file, :boolean, default: false, source: :writeTextFile)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          read_text_file: boolean(),
          write_text_file: boolean(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  All fields are optional with defaults.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:read_text_file, :write_text_file, :meta])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
