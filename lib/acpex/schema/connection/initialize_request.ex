defmodule ACPex.Schema.Connection.InitializeRequest do
  @moduledoc """
  Request sent by the client to initialize the ACP connection.

  This is the first message sent by the client after spawning the agent process.
  It establishes the protocol version and exchanges capability information.

  ## Required Fields

    * `protocol_version` - The protocol version (integer, currently 1)

  ## Optional Fields

    * `client_capabilities` - Client capability information (map)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Connection.InitializeRequest{
        protocol_version: 1,
        client_capabilities: %{
          "sessions" => %{"new" => true}
        }
      }

  ## JSON Representation

  The struct is encoded with camelCase keys for protocol compliance:

      {
        "protocolVersion": 1,
        "clientCapabilities": {
          "sessions": {"new": true}
        }
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:protocol_version, :integer, source: :protocolVersion)
    field(:client_capabilities, :map, source: :clientCapabilities)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          protocol_version: integer(),
          client_capabilities: map() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `protocol_version` - Must be present and must be an integer

  ## Examples

      iex> changeset(%InitializeRequest{}, %{"protocolVersion" => 1})
      #Ecto.Changeset<valid?: true, ...>

      iex> changeset(%InitializeRequest{}, %{})
      #Ecto.Changeset<valid?: false, errors: [protocol_version: {"can't be blank", [validation: :required]}]>

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:protocol_version, :client_capabilities, :meta])
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
