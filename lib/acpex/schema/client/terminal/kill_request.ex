defmodule ACPex.Schema.Client.Terminal.KillRequest do
  @moduledoc """
  Request from agent to kill a terminal process.

  Sent by the agent to request the client to forcefully terminate a running
  terminal process. This is a bidirectional request (agent → client).

  ## Required Fields

    * `session_id` - The session identifier (string)
    * `terminal_id` - The terminal identifier (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.Terminal.KillRequest{
        session_id: "session-123",
        terminal_id: "term-abc123"
      }

  ## JSON Representation

      {
        "sessionId": "session-123",
        "terminalId": "term-abc123"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:session_id, :string, source: :sessionId)
    field(:terminal_id, :string, source: :terminalId)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
          terminal_id: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_id` - Must be present
    * `terminal_id` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:session_id, :terminal_id, :meta])
    |> validate_required([:session_id, :terminal_id])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
