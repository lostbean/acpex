defmodule ACPex.Schema.Client.Terminal.CreateRequest do
  @moduledoc """
  Request from agent to create a terminal.

  Sent by the agent to request the client to create a new terminal process
  for executing commands. This is a bidirectional request (agent → client).

  ## Required Fields

    * `session_id` - The session identifier (string)
    * `command` - The command to execute (string)

  ## Optional Fields

    * `args` - Command-line arguments (list of strings)
    * `cwd` - Working directory (string)
    * `env` - Environment variables (list of maps)
    * `output_byte_limit` - Maximum output bytes (integer)
    * `meta` - Additional metadata (map)

  ## Example

      %ACPex.Schema.Client.Terminal.CreateRequest{
        session_id: "session-123",
        command: "/bin/bash",
        args: ["-c", "echo hello"],
        cwd: "/project",
        env: [%{"name" => "PATH", "value" => "/usr/bin"}]
      }

  ## JSON Representation

      {
        "sessionId": "session-123",
        "command": "/bin/bash",
        "args": ["-c", "echo hello"],
        "cwd": "/project",
        "env": [{"name": "PATH", "value": "/usr/bin"}]
      }

  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:session_id, :string, source: :sessionId)
    field(:command, :string)
    field(:args, {:array, :string})
    field(:cwd, :string)
    field(:env, {:array, :map})
    field(:output_byte_limit, :integer, source: :outputByteLimit)
    field(:meta, :map, source: :_meta)
  end

  @type t :: %__MODULE__{
          session_id: String.t(),
          command: String.t(),
          args: [String.t()] | nil,
          cwd: String.t() | nil,
          env: [map()] | nil,
          output_byte_limit: integer() | nil,
          meta: map() | nil
        }

  @doc """
  Creates a changeset for validation.

  ## Required Fields

    * `session_id` - Must be present
    * `command` - Must be present

  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:session_id, :command, :args, :cwd, :env, :output_byte_limit, :meta])
    |> validate_required([:session_id, :command])
    |> validate_number(:output_byte_limit, greater_than: 0)
  end

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> ACPex.Schema.Codec.encode_to_map!()
      |> Jason.Encode.map(opts)
    end
  end
end
