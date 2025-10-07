defmodule ACPex.Schema.Types.McpCapabilities do
  @moduledoc """
  MCP (Model Context Protocol) capabilities supported by the agent.

  Describes which MCP transport protocols the agent supports.

  ## Optional Fields (all default to false)

    * `http` - Whether the agent supports HTTP-based MCP
    * `sse` - Whether the agent supports Server-Sent Events (SSE) based MCP
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Types.McpCapabilities{
        http: true,
        sse: false
      }

  ## JSON Representation

      {
        "http": true,
        "sse": false
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:http, :boolean, default: false)
    field(:sse, :boolean, default: false)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          http: boolean(),
          sse: boolean(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  All fields are optional with defaults.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:http, :sse, :meta])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
