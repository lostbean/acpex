defmodule ACPex.Schema.Types.SessionUpdate.CurrentModeUpdate do
  @moduledoc """
  Current mode update.

  Notification of a change to the session's current mode.

  ## Required Fields

    * `type` - Always "current_mode_update" for this variant
    * `session_update` - Update identifier
    * `current_mode_id` - New current mode identifier

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.SessionUpdate.CurrentModeUpdate{
        type: "current_mode_update",
        session_update: "update-888",
        current_mode_id: "debug_mode"
      }

  ## JSON Representation

      {
        "type": "current_mode_update",
        "sessionUpdate": "update-888",
        "currentModeId": "debug_mode"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "current_mode_update")
    field(:session_update, :string, source: :sessionUpdate)
    field(:current_mode_id, :string, source: :currentModeId)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          session_update: String.t(),
          current_mode_id: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_update` - Must be present
    * `current_mode_id` - Must be present

  The `type` field defaults to "current_mode_update".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :session_update, :current_mode_id, :meta])
    |> validate_required([:session_update, :current_mode_id])
    |> validate_inclusion(:type, ["current_mode_update"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
