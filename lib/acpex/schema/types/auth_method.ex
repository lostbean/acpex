defmodule ACPex.Schema.Types.AuthMethod do
  @moduledoc """
  Authentication method information.

  Describes an available authentication method that can be used
  during the connection authentication phase.

  ## Required Fields

    * `id` - Unique identifier for the authentication method
    * `name` - Human-readable name for the authentication method

  ## Optional Fields

    * `description` - Detailed description of the authentication method
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.AuthMethod{
        id: "oauth2",
        name: "OAuth 2.0",
        description: "Authenticate using OAuth 2.0 flow"
      }

  ## JSON Representation

      {
        "id": "oauth2",
        "name": "OAuth 2.0",
        "description": "Authenticate using OAuth 2.0 flow"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    field(:description, :string)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `id` - Must be present
    * `name` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:id, :name, :description, :meta])
    |> validate_required([:id, :name])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
