defmodule ACPex.Agent do
  @moduledoc """
  Behaviour for implementing an ACP agent (AI coding assistant).

  An agent is responsible for:
  - Handling initialization and authentication
  - Managing conversation sessions
  - Processing user prompts and generating responses
  - Making requests to the client for file and terminal operations
  """

  @type state :: term()
  @type params :: map()
  @type response :: map()

  @doc """
  Initialize the agent with the given arguments.

  Returns `{:ok, initial_state}`.
  """
  @callback init(args :: term()) :: {:ok, state()}

  @doc """
  Handle the initialization handshake from the client.

  This is where capabilities are negotiated.
  """
  @callback handle_initialize(params(), state()) ::
              {:ok, response(), state()}

  @doc """
  Handle authentication request from the client.
  """
  @callback handle_authenticate(params(), state()) ::
              {:ok, response(), state()} | {:error, map(), state()}

  @doc """
  Handle creation of a new session (conversation).
  """
  @callback handle_new_session(params(), state()) ::
              {:ok, response(), state()}

  @doc """
  Handle loading of an existing session.
  """
  @callback handle_load_session(params(), state()) ::
              {:ok, response(), state()} | {:error, map(), state()}

  @doc """
  Handle a user prompt within a session.

  The agent should process the prompt and send updates via
  `ACPex.Connection.send_notification/3`.
  """
  @callback handle_prompt(params(), state()) ::
              {:ok, response(), state()}

  @doc """
  Handle a cancellation request for an ongoing prompt.
  """
  @callback handle_cancel(params(), state()) ::
              {:noreply, state()}
end
