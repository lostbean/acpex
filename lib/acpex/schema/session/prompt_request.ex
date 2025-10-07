defmodule ACPex.Schema.Session.PromptRequest do
  @moduledoc """
  User prompt sent to the agent.

  Represents a user's message or query to the agent within an active session.

  ## Required Fields

    * `session_id` - The session identifier (string)
    * `prompt` - The prompt content blocks (list of maps)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Session.PromptRequest{
        session_id: "session-123",
        prompt: [
          %{"type" => "text", "text" => "Refactor this function"}
        ]
      }

  ## JSON Representation

      {
        "sessionId": "session-123",
        "prompt": [
          {"type": "text", "text": "Refactor this function"}
        ]
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:session_id, :string, source: :sessionId)
    field(:prompt, {:array, :map})
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
          prompt: [map()],
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_id` - Must be present
    * `prompt` - Must be present and non-empty

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:session_id, :prompt, :meta])
    |> validate_required([:session_id, :prompt])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
