defmodule ACPex.Client do
  @moduledoc """
  Behaviour for implementing an ACP client (typically a code editor).

  A client is responsible for:
  - Managing the connection to an agent
  - Handling session updates from the agent
  - Responding to agent requests for file system and terminal operations
  """

  @type state :: term()
  @type params :: map()
  @type response :: map()
  @type error_response :: %{code: integer(), message: String.t()}

  @doc """
  Initialize the client with the given arguments.

  Returns `{:ok, initial_state}`.
  """
  @callback init(args :: term()) :: {:ok, state()}

  @doc """
  Handle a session update notification from the agent.

  These are streaming updates during prompt processing.
  """
  @callback handle_session_update(params(), state()) ::
              {:noreply, state()}

  @doc """
  Handle a request from the agent to read a text file.

  Should return the file contents or an error.
  """
  @callback handle_fs_read_text_file(params(), state()) ::
              {:ok, response(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to write a text file.
  """
  @callback handle_fs_write_text_file(params(), state()) ::
              {:ok, response(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to create a terminal.
  """
  @callback handle_terminal_create(params(), state()) ::
              {:ok, response(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to get terminal output.
  """
  @callback handle_terminal_output(params(), state()) ::
              {:ok, response(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to wait for terminal exit.
  """
  @callback handle_terminal_wait_for_exit(params(), state()) ::
              {:ok, response(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to kill a terminal command.
  """
  @callback handle_terminal_kill(params(), state()) ::
              {:ok, response(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a request from the agent to release a terminal.
  """
  @callback handle_terminal_release(params(), state()) ::
              {:ok, response(), state()} | {:error, error_response(), state()}
end
