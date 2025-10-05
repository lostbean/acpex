# Next Steps for ACPex Development

Based on a review against the `docs/design.md` architectural document, the
following tasks are recommended to bring the implementation to full compliance
with the design and the Agent Client Protocol specification.

## 1. Complete the Protocol Schema and Behaviours

The current implementation only covers a subset of the ACP specification. The
remaining methods and data structures need to be added.

- **Action:**
  - In `lib/acpex/schema.ex`, add struct definitions for all missing
    request/response types, including:
    - `AuthenticateRequest` / `AuthenticateResponse`
    - `LoadSessionRequest` / `LoadSessionResponse`
    - `CancelNotification`
    - All `terminal/*` request and response types (`CreateTerminalRequest`,
      etc.).
    - Detailed `session/update` content blocks (`AgentMessageChunk`, `ToolCall`,
      `PlanUpdate`, etc.).
  - In `lib/acpex/agent.ex` and `lib/acpex/client.ex`, add the corresponding
    `@callback` definitions for the new methods (e.g., `handle_load_session`,
    `handle_terminal_create`).

## 2. Refine Behaviour Typespecs

The behaviour callbacks currently use a generic `map()` for parameters, which is
less precise than specified in the design. This weakens static analysis
capabilities.

- **Action:**
  - Update the `@callback` definitions in `lib/acpex/agent.ex` and
    `lib/acpex/client.ex` to use the specific struct types from `ACPex.Schema`.
  - For example, change:
    ```elixir
    @callback handle_initialize(params(), state()) :: {:ok, response(), state()}
    ```
    to:
    ```elixir
    @callback handle_initialize(params :: ACPex.Schema.InitializeRequest.t(), state :: term()) :: {:ok, ACPex.Schema.InitializeResponse.t(), new_state :: term()}
    ```
  - This will improve static analysis and provide better documentation and
    compile-time guarantees for developers.

## 3. Implement "Let It Crash" Error Handling

The current error handling for protocol parsing is more lenient than the robust
"let it crash" philosophy outlined in the design document.

- **Action:**
  - Define a custom exception, `defexception ACPex.ProtocolError`, as suggested
    in the design.
  - Modify the message parsing logic in `lib/acpex/connection.ex` to raise this
    exception when unrecoverable errors occur (e.g., invalid headers, malformed
    JSON).
  - This ensures the `Connection` GenServer crashes on protocol violations,
    allowing a supervisor to restart it in a clean state, leading to a more
    resilient system.

## 4. Add Property-Based Testing

The design calls for property-based tests to ensure the message parser is
robust, but these are currently missing.

- **Action:**
  - Add `stream_data` as a `:test` dependency in `mix.exs`.
  - Create a new test file (e.g., `test/acpex/parser_property_test.exs`).
  - Write property tests that generate a wide variety of valid and malformed
    message frames to feed into the parser, asserting that it correctly handles
    them or fails predictably.
