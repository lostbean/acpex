defmodule ACPex.Schema.Client.FsWriteTextFileRequest do
  @moduledoc """
  Request from agent to write a text file.

  Sent by the agent to request the client to write content to a file on
  the local filesystem. This is a bidirectional request (agent → client).

  ## Required Fields

    * `session_id` - The session identifier (string)
    * `path` - The file path to write (string)
    * `content` - The content to write (string)

  ## Optional Fields

    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.FsWriteTextFileRequest{
        session_id: "session-123",
        path: "/path/to/file.txt",
        content: "New file contents"
      }

  ## JSON Representation

      {
        "sessionId": "session-123",
        "path": "/path/to/file.txt",
        "content": "New file contents"
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:session_id, :string, source: :sessionId)
    field(:path, :string)
    field(:content, :string)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
          path: String.t(),
          content: String.t(),
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_id` - Must be present
    * `path` - Must be present
    * `content` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:session_id, :path, :content, :meta])
    |> validate_required([:session_id, :path, :content])
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
