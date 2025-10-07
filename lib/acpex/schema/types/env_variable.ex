defmodule ACPex.Schema.Types.EnvVariable do
  @moduledoc """
  Environment variable definition.

  Used in terminal creation requests to specify environment variables
  for the terminal process.

  ## Required Fields

    * `name` - Variable name (string)
    * `value` - Variable value (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.EnvVariable{
        name: "PATH",
        value: "/usr/local/bin:/usr/bin:/bin"
      }

  ## JSON Representation

      {
        "name": "PATH",
        "value": "/usr/local/bin:/usr/bin:/bin"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:name, :string)
    field(:value, :string)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          name: String.t(),
          value: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `name` - Must be present
    * `value` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :value, :meta])
    |> validate_required([:name, :value])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
