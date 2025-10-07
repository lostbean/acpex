defmodule ACPex.Schema.Types.PromptCapabilities do
  @moduledoc """
  Prompt capabilities supported by the agent.

  Describes which types of content the agent can handle in prompts.

  ## Optional Fields (all default to false)

    * `audio` - Whether the agent supports audio content
    * `embedded_context` - Whether the agent supports embedded context
    * `image` - Whether the agent supports image content
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.PromptCapabilities{
        image: true,
        audio: false,
        embedded_context: true
      }

  ## JSON Representation

      {
        "image": true,
        "audio": false,
        "embeddedContext": true
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:audio, :boolean, default: false)
    field(:embedded_context, :boolean, default: false, source: :embeddedContext)
    field(:image, :boolean, default: false)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          audio: boolean(),
          embedded_context: boolean(),
          image: boolean(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  All fields are optional with defaults.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:audio, :embedded_context, :image, :meta])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
