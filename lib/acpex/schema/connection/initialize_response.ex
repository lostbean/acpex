defmodule ACPex.Schema.Connection.InitializeResponse do
  @moduledoc """
  Response from the agent with its capabilities.

  Sent by the agent in response to an InitializeRequest. This message
  communicates what features the agent supports.

  ## Required Fields

    * `protocol_version` - The protocol version the agent supports (integer)

  ## Optional Fields

    * `agent_capabilities` - Agent capability information (map)
    * `auth_methods` - List of supported authentication methods (list of maps)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Connection.InitializeResponse{
        protocol_version: 1,
        agent_capabilities: %{
          "sessions" => %{"new" => true, "load" => false}
        },
        auth_methods: []
      }

  ## JSON Representation

  The struct is encoded with camelCase keys for protocol compliance:

      {
        "protocolVersion": 1,
        "agentCapabilities": {
          "sessions": {"new": true, "load": false}
        }
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:protocol_version, :integer, source: :protocolVersion)
    field(:agent_capabilities, :map, source: :agentCapabilities)
    field(:auth_methods, {:array, :map}, source: :authMethods)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          protocol_version: integer(),
          agent_capabilities: map() | nil,
          auth_methods: [map()] | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `protocol_version` - Must be present and must be an integer

  ## Examples

      iex> changeset(%InitializeResponse{}, %{"protocolVersion" => 1})
      #Ecto.Changeset<valid?: true, ...>

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:protocol_version, :agent_capabilities, :auth_methods, :meta])
    |> validate_required([:protocol_version])
    |> validate_number(:protocol_version, greater_than: 0)
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
