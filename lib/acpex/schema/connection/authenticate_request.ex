defmodule ACPex.Schema.Connection.AuthenticateRequest do
  @moduledoc """
  Request to authenticate with the agent.

  Sent by the client if the agent requires authentication (as indicated by
  `auth_methods` in the InitializeResponse).

  ## Required Fields

    * `method_id` - The ID of the authentication method to use (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Connection.AuthenticateRequest{
        method_id: "api_key"
      }

  ## JSON Representation

      {
        "methodId": "api_key"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:method_id, :string, source: :methodId)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          method_id: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `method_id` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:method_id, :meta])
    |> validate_required([:method_id])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
