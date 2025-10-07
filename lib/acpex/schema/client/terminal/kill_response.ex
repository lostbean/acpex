defmodule ACPex.Schema.Client.Terminal.KillResponse do
  @moduledoc """
  Confirmation of terminal kill.

  Sent by the client in response to a KillTerminalRequest to confirm
  that the terminal process was successfully killed.

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.Terminal.KillResponse{}

  ## JSON Representation

      {}

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  No required fields.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:meta])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
