defmodule ACPex.Client do
  @moduledoc """
  Behaviour for implementing an ACP client (typically a code editor).

  A client is responsible for:
  - Managing the connection to an agent
  - Handling session updates from the agent
  - Responding to agent requests for file system and terminal operations

  ## Type-Safe API

  All callbacks use strongly-typed structs from the `ACPex.Schema.*` modules,
  providing compile-time validation and better documentation.

  ## Example

      defmodule MyEditor do
        @behaviour ACPex.Client

        def init(_args), do: {:ok, %{files: %{}}}

        def handle_session_update(notification, state) do
          # Display update in UI
          {:noreply, state}
        end

        def handle_fs_read_text_file(request, state) do
          case File.read(request.path) do
            {:ok, content} ->
              response = %ACPex.Schema.Client.FsReadTextFileResponse{
                content: content
              }
              {:ok, response, state}

            {:error, _} ->
              {:error, %{code: -32001, message: "File not found"}, state}
          end
        end

        # ... other callbacks
      end
  """

  alias ACPex.Schema.Session.UpdateNotification
  alias ACPex.Schema.Client.{FsReadTextFileRequest, FsReadTextFileResponse}
  alias ACPex.Schema.Client.{FsWriteTextFileRequest, FsWriteTextFileResponse}
  alias ACPex.Schema.Client.Terminal.{CreateRequest, CreateResponse}
  alias ACPex.Schema.Client.Terminal.{OutputRequest, OutputResponse}
  alias ACPex.Schema.Client.Terminal.{WaitForExitRequest, WaitForExitResponse}
  alias ACPex.Schema.Client.Terminal.{KillRequest, KillResponse}
  alias ACPex.Schema.Client.Terminal.{ReleaseRequest, ReleaseResponse}

  @type state :: term()
  @type error_response :: %{code: integer(), message: String.t()}

  @doc """
  Initialize the client with the given arguments.

  Returns `{:ok, initial_state}`.
  """
  @callback init(args :: term()) :: {:ok, state()}

  @doc """
  Handle a session update notification from the agent.

  These are streaming updates during prompt processing (thoughts, message chunks, tool calls, etc).

  ## Parameters

    * `notification` - An `UpdateNotification` struct with session_id and update data
    * `state` - Current client state

  ## Returns

    * `{:noreply, new_state}` - Notifications don't send responses
  """
  @callback handle_session_update(UpdateNotification.t(), state()) ::
              {:noreply, state()}

  @doc """
  Handle a request from the agent to read a text file.

  ## Parameters

    * `request` - A `FsReadTextFileRequest` struct with the file path
    * `state` - Current client state

  ## Returns

    * `{:ok, response, new_state}` where response is a `FsReadTextFileResponse` struct
    * `{:error, error_map, new_state}` if file cannot be read
  """
  @callback handle_fs_read_text_file(FsReadTextFileRequest.t(), state()) ::
              {:ok, FsReadTextFileResponse.t(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to write a text file.

  ## Parameters

    * `request` - A `FsWriteTextFileRequest` struct with path and content
    * `state` - Current client state

  ## Returns

    * `{:ok, response, new_state}` where response is a `FsWriteTextFileResponse` struct
    * `{:error, error_map, new_state}` if file cannot be written
  """
  @callback handle_fs_write_text_file(FsWriteTextFileRequest.t(), state()) ::
              {:ok, FsWriteTextFileResponse.t(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to create a terminal.

  ## Parameters

    * `request` - A `CreateRequest` struct with terminal configuration
    * `state` - Current client state

  ## Returns

    * `{:ok, response, new_state}` where response is a `CreateResponse` struct with terminal_id
    * `{:error, error_map, new_state}` if terminal cannot be created
  """
  @callback handle_terminal_create(CreateRequest.t(), state()) ::
              {:ok, CreateResponse.t(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to get terminal output.

  ## Parameters

    * `request` - An `OutputRequest` struct with terminal_id
    * `state` - Current client state

  ## Returns

    * `{:ok, response, new_state}` where response is an `OutputResponse` struct with output data
    * `{:error, error_map, new_state}` if terminal not found
  """
  @callback handle_terminal_output(OutputRequest.t(), state()) ::
              {:ok, OutputResponse.t(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to wait for terminal exit.

  ## Parameters

    * `request` - A `WaitForExitRequest` struct with terminal_id
    * `state` - Current client state

  ## Returns

    * `{:ok, response, new_state}` where response is a `WaitForExitResponse` struct with exit status
    * `{:error, error_map, new_state}` if terminal not found
  """
  @callback handle_terminal_wait_for_exit(WaitForExitRequest.t(), state()) ::
              {:ok, WaitForExitResponse.t(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to kill a terminal command.

  ## Parameters

    * `request` - A `KillRequest` struct with terminal_id
    * `state` - Current client state

  ## Returns

    * `{:ok, response, new_state}` where response is a `KillResponse` struct
    * `{:error, error_map, new_state}` if terminal not found
  """
  @callback handle_terminal_kill(KillRequest.t(), state()) ::
              {:ok, KillResponse.t(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to release a terminal.

  ## Parameters

    * `request` - A `ReleaseRequest` struct with terminal_id
    * `state` - Current client state

  ## Returns

    * `{:ok, response, new_state}` where response is a `ReleaseResponse` struct
    * `{:error, error_map, new_state}` if terminal not found
  """
  @callback handle_terminal_release(ReleaseRequest.t(), state()) ::
              {:ok, ReleaseResponse.t(), state()} | {:error, error_response(), state()}
end
