defmodule ACPex.Agent do
  @moduledoc """
  Behaviour for implementing an ACP agent (AI coding assistant).

  An agent is responsible for:
  - Handling initialization and authentication
  - Managing conversation sessions
  - Processing user prompts and generating responses
  - Making requests to the client for file and terminal operations

  ## Type-Safe API

  All callbacks use strongly-typed structs from the `ACPex.Schema.*` modules,
  providing compile-time validation and better documentation.

  ## Example

      defmodule MyAgent do
        @behaviour ACPex.Agent

        def init(_args), do: {:ok, %{}}

        def handle_initialize(request, state) do
          response = %ACPex.Schema.Connection.InitializeResponse{
            protocol_version: 1,
            agent_capabilities: %{sessions: %{new: true}}
          }
          {:ok, response, state}
        end

        def handle_new_session(request, state) do
          response = %ACPex.Schema.Session.NewResponse{}
          {:ok, response, state}
        end

        # ... other callbacks
      end
  """

  alias ACPex.Schema.Connection.{InitializeRequest, InitializeResponse}
  alias ACPex.Schema.Connection.{AuthenticateRequest, AuthenticateResponse}
  alias ACPex.Schema.Session.{NewRequest, NewResponse}
  alias ACPex.Schema.Session.{PromptRequest, PromptResponse}
  alias ACPex.Schema.Session.CancelNotification

  @type state :: term()
  @type error_response :: %{code: integer(), message: String.t()}

  @doc """
  Initialize the agent with the given arguments.

  Returns `{:ok, initial_state}`.
  """
  @callback init(args :: term()) :: {:ok, state()}

  @doc """
  Handle the initialization handshake from the client.

  This is where capabilities are negotiated.

  ## Parameters

    * `request` - An `InitializeRequest` struct with protocol version and client capabilities
    * `state` - Current agent state

  ## Returns

    * `{:ok, response, new_state}` where response is an `InitializeResponse` struct
  """
  @callback handle_initialize(InitializeRequest.t(), state()) ::
              {:ok, InitializeResponse.t(), state()}

  @doc """
  Handle authentication request from the client.

  ## Parameters

    * `request` - An `AuthenticateRequest` struct
    * `state` - Current agent state

  ## Returns

    * `{:ok, response, new_state}` where response is an `AuthenticateResponse` struct
    * `{:error, error_map, new_state}` for authentication failures
  """
  @callback handle_authenticate(AuthenticateRequest.t(), state()) ::
              {:ok, AuthenticateResponse.t(), state()} | {:error, error_response(), state()}

  @doc """
  Handle creation of a new session (conversation).

  ## Parameters

    * `request` - A `NewRequest` struct
    * `state` - Current agent state

  ## Returns

    * `{:ok, response, new_state}` where response is a `NewResponse` struct
  """
  @callback handle_new_session(NewRequest.t(), state()) ::
              {:ok, NewResponse.t(), state()}

  @doc """
  Handle loading of an existing session.

  ## Parameters

    * `request` - A session load request struct
    * `state` - Current agent state

  ## Returns

    * `{:ok, response, new_state}` on successful load
    * `{:error, error_map, new_state}` if session not found
  """
  @callback handle_load_session(map(), state()) ::
              {:ok, map(), state()} | {:error, error_response(), state()}

  @doc """
  Handle a user prompt within a session.

  The agent should process the prompt and send updates via
  `ACPex.Protocol.Connection.send_notification/3`.

  ## Parameters

    * `request` - A `PromptRequest` struct with session_id and prompt content
    * `state` - Current agent state

  ## Returns

    * `{:ok, response, new_state}` where response is a `PromptResponse` struct
  """
  @callback handle_prompt(PromptRequest.t(), state()) ::
              {:ok, PromptResponse.t(), state()}

  @doc """
  Handle a cancellation request for an ongoing prompt.

  ## Parameters

    * `notification` - A `CancelNotification` struct
    * `state` - Current agent state

  ## Returns

    * `{:noreply, new_state}` - No response is sent for cancellations
  """
  @callback handle_cancel(CancelNotification.t(), state()) ::
              {:noreply, state()}
end
