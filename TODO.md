# ACPex TODO

## Architecture Improvements

### 1. Generic Executable Handling (Remove Node.js Special-Casing)

**Status:** ✅ **Completed** **Context:** Successfully simplified executable
resolution to let the OS handle all executable types uniformly (binaries,
scripts with shebangs, symlinks).

**Completed Work:**

- ✅ Research Elixir/Erlang best practices for spawning external processes
  - ✅ Exile library chosen and integrated successfully
  - ✅ Provides backpressure, async I/O, and proper stream handling
- ✅ Simplified `resolve_executable/2` to handle all executables uniformly
  - OS now handles shebang scripts automatically with `:spawn_executable`
  - Removed Node.js-specific detection (`.js`/`.mjs` special-casing)
  - Removed manual shebang detection
  - Removed complex symlink resolution
  - Tested with bash script agent - works perfectly
- ✅ Added `System.find_executable/1` to resolve paths from PATH
- ✅ Added validation and clear error messages:
  - File existence check
  - Executable permission check
  - Clear error messages for common failure cases
- ✅ Added comprehensive unit tests in `connection_test.exs`:
  - Test with absolute paths to existing executables
  - Test with non-existent files
  - Test with non-executable files
  - Test with commands in PATH
  - Test with commands not in PATH
- ✅ Verified backward compatibility with e2e tests

---

## Protocol Implementation

### 2. Implement Proper Schema with Ecto.Schema

**Status:** 🟢 Core implementation complete **Context:** The official ACP
specification defines a complete JSON schema. We have implemented a proper
`Ecto.Schema`-based system with automatic camelCase ↔ snake_case conversion via
the `:source` field option, comprehensive validation via changesets, and a
dedicated `ACPex.Schema.Codec` module for encoding/decoding.

**Completed Work:**

- ✅ Added `ecto` dependency to `mix.exs`
- ✅ Created comprehensive Ecto schemas using `:source` field option:
  - `lib/acpex/schema/connection/` - InitializeRequest/Response,
    AuthenticateRequest/Response
  - `lib/acpex/schema/session/` - NewRequest/Response, PromptRequest/Response,
    UpdateNotification, CancelNotification
  - `lib/acpex/schema/client/` - FsReadTextFileRequest/Response,
    FsWriteTextFileRequest/Response
  - `lib/acpex/schema/client/terminal/` - All 5 terminal operations (Create,
    Output, WaitForExit, Kill, Release)
  - `lib/acpex/schema/types/` - EnvVariable, TerminalExitStatus
- ✅ Implemented `ACPex.Schema.Codec` module with:
  - `encode!/1` and `encode_to_map!/1` for struct → JSON/map conversion
  - `decode!/2` and `decode_from_map!/2` for JSON/map → struct conversion
  - Automatic camelCase ↔ snake_case conversion via `:source` field mappings
  - Nil value removal from encoded output
- ✅ Implemented `Jason.Encoder` protocol for all schemas
- ✅ Added changeset-based validation for all schemas
- ✅ Created comprehensive test suites:
  - `test/acpex/schema/codec_test.exs` - 19 tests for core schemas
  - `test/acpex/schema/terminal_test.exs` - 20 tests for terminal schemas
  - `test/acpex/schema_test.exs` - 14 tests demonstrating schema usage
  - `test/acpex/schema/types_test.exs` - 18 tests for AuthMethod and
    Capabilities
  - `test/acpex/schema/content_block_test.exs` - 22 tests for ContentBlock union
    type
  - `test/acpex/schema/session_update_test.exs` - 21 tests for SessionUpdate
    union type
- ✅ All tests pass (157 total tests, 0 failures)
- 🟡 Old `ACPex.Json` and `ACPex.Schema` modules still exist for backward
  compatibility

**Remaining Tasks (Optional/Future):**

- [x] Read the complete official schema:
      https://agentclientprotocol.com/protocol/schema
- [x] Add `ecto` dependency to `mix.exs`
- [x] Create Ecto schemas for core protocol types in `lib/acpex/schema/`:

  **Connection-Level Messages:**

  - [x] `InitializeRequest` / `InitializeResponse`
  - [x] `AuthenticateRequest` / `AuthenticateResponse`

  **Session-Level Messages:**

  - [x] `NewRequest` / `NewResponse`
  - [x] `PromptRequest` / `PromptResponse`
  - [x] `UpdateNotification`
  - [x] `CancelNotification`

  **Client Requests (agent → client):**

  - [x] `FsReadTextFileRequest` / `FsReadTextFileResponse`
  - [x] `FsWriteTextFileRequest` / `FsWriteTextFileResponse`
  - [x] `TerminalCreateRequest` / `TerminalCreateResponse`
  - [x] `TerminalOutputRequest` / `TerminalOutputResponse`
  - [x] `TerminalWaitForExitRequest` / `TerminalWaitForExitResponse`
  - [x] `TerminalKillRequest` / `TerminalKillResponse`
  - [x] `TerminalReleaseRequest` / `TerminalReleaseResponse`

  **Shared Types:**

  - [x] `EnvVariable` - Environment variable type for terminal creation
  - [x] `TerminalExitStatus` - Terminal exit status information
  - [x] `ContentBlock` (text, image, audio, resource_link, resource) -
        Discriminated union with 5 variants
  - [x] `SessionUpdate` (message, thought, tool call, plan, etc.) -
        Discriminated union with 8 variants
  - [x] `AuthMethod` - Authentication method information
  - [x] `Capabilities` - Agent and client capabilities (AgentCapabilities,
        ClientCapabilities, PromptCapabilities, McpCapabilities,
        FileSystemCapability)

- [x] Implemented schemas using `:source` field option for camelCase mapping:

  ```elixir
  defmodule ACPex.Schema.InitializeRequest do
    use Ecto.Schema
    import Ecto.Changeset

    @primary_key false
    embedded_schema do
      # Use :source to specify the exact JSON key name (camelCase)
      # Elixir field name uses snake_case for idiomatic code
      field :protocol_version, :integer, source: :protocolVersion
      field :client_info, :map, source: :clientInfo
      field :capabilities, :map
      field :authentication_methods, {:array, :string}, source: :authenticationMethods
    end

    def changeset(struct, params) do
      struct
      |> cast(params, [:protocol_version, :client_info, :capabilities, :authentication_methods])
      |> validate_required([:protocol_version])
    end

    # Encoding: use Jason.Encoder with source fields
    defimpl Jason.Encoder do
      def encode(value, opts) do
        # Ecto.embedded_dump/2 respects :source field mappings
        value
        |> Ecto.embedded_dump(:json)
        |> Jason.Encode.map(opts)
      end
    end
  end
  ```

  **Key Points:**

  - Use `:source` field option to explicitly map Elixir field names (snake_case)
    to JSON keys (camelCase)
  - No need for separate case conversion functions - the schema IS the mapping
  - `Ecto.embedded_dump(:json)` automatically uses `:source` mappings when
    encoding
  - When decoding, use `Ecto.embedded_load/3` which also respects `:source`
    mappings
  - This makes the schema self-documenting and the single source of truth

- [x] Created helper module `ACPex.Schema.Codec` for encoding/decoding with
      schemas

  - See `lib/acpex/schema/codec.ex`
  - Includes `encode!/1`, `encode_to_map!/1`, `decode!/2`, `decode_from_map!/2`
  - Handles automatic camelCase ↔ snake_case conversion
  - Removes nil values from encoded output

- [ ] Update transport layer to use schemas instead of maps (optional - backward
      compatible)
- [ ] Add validation at message boundaries (optional - can use changesets)

**Benefits Achieved:**

- ✅ Type safety and compile-time checks via Ecto schemas
- ✅ Auto-generated documentation from schema definitions
- ✅ Validation ensures protocol compliance via changesets
- ✅ Clear mapping between Elixir (snake_case) and JSON (camelCase)
- ✅ Single source of truth for protocol specification

**Next Steps:**

The schema system is now **fully complete** with ALL protocol types from the
official ACP specification implemented:

- ✅ Connection, Session, and File operation schemas
- ✅ All 5 terminal operation schemas
- ✅ Supporting types (EnvVariable, TerminalExitStatus)
- ✅ **Complex union types**:
  - ContentBlock (5 variants: text, image, audio, resource_link, resource)
  - SessionUpdate (8 variants: user_message_chunk, agent_message_chunk,
    agent_thought_chunk, tool_call, tool_call_update, plan,
    available_commands_update, current_mode_update)
- ✅ **Complete capability schemas**:
  - AuthMethod - Authentication method information
  - AgentCapabilities - Agent capabilities including MCP and prompt capabilities
  - ClientCapabilities - Client capabilities including file system and terminal
  - PromptCapabilities - Audio, image, and embedded context support
  - McpCapabilities - HTTP and SSE transport support
  - FileSystemCapability - Read and write text file support

Total: **27 schema files** with **157 passing tests** (61 tests added for new
schemas)

The old `ACPex.Json` and `ACPex.Schema` modules remain for backward
compatibility.

---

### 3. Use Structs Over Maps in Public API

**Status:** ✅ **COMPLETED** **Context:** Successfully migrated the entire public API from maps to typed structs using the Ecto schema system.

**Completed Work:**

- ✅ Audited and updated all public API functions:
  - ✅ `ACPex.Protocol.Connection` - Uses Codec to decode/encode all messages
  - ✅ `ACPex.Agent` behaviour - All callbacks use typed struct parameters and return values
  - ✅ `ACPex.Client` behaviour - All callbacks use typed struct parameters and return values
  - ✅ `ACPex.Protocol.Session` - Uses Codec for all message handling
- ✅ Migrated all production code to use new schemas
- ✅ Removed legacy `ACPex.Json` module (deleted lib/acpex/json.ex)
- ✅ Removed legacy `ACPex.Schema` module (deleted lib/acpex/schema.ex)
- ✅ Removed `inflex` dependency from mix.exs
- ✅ All behaviour callbacks now use typed structs
- ✅ Updated all tests to use struct-based API:
  - ✅ Integration tests (7/7 passing)
  - ✅ Unit tests (ConnectionTest, SessionTest)
  - ✅ E2E tests (including claude_code_acp)
- ✅ All 157 tests passing with 0 failures
- ✅ Pattern matching works naturally with structs throughout codebase

**Example Before:**

```elixir
def handle_fs_read_text_file(%{"path" => path}, state) do
  {:ok, %{"content" => content}, state}
end
```

**Example After:**

```elixir
def handle_fs_read_text_file(request, state) do
  response = %ACPex.Schema.Client.FsReadTextFileResponse{content: content}
  {:ok, response, state}
end
```

**Benefits Achieved:**

- ✅ Complete type safety at compile time via Ecto schemas
- ✅ Automatic camelCase ↔ snake_case conversion via `:source` fields
- ✅ Clear, self-documenting API with struct pattern matching
- ✅ No manual key conversion needed anywhere in codebase
- ✅ Protocol compliance guaranteed by schema validation

---

### 4. Remove CamelCase Conversion Functions

**Status:** ✅ **COMPLETED** **Context:** All camelCase/snake_case conversion is now handled automatically by Ecto schemas using `:source` field parameters. All manual conversion code has been eliminated.

**Completed Work:**

- ✅ Removed all manual camelCase/snake_case conversion code
- ✅ All conversions now happen automatically in schemas via `:source` field parameter
- ✅ Deleted `ACPex.Json` module (lib/acpex/json.ex) - no longer needed
- ✅ Deleted old `ACPex.Schema` module (lib/acpex/schema.ex) - replaced by Ecto schemas
- ✅ Removed `inflex` dependency from mix.exs - no longer needed
- ✅ Connection and Session layers use `ACPex.Schema.Codec` for all encoding/decoding
- ✅ Schemas are now the single source of truth for field name mappings
- ✅ Updated Connection.ex to handle both camelCase and snake_case for backward compatibility
- ✅ All tests updated to use struct-based assertions

**Actual Implementation:**

```elixir
# lib/acpex/protocol/connection.ex - No manual conversion!
defp handle_incoming_message(%{"method" => method, "params" => params} = msg, state) do
  # Decode directly to struct using schema with :source fields
  request_struct = decode_connection_request(method, params)

  # Invoke handler with struct
  case apply(state.handler_module, callback, [request_struct, state.handler_state]) do
    {:ok, result_struct, new_handler_state} ->
      # Encode struct back to map - automatic camelCase conversion!
      result_map = Codec.encode_to_map!(result_struct)
      response = build_response(id, result_map)
      # ...
  end
end
```

**Benefits Achieved:**

- ✅ Zero manual conversion code in the entire codebase
- ✅ Schemas handle all camelCase ↔ snake_case automatically via `:source` fields
- ✅ Protocol layer works entirely with typed structs
- ✅ Cleaner, more maintainable code with single source of truth
- ✅ Compile-time safety with no runtime string manipulation

---

## Testing & Quality

### 5. Improve Test Coverage

**Tasks:**

- [ ] Add unit tests for `resolve_executable/2`
- [ ] Add unit tests for all schema validations
- [ ] Test error cases (invalid JSON, missing required fields, etc.)
- [ ] Add property-based tests for schema encoding/decoding
- [ ] Test concurrent sessions properly

### 6. Performance & Reliability

**Tasks:**

- [ ] Profile memory usage with long-running sessions
- [ ] Test handling of large responses (image data, long code)
- [ ] Add backpressure handling for high message volumes
- [ ] Test reconnection scenarios if agent crashes

---

## Documentation

### 7. API Documentation

**Tasks:**

- [ ] Add comprehensive `@moduledoc` to all public modules
- [ ] Add `@doc` with examples to all public functions
- [ ] Create guides in `docs/`:
  - [ ] `docs/getting_started.md`
  - [ ] `docs/building_agents.md`
  - [ ] `docs/building_clients.md`
  - [ ] `docs/protocol_overview.md`
- [ ] Add typespecs (`@spec`) to all public functions
- [ ] Generate and publish HexDocs

---

## Future Features

### 8. Additional Transport Options

**Tasks:**

- [ ] WebSocket transport for browser-based clients
- [ ] HTTP/SSE transport for serverless deployments
- [ ] Unix socket transport for same-machine communication

### 9. MCP Integration

**Tasks:**

- [ ] Research MCP protocol overlap with ACP
- [ ] Design shared schema types between ACPex and future MCPex library
- [ ] Consider extracting shared types into `acp_mcp_types` package

---

## Done ✅

### Critical Issues Resolved

- [x] **Debug and Fix `session/prompt` Timeout** - The transport now
      successfully handles all Claude Code ACP operations including
      `session/prompt`. Fixed by integrating Exile library with proper
      backpressure and async I/O.
  - Test location: `test/acpex/e2e_test.exs:676` (now passing)
  - Solution: Exile integration eliminated timeout issues

### Phase 3: Struct-Based API Migration

- [x] **Complete migration from maps to typed structs** - All public API now
      uses Ecto schemas throughout (Phase 3 complete)
  - Updated all behaviour callback signatures to use typed structs
  - Integrated Codec into Connection and Session protocol layers
  - Removed legacy ACPex.Json and ACPex.Schema modules
  - All 157 tests passing (integration, unit, E2E)
  - Zero manual camelCase conversion - all handled by schemas

### Transport Layer Improvements

- [x] **Implement Port-based transport** - Transport now uses native Erlang Ports
      with line-buffered I/O, non-blocking async message passing, and automatic
      process cleanup
  - Implementation: `lib/acpex/transport/ndjson.ex`
  - Provides bidirectional streaming with automatic line-based message framing
  - Uses `:spawn_executable` for direct process spawning
- [x] Remove `:stderr_to_stdout` from transport (was polluting JSON stream)
- [x] Simplify executable handling - OS handles shebangs automatically
- [x] Add debug logging to transport layer

### Protocol Compliance

- [x] Fix protocol version type (use integer `1` not string `"1.0"`)
- [x] Update test assertions to accept multiple protocol version formats
- [x] Fix capabilities field name mismatch (`capabilities` vs
      `agentCapabilities`)

### Schema & Serialization (Interim Solution)

- [x] Create `ACPex.Json` module for camelCase ↔ snake_case conversion
- [x] Define basic protocol structs in `lib/acpex/schema.ex`
- [x] Add Inflex dependency for case conversion
  - Note: This is a temporary solution; migration to Ecto.Schema planned

---

## Notes

- **Protocol Reference:** https://agentclientprotocol.com/
- **Official Schema:** https://agentclientprotocol.com/protocol/schema
- **Reference Implementation:**
  https://github.com/zed-industries/agent-client-protocol (Rust)
- **Claude Code ACP:** https://github.com/zed-industries/claude-code-acp
  (TypeScript)

---

## Quick Links

- E2E Tests: `test/acpex/e2e_test.exs`
- Transport: `lib/acpex/transport/ndjson.ex`
- Connection: `lib/acpex/protocol/connection.ex`
- Session: `lib/acpex/protocol/session.ex`
