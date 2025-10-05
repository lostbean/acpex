defmodule ACPex.Schema do
  @moduledoc """
  Data structures for the Agent Client Protocol.

  These structs map to the types defined in the ACP JSON Schema.
  """

  defmodule InitializeRequest do
    @moduledoc "Request sent by client to initialize the connection"
    @enforce_keys [:protocol_version, :capabilities]
    defstruct [:protocol_version, :capabilities, :client_info]

    @type t :: %__MODULE__{
            protocol_version: String.t(),
            capabilities: map(),
            client_info: map() | nil
          }
  end

  defmodule InitializeResponse do
    @moduledoc "Response from agent with its capabilities"
    @enforce_keys [:protocol_version, :capabilities]
    defstruct [:protocol_version, :capabilities, :agent_info]

    @type t :: %__MODULE__{
            protocol_version: String.t(),
            capabilities: map(),
            agent_info: map() | nil
          }
  end

  defmodule NewSessionRequest do
    @moduledoc "Request to create a new conversation session"
    defstruct [:session_id]

    @type t :: %__MODULE__{
            session_id: String.t() | nil
          }
  end

  defmodule NewSessionResponse do
    @moduledoc "Response with the created session ID"
    @enforce_keys [:session_id]
    defstruct [:session_id]

    @type t :: %__MODULE__{
            session_id: String.t()
          }
  end

  defmodule PromptRequest do
    @moduledoc "User prompt sent to the agent"
    @enforce_keys [:session_id, :prompt]
    defstruct [:session_id, :prompt, :context]

    @type t :: %__MODULE__{
            session_id: String.t(),
            prompt: String.t(),
            context: map() | nil
          }
  end

  defmodule PromptResponse do
    @moduledoc "Acknowledgment that prompt processing has begun"
    defstruct []

    @type t :: %__MODULE__{}
  end

  defmodule SessionUpdate do
    @moduledoc "Streaming update notification from agent"
    @enforce_keys [:session_id, :update]
    defstruct [:session_id, :update]

    @type t :: %__MODULE__{
            session_id: String.t(),
            update: map()
          }
  end

  defmodule ReadTextFileRequest do
    @moduledoc "Agent request to read a file"
    @enforce_keys [:path]
    defstruct [:path]

    @type t :: %__MODULE__{
            path: String.t()
          }
  end

  defmodule ReadTextFileResponse do
    @moduledoc "File contents response"
    @enforce_keys [:content]
    defstruct [:content]

    @type t :: %__MODULE__{
            content: String.t()
          }
  end

  defmodule WriteTextFileRequest do
    @moduledoc "Agent request to write a file"
    @enforce_keys [:path, :content]
    defstruct [:path, :content]

    @type t :: %__MODULE__{
            path: String.t(),
            content: String.t()
          }
  end

  defmodule WriteTextFileResponse do
    @moduledoc "Confirmation of file write"
    defstruct []

    @type t :: %__MODULE__{}
  end
end
