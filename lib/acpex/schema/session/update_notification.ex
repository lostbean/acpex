defmodule ACPex.Schema.Session.UpdateNotification do
  @moduledoc """
  Streaming update notification from the agent.

  Sent by the agent during prompt processing to provide real-time updates
  about its progress. These are notifications (no response expected).

  ## Required Fields

    * `session_id` - The session identifier (string)
    * `update` - The update content (map)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Update Types

  The `update` map can contain various types of information:
    * `message` - A message chunk from the agent
    * `thought` - Agent's reasoning or explanation
    * `toolCall` - Information about a tool being called
    * `plan` - A step-by-step plan for the task

  ## Example

      %ACPex.Schema.Session.UpdateNotification{
        session_id: "session-123",
        update: %{
          "type" => "thought",
          "content" => "Analyzing the code structure..."
        }
      }

  ## JSON Representation

      {
        "sessionId": "session-123",
        "update": {
          "type": "thought",
          "content": "Analyzing the code structure..."
        }
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:session_id, :string, source: :sessionId)
    field(:update, :map)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
          update: map(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_id` - Must be present
    * `update` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:session_id, :update, :meta])
    |> validate_required([:session_id, :update])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
