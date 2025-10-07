defmodule ACPex.Schema.Session.NewRequest do
  @moduledoc """
  Request to create a new conversation session.

  Sent by the client to start a new conversation with the agent.

  ## Required Fields

    * `cwd` - Current working directory (string)
    * `mcp_servers` - List of MCP server configurations (list of maps)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Session.NewRequest{
        cwd: "/path/to/project",
        mcp_servers: []
      }

  ## JSON Representation

      {
        "cwd": "/path/to/project",
        "mcpServers": []
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:cwd, :string)
    field(:mcp_servers, {:array, :map}, source: :mcpServers)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          cwd: String.t(),
          mcp_servers: [map()],
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `cwd` - Must be present
    * `mcp_servers` - Must be present (can be empty list)

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:cwd, :mcp_servers, :meta])
    |> validate_required([:cwd, :mcp_servers])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
