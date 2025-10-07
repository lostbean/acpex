defmodule ACPex.Schema.Connection.AuthenticateResponse do
  @moduledoc """
  Response to an authentication request.

  Sent by the agent to confirm successful authentication or report an error.

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Connection.AuthenticateResponse{}

  ## JSON Representation

      {}

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:authenticated, :boolean)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          authenticated: boolean() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  No required fields.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:authenticated, :meta])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
