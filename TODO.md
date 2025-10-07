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

**Status:** 🟡 Temporary solution in place **Context:** The official ACP
specification defines a complete JSON schema. We currently have `ACPex.Json`
module with custom structs using Inflex for case conversion, but we should
migrate to `Ecto.Schema` for proper validation and type safety.

**Current State:**

- `ACPex.Json` module provides basic structs with camelCase ↔ snake_case
  conversion
- Uses Inflex library for case conversion
- Basic structs defined in `lib/acpex/schema.ex`
- Still passing plain maps in Connection/Session APIs
- No compile-time validation or changeset-based validation
- No documentation of required/optional fields beyond `@enforce_keys`

**Tasks:**

- [ ] Read the complete official schema:
      https://agentclientprotocol.com/protocol/schema
- [ ] Add `ecto` dependency to `mix.exs`
- [ ] Create Ecto schemas for all protocol types in `lib/acpex/schema/`:

  **Connection-Level Messages:**
  - [ ] `InitializeRequest` / `InitializeResponse`
  - [ ] `AuthenticateRequest` / `AuthenticateResponse`

  **Session-Level Messages:**
  - [ ] `SessionNewRequest` / `SessionNewResponse`
  - [ ] `SessionPromptRequest` / `SessionPromptResponse`
  - [ ] `SessionUpdateNotification`
  - [ ] `SessionCancelNotification`

  **Client Requests (agent → client):**
  - [ ] `FsReadTextFileRequest` / `FsReadTextFileResponse`
  - [ ] `FsWriteTextFileRequest` / `FsWriteTextFileResponse`
  - [ ] `TerminalCreateRequest` / `TerminalCreateResponse`
  - [ ] `TerminalOutputRequest` / `TerminalOutputResponse`
  - [ ] `TerminalWaitForExitRequest` / `TerminalWaitForExitResponse`
  - [ ] `TerminalKillRequest` / `TerminalKillResponse`
  - [ ] `TerminalReleaseRequest` / `TerminalReleaseResponse`

  **Shared Types:**
  - [ ] `PromptContent` (text, image, embedded context)
  - [ ] `SessionUpdate` (message, thought, tool call, plan, etc.)
  - [ ] `AuthMethod`
  - [ ] `Capabilities`

- [ ] Implement schemas using `:source` field option for camelCase mapping:
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

- [ ] Create helper module for encoding/decoding with schemas:
  ```elixir
  defmodule ACPex.Schema.Codec do
    def encode!(struct) do
      struct
      |> Ecto.embedded_dump(:json)
      |> Jason.encode!()
    end

    def decode!(json, schema_module) do
      json
      |> Jason.decode!()
      |> then(&Ecto.embedded_load(schema_module, &1, :json))
    end
  end
  ```

- [ ] Update transport layer to use schemas instead of maps
- [ ] Add validation at message boundaries (incoming and outgoing)

**Benefits:**

- Type safety and compile-time checks
- Auto-generated documentation from schema definitions
- Validation ensures protocol compliance
- Clear mapping between Elixir (snake_case) and JSON (camelCase)

---

### 3. Use Structs Over Maps in Public API

**Status:** 🟡 Mixed usage **Context:** Currently the API mixes structs and
maps. We should consistently use structs for better developer experience.

**Tasks:**

- [ ] Audit all public API functions in:
  - [ ] `ACPex.Protocol.Connection`
  - [ ] `ACPex.Agent` behaviour
  - [ ] `ACPex.Client` behaviour
- [ ] Replace map parameters with typed structs
- [ ] Update documentation to show struct usage
- [ ] Ensure pattern matching works naturally with structs

**Example Before:**

```elixir
def send_request(pid, method, %{"sessionId" => session_id, "prompt" => prompt})
```

**Example After:**

```elixir
def send_request(pid, %ACPex.Schema.SessionPromptRequest{session_id: session_id, prompt: prompt})
```

---

### 4. Remove CamelCase Conversion Functions

**Status:** 🟡 Partially handled **Context:** `ACPex.Json` module handles
systematic conversion for structs, but manual conversion still exists in some
places. With proper Ecto schemas using `:source` field parameters, ALL key
conversion should be handled automatically by the schema layer.

**Current State:**

```elixir
# lib/acpex/protocol/connection.ex:351-363
defp handle_incoming_message(%{"params" => %{"sessionId" => session_id}} = msg, state) do
  # Manual conversion - should be eliminated
  new_params = params |> Map.put("session_id", session_id) |> Map.delete("sessionId")
  msg_with_snake_case = Map.put(msg, "params", new_params)
  handle_incoming_message(msg_with_snake_case, state)
end
```

**Note:** `ACPex.Json` module provides automatic conversion for structs, but
Connection/Session layers still work with plain maps and do manual conversions.

**Target State with Schemas:**

```elixir
# No conversion needed - schema handles it!
defp handle_incoming_message(%{"method" => "session/prompt"} = msg, state) do
  # Decode directly to struct using schema with :source fields
  request = ACPex.Schema.Codec.decode!(msg["params"], ACPex.Schema.SessionPromptRequest)
  # Now access as: request.session_id (Elixir snake_case)
  # When encoding back: automatically becomes "sessionId" (JSON camelCase)
end
```

**Tasks:**

- [ ] Remove all manual camelCase/snake_case conversion code
- [ ] All conversions happen in schemas via `:source` field parameter (see Task
      #2)
- [ ] Use `Ecto.embedded_dump(:json)` for encoding (respects `:source`)
- [ ] Use `Ecto.embedded_load/3` for decoding (respects `:source`)
- [ ] Schemas become the single source of truth for field name mappings
- [ ] No need for `ACPex.JSON.to_camel_case()` helper - delete it!

**Location of manual conversions to remove:**

- `lib/acpex/protocol/connection.ex:351-363` (sessionId conversion)
- `lib/acpex/json.ex` - Replace entire module with Ecto schema approach
- `test/acpex/e2e_test.exs` (test assertions can use structs directly)

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

### Transport Layer Improvements

- [x] **Integrate Exile for process management** - Transport now uses
      `Exile.stream!` with proper backpressure, non-blocking async I/O, and
      prevention of zombie processes
  - Implementation: `lib/acpex/transport/ndjson.ex`
  - Provides bidirectional streaming with automatic flow control
- [x] Remove `:stderr_to_stdout` from transport (was polluting JSON stream)
- [x] Fix Node.js script spawning (detect .js files, spawn with `node`)
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
