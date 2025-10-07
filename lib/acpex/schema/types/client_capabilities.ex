defmodule ACPex.Schema.Types.ClientCapabilities do
  @moduledoc """
  Client capabilities for ACP protocol.

  Describes the capabilities supported by the client application.

  ## Optional Fields

    * `fs` - File system capabilities (FileSystemCapability struct or map)
    * `terminal` - Whether the client supports terminal operations (default: false)
    * `meta` - Additional metadata (map)

  ## Example with structs

      %ACPex.Schema.Types.ClientCapabilities{
        fs: %ACPex.Schema.Types.FileSystemCapability{
          read_text_file: true,
          write_text_file: true
        },
        terminal: true
      }

  ## Example with maps (also supported)

      %ACPex.Schema.Types.ClientCapabilities{
        fs: %{read_text_file: true, write_text_file: true},
        terminal: true
      }

  ## JSON Representation

      {
        "fs": {
          "readTextFile": true,
          "writeTextFile": true
        },
        "terminal": true
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    # Note: Using :map for fs to support both struct and map input
    # Can be cast to FileSystemCapability struct if needed
    field(:fs, :map)
    field(:terminal, :boolean, default: false)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          fs: map() | ACPex.Schema.Types.FileSystemCapability.t() | nil,
          terminal: boolean(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  All fields are optional with defaults.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:fs, :terminal, :meta])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
