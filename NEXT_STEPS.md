# Next Steps for ACPex Development

Based on the recent architectural refactoring to align with `docs/design.md`, the
following tasks are recommended to create a complete and robust implementation.

## 1. Implement Full Protocol Logic

The foundational OTP structure is in place, with complete routing logic for all
protocol messages.

- **Action:**
  - [x] In `ACPex.Protocol.Connection`, implement the dispatching logic for
    connection-level requests (e.g., `initialize`, `authenticate`) to the
    handler module.
  - [x] In `ACPex.Protocol.Session`, implement the full routing logic to dispatch all
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

A comprehensive test suite has been created to verify the new architecture.

- **Action:**
  - [x] Create new test files for the refactored OTP architecture (e.g.,
    `test/acpex/protocol/connection_test.exs`).
  - [x] Create `test/acpex/protocol/session_test.exs` with comprehensive coverage of
    all session-level methods (session/*, fs/*, terminal/*).
  - [x] Write integration tests that verify the complete message flow through the
    `Transport` -> `Connection` -> `Session` process hierarchy.
  - [x] Ensure tests cover the full lifecycle: starting a connection, creating a
    session, sending requests and notifications, and graceful termination.

## 4. Update Documentation

Comprehensive documentation has been added to all modules.

- **Action:**
  - [x] Write comprehensive `@moduledoc` documentation for all new modules:
    `ACPex.Application`, `ACPex.Json`, and all modules under `ACPex.Protocol`.
  - [x] Add `@doc` and `@spec` definitions for all public functions.
  - [x] Update the `:groups_for_modules` list in `mix.exs` to correctly categorize the
    new modules for the generated HexDocs site.

## 5. Implement Symmetric JSON Deserialization

The library now supports both encoding and decoding between Elixir structs and JSON.

- **Action:**
  - [x] Implement logic to deserialize incoming JSON with `camelCase` keys directly
    into the `ACPex.Schema` structs with `snake_case` atom keys.
  - [x] This provides a fully seamless, struct-based experience for developers
    and improves type safety.

## Summary

All core implementation tasks have been completed:

- ✅ Full protocol logic with dynamic routing
- ✅ Client-side agent spawning via Port
- ✅ Comprehensive test suite (25 tests, all passing)
- ✅ Complete documentation with @moduledoc, @doc, and @spec
- ✅ Symmetric JSON serialization (encode and decode)

The library is now feature-complete and ready for the next phase of development,
which may include:

- Creating example agents and clients
- Building MCP integration
- Adding alternative transport layers (WebSocket)
- Publishing to Hex.pm
