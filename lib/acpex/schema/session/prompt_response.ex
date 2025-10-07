defmodule ACPex.Schema.Session.PromptResponse do
  @moduledoc """
  Response to a prompt request.

  Sent by the agent when it has finished processing a prompt. This is the
  final message in the prompt turn, after all streaming updates.

  ## Required Fields

    * `stop_reason` - Why the prompt processing stopped (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Stop Reasons

    * `"done"` - Processing completed successfully
    * `"cancelled"` - Processing was cancelled by the client
    * `"error"` - An error occurred during processing

  ## Example

      %ACPex.Schema.Session.PromptResponse{
        stop_reason: "done"
      }

  ## JSON Representation

      {
        "stopReason": "done"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:stop_reason, :string, source: :stopReason)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          stop_reason: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `stop_reason` - Must be present and be one of: "done", "cancelled", "error"

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:stop_reason, :meta])
    |> validate_required([:stop_reason])
    |> validate_inclusion(:stop_reason, ["done", "cancelled", "error"])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
