defmodule ACPex.Schema.Types.SessionUpdate.AvailableCommandsUpdate do
  @moduledoc """
  Available commands update.

  Notification of changes to the set of available commands in the session.

  ## Required Fields

    * `type` - Always "available_commands_update" for this variant
    * `session_update` - Update identifier
    * `available_commands` - List of available commands (list of maps)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Available Command Structure

  Each entry in the `available_commands` list typically contains:
  - `id` - Unique identifier for the command
  - `name` - Command name
  - `description` - Description of what the command does
  - Other fields specific to the command

  ## Example

      %ACPex.Schema.Types.SessionUpdate.AvailableCommandsUpdate{
        type: "available_commands_update",
        session_update: "update-999",
        available_commands: [
          %{
            "id" => "cmd-1",
            "name" => "analyze",
            "description" => "Analyze the code"
          },
          %{
            "id" => "cmd-2",
            "name" => "refactor",
            "description" => "Refactor the code"
          }
        ]
      }

  ## JSON Representation

      {
        "type": "available_commands_update",
        "sessionUpdate": "update-999",
        "availableCommands": [
          {
            "id": "cmd-1",
            "name": "analyze",
            "description": "Analyze the code"
          },
          {
            "id": "cmd-2",
            "name": "refactor",
            "description": "Refactor the code"
          }
        ]
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:type, :string, default: "available_commands_update")
    field(:session_update, :string, source: :sessionUpdate)
    field(:available_commands, {:array, :map}, source: :availableCommands)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          type: String.t(),
          session_update: String.t(),
          available_commands: [map()],
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_update` - Must be present
    * `available_commands` - Must be present

  The `type` field defaults to "available_commands_update".
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:type, :session_update, :available_commands, :meta])
    |> validate_required([:session_update, :available_commands])
    |> validate_inclusion(:type, ["available_commands_update"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
