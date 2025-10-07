defmodule ACPex.Schema.Client.FsReadTextFileRequest do
  @moduledoc """
  Request from agent to read a text file.

  Sent by the agent to request the client to read a file from the local
  filesystem. This is a bidirectional request (agent → client).

  ## Required Fields

    * `session_id` - The session identifier (string)
    * `path` - The file path to read (string)

  ## Optional Fields

    * `line` - Starting line number (integer)
    * `limit` - Maximum number of lines to read (integer)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.FsReadTextFileRequest{
        session_id: "session-123",
        path: "/path/to/file.txt"
      }

  ## JSON Representation

      {
        "sessionId": "session-123",
        "path": "/path/to/file.txt"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:session_id, :string, source: :sessionId)
    field(:path, :string)
    field(:line, :integer)
    field(:limit, :integer)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
          path: String.t(),
          line: integer() | nil,
          limit: integer() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_id` - Must be present
    * `path` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:session_id, :path, :line, :limit, :meta])
    |> validate_required([:session_id, :path])
    |> validate_number(:line, greater_than: 0)
    |> validate_number(:limit, greater_than: 0)
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
