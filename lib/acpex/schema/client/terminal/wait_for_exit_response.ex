defmodule ACPex.Schema.Client.Terminal.WaitForExitResponse do
  @moduledoc """
  Response containing terminal exit information.

  Sent by the client in response to a WaitForTerminalExitRequest, containing
  the terminal's exit code and/or signal.

  ## Optional Fields

    * `exit_code` - The exit code (integer, 0 or greater)
    * `signal` - The signal that terminated the process (string)
    * `meta` - Additional metadata (map)

  Note: At least one of `exit_code` or `signal` should be present.

  ## Example

      %ACPex.Schema.Client.Terminal.WaitForExitResponse{
        exit_code: 0,
        signal: nil
      }

  ## JSON Representation

      {
        "exitCode": 0
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:exit_code, :integer, source: :exitCode)
    field(:signal, :string)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          exit_code: integer() | nil,
          signal: String.t() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Optional Fields

    * `exit_code` - If present, must be >= 0
    * `signal` - Optional signal string

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:exit_code, :signal, :meta])
    |> validate_number(:exit_code, greater_than_or_equal_to: 0)
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
