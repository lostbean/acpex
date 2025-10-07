defmodule ACPex.Schema.Session.CancelNotification do
  @moduledoc """
  Notification to cancel prompt processing.

  Sent by the client to request cancellation of an ongoing prompt. The agent
  should stop processing and send a PromptResponse with stop_reason "cancelled".

  ## Required Fields

    * `session_id` - The session identifier (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Session.CancelNotification{
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
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
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
    |> cast(params, [:session_id, :meta])
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
