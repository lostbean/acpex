defmodule ACPex.Schema.Types.AgentCapabilities do
  @moduledoc """
  Agent capabilities for ACP protocol.

  Describes the capabilities supported by the agent.

  ## Optional Fields

    * `load_session` - Whether the agent supports loading saved sessions (default: false)
    * `mcp_capabilities` - MCP protocol capabilities (McpCapabilities struct or map)
    * `prompt_capabilities` - Prompt content capabilities (PromptCapabilities struct or map)
    * `meta` - Additional metadata (map)

  ## Example with structs

      %ACPex.Schema.Types.AgentCapabilities{
        load_session: true,
        mcp_capabilities: %ACPex.Schema.Types.McpCapabilities{
          http: true,
          sse: false
        },
        prompt_capabilities: %ACPex.Schema.Types.PromptCapabilities{
          image: true,
          audio: false,
          embedded_context: true
        }
      }

  ## Example with maps (also supported)

      %ACPex.Schema.Types.AgentCapabilities{
        load_session: true,
        mcp_capabilities: %{http: true, sse: false},
        prompt_capabilities: %{image: true, audio: false, embedded_context: true}
      }

  ## JSON Representation

      {
        "loadSession": true,
        "mcpCapabilities": {
          "http": true,
          "sse": false
        },
        "promptCapabilities": {
          "image": true,
          "audio": false,
          "embeddedContext": true
        }
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:load_session, :boolean, default: false, source: :loadSession)
    # Note: Using :map for nested capabilities to support both struct and map input
    # Can be cast to McpCapabilities/PromptCapabilities structs if needed
    field(:mcp_capabilities, :map, source: :mcpCapabilities)
    field(:prompt_capabilities, :map, source: :promptCapabilities)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          load_session: boolean(),
          mcp_capabilities: map() | ACPex.Schema.Types.McpCapabilities.t() | nil,
          prompt_capabilities: map() | ACPex.Schema.Types.PromptCapabilities.t() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  All fields are optional with defaults.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:load_session, :mcp_capabilities, :prompt_capabilities, :meta])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
