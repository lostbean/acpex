defmodule ACPex.Schema.Client.Terminal.CreateResponse do
  @moduledoc """
  Response containing the created terminal ID.

  Sent by the client in response to a CreateTerminalRequest, containing
  the unique identifier for the newly created terminal.

  ## Required Fields

    * `terminal_id` - Unique terminal identifier (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.Terminal.CreateResponse{
        terminal_id: "term-abc123"
      }

  ## JSON Representation

      {
        "terminalId": "term-abc123"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:terminal_id, :string, source: :terminalId)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          terminal_id: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `terminal_id` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:terminal_id, :meta])
    |> validate_required([:terminal_id])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
