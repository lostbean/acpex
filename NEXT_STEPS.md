# Next Steps for ACPex Development

Based on the recent architectural refactoring to align with `docs/design.md`, the
following tasks are recommended to create a complete and robust implementation.

## 1. Implement Full Protocol Logic

The foundational OTP structure is in place, but the logic to route all protocol
messages to the user's behaviour callbacks is incomplete.

- **Action:**
  - [x] In `ACPex.Protocol.Connection`, implement the dispatching logic for
    connection-level requests (e.g., `initialize`, `authenticate`) to the
    handler module.
  - [ ] In `ACPex.Protocol.Session`, implement the full routing logic to dispatch all
    session-level messages (`session/prompt`, `session/cancel`, `fs/read_text_file`,
    etc.) to the correct callbacks on the handler module.
  - [x] Implement proper JSON-RPC error responses for protocol violations, such as
    requests for an unknown `session_id` or calls to an unsupported method.

## 2. Implement Client-Side Agent Spawning

The library does not yet support the client role correctly, as it cannot spawn an
agent subprocess.

- **Action:**
  - [x] Modify the transport layer or connection process to handle the `:client` role.
  - [x] When `start_client` is called, the library must spawn the agent executable as
    an external OS process.
  - [x] The Erlang `Port` must be connected to the `stdin` and `stdout` of the newly
    spawned agent process, not the client's own stdio.

## 3. Create a New Test Suite

The original test suite was removed during the refactoring and must be replaced to
ensure the new architecture is correct and robust.

- **Action:**
  - [x] Create new test files for the refactored OTP architecture (e.g.,
    `test/acpex/protocol/connection_test.exs`).
  - [ ] Create `test/acpex/protocol/session_test.exs`.
  - [ ] Write integration tests that verify the complete message flow through the
    `Transport` -> `Connection` -> `Session` process hierarchy.
  - [ ] Ensure tests cover the full lifecycle: starting a connection, creating a
    session, sending requests and notifications, and graceful termination.

## 4. Update Documentation

The new modules created during the refactoring are missing documentation.

- **Action:**
  - [ ] Write comprehensive `@moduledoc` documentation for all new modules:
    `ACPex.Application`, `ACPex.Json`, and all modules under `ACPex.Protocol`.
  - [ ] Add `@doc` and `@spec` definitions for all public functions.
  - [ ] Update the `:groups_for_modules` list in `mix.exs` to correctly categorize the
    new modules for the generated HexDocs site.

## 5. Implement Symmetric JSON Deserialization

The library can encode Elixir structs to `camelCase` JSON, but it does not yet
handle the reverse when decoding.

- **Action:**
  - [ ] Implement logic to deserialize incoming JSON with `camelCase` keys directly
    into the `ACPex.Schema` structs with `snake_case` atom keys.
  - [ ] This will provide a fully seamless, struct-based experience for developers
    and improve type safety.
