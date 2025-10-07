defmodule ACPex.Schema.Client.Terminal.OutputResponse do
  @moduledoc """
  Response containing terminal output.

  Sent by the client in response to a TerminalOutputRequest, containing
  the terminal's output and optionally its exit status.

  ## Required Fields

    * `output` - The terminal output (string)
    * `truncated` - Whether the output was truncated (boolean)

  ## Optional Fields

    * `exit_status` - Terminal exit status (map with exitCode and signal)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.Terminal.OutputResponse{
        output: "Hello, world!\\n",
        truncated: false,
        exit_status: %{"exitCode" => 0, "signal" => nil}
      }

  ## JSON Representation

      {
        "output": "Hello, world!\\n",
        "truncated": false,
        "exitStatus": {"exitCode": 0, "signal": null}
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:output, :string)
    field(:exit_status, :map, source: :exitStatus)
    field(:truncated, :boolean)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          output: String.t(),
          exit_status: map() | nil,
          truncated: boolean(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `output` - Must be present
    * `truncated` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:output, :exit_status, :truncated, :meta])
    |> validate_required([:output, :truncated])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
