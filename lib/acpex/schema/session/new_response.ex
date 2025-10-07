defmodule ACPex.Schema.Session.NewResponse do
  @moduledoc """
  Response with the created session ID.

  Sent by the agent in response to a NewSessionRequest, providing the
  unique identifier for the newly created session.

  ## Required Fields

    * `session_id` - Unique session identifier (string)

  ## Optional Fields

    * `models` - Available models for the session (map)
    * `modes` - Available modes for the session (map)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Session.NewResponse{
        session_id: "session-123"
      }

  ## JSON Representation

      {
        "sessionId": "session-123"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:session_id, :string, source: :sessionId)
    field(:models, :map)
    field(:modes, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
          models: map() | nil,
          modes: map() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_id` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:session_id, :models, :modes, :meta])
    |> validate_required([:session_id])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
