defmodule ACPex.Schema.Types.SessionUpdate.Plan do
  @moduledoc """
  Plan update.

  Agent's execution plan for complex tasks, broken down into entries.

  ## Required Fields

    * `type` - Always "plan" for this variant
    * `session_update` - Update identifier
    * `entries` - List of plan entries (list of maps)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Plan Entry Structure

  Each entry in the `entries` list typically contains:
  - `id` - Unique identifier for the plan entry
  - `description` - Description of the task
  - `status` - Current status (pending, in_progress, completed, failed)
  - Other fields specific to the plan entry type

  ## Example

      %ACPex.Schema.Types.SessionUpdate.Plan{
        type: "plan",
        session_update: "update-789",
        entries: [
          %{
            "id" => "step-1",
            "description" => "Read configuration file",
            "status" => "completed"
          },
          %{
            "id" => "step-2",
            "description" => "Parse configuration",
            "status" => "in_progress"
          }
        ]
      }

  ## JSON Representation

      {
        "type": "plan",
        "sessionUpdate": "update-789",
        "entries": [
          {
            "id": "step-1",
            "description": "Read configuration file",
            "status": "completed"
          },
          {
            "id": "step-2",
            "description": "Parse configuration",
            "status": "in_progress"
          }
        ]
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "plan")
    field(:session_update, :string, source: :sessionUpdate)
    field(:entries, {:array, :map})
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          session_update: String.t(),
          entries: [map()],
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_update` - Must be present
    * `entries` - Must be present

  The `type` field defaults to "plan".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :session_update, :entries, :meta])
    |> validate_required([:session_update, :entries])
    |> validate_inclusion(:type, ["plan"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
