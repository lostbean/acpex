# ACPex TODO

## Critical Issues

### 1. Debug and Fix `session/prompt` Timeout

**Status:** 🔴 Blocking E2E tests **Context:** The transport now successfully
spawns Claude Code ACP and handles `initialize` and `session/new`, but
`session/prompt` requests time out after 90 seconds.

**Tasks:**

- [ ] Manually simulate the failed E2E test using `echo` commands piped directly
      to the ACP agent
  ```bash
  # Test the complete flow manually to isolate the issue
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,...}}' | /Users/edgar/.npm-global/bin/claude-code-acp
  echo '{"jsonrpc":"2.0","id":2,"method":"session/new","params":{"cwd":"/tmp","mcpServers":[]}}' | ...
  echo '{"jsonrpc":"2.0","id":3,"method":"session/prompt","params":{...}}' | ...
  ```
- [ ] Compare manual interaction vs. automated test to identify differences
- [ ] Add transport-level logging to see if prompt responses are being received
      but not processed
- [ ] Check if session updates (`session/update` notifications) are causing the
      response to be missed
- [ ] Verify the connection is properly routing session-level messages to
      session GenServer

**Location:** `test/acpex/e2e_test.exs:683` (test "creates session and handles
prompts with claude code")

---

## Architecture Improvements

### 2. Generic Executable Handling (Remove Node.js Special-Casing)

**Status:** 🟡 Works but not ideal **Context:** Currently we have special logic
to detect Node.js scripts and spawn them with `node`. This should be generalized
to handle any executable properly.

**Current Issue:**

```elixir
# lib/acpex/protocol/connection.ex:247-280
defp resolve_executable(path, args) do
  # Special cases for .js/.mjs files
  # Special cases for shebang scripts
  # Falls back to treating as binary
end
```

**Tasks:**

- [ ] Research Elixir/Erlang best practices for spawning external processes
  - Read Erlang Port documentation:
    https://www.erlang.org/doc/man/erlang#open_port-2
  - Check how other Elixir projects handle this (e.g., Porcelain, Exile)
  - Look into `:os.cmd/1` vs `System.cmd/3` vs `Port.open/2` tradeoffs
- [ ] Simplify `resolve_executable/2` to handle all executables uniformly
  - Let the OS handle shebang scripts (they should work with
    `:spawn_executable`)
  - Remove Node.js-specific detection
  - Test with multiple agent types (bash script, Node.js, potential Python/Ruby
    agents)
- [ ] Consider using `System.find_executable/1` to validate paths before
      spawning
- [ ] Add clear error messages when executable cannot be spawned

**References:**

- Port documentation: https://hexdocs.pm/elixir/Port.html
- Erlang spawn options: https://www.erlang.org/doc/man/erlang#open_port-2

---

## Protocol Implementation

### 3. Implement Proper Schema with Ecto.Schema

**Status:** 🟡 Currently using plain maps **Context:** The official ACP
specification defines a complete JSON schema. We should use `Ecto.Schema` to
define typed structs for all protocol messages, ensuring type safety and
automatic validation.

**Current State:**

- Messages are passed as plain maps with string keys
- No compile-time validation
- Manual key conversion between camelCase (protocol) and snake_case (Elixir)
- No documentation of required/optional fields in the code

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
  - Use `:source` field option to explicitly map Elixir field names (snake_case) to JSON keys (camelCase)
  - No need for separate case conversion functions - the schema IS the mapping
  - `Ecto.embedded_dump(:json)` automatically uses `:source` mappings when encoding
  - When decoding, use `Ecto.embedded_load/3` which also respects `:source` mappings
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

### 4. Use Structs Over Maps in Public API

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

### 5. Remove CamelCase Conversion Functions

**Status:** 🟡 Currently manual conversion **Context:** With proper Ecto
schemas using `:source` field parameters, all key conversion is handled
automatically by the schema layer - no separate conversion functions needed!

**Current State:**

```elixir
# lib/acpex/protocol/connection.ex:260-263
defp handle_incoming_message(%{"params" => %{"sessionId" => session_id}} = msg, state) do
  # Manual conversion - should be eliminated
  msg_with_snake_case = put_in(msg, ["params", "session_id"], session_id)
  handle_incoming_message(msg_with_snake_case, state)
end
```

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
- [ ] All conversions happen in schemas via `:source` field parameter (see Task #3)
- [ ] Use `Ecto.embedded_dump(:json)` for encoding (respects `:source`)
- [ ] Use `Ecto.embedded_load/3` for decoding (respects `:source`)
- [ ] Schemas become the single source of truth for field name mappings
- [ ] No need for `ACPex.JSON.to_camel_case()` helper - delete it!

**Location of manual conversions to remove:**

- `lib/acpex/protocol/connection.ex:260-264`
- `test/acpex/e2e_test.exs:314, 659, 711, 775, 843` (test assertions can use structs directly)

---

## Testing & Quality

### 6. Improve Test Coverage

**Tasks:**

- [ ] Add unit tests for `resolve_executable/2`
- [ ] Add unit tests for all schema validations
- [ ] Test error cases (invalid JSON, missing required fields, etc.)
- [ ] Add property-based tests for schema encoding/decoding
- [ ] Test concurrent sessions properly

### 7. Performance & Reliability

**Tasks:**

- [ ] Profile memory usage with long-running sessions
- [ ] Test handling of large responses (image data, long code)
- [ ] Add backpressure handling for high message volumes
- [ ] Test reconnection scenarios if agent crashes

---

## Documentation

### 8. API Documentation

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

### 9. Additional Transport Options

**Tasks:**

- [ ] WebSocket transport for browser-based clients
- [ ] HTTP/SSE transport for serverless deployments
- [ ] Unix socket transport for same-machine communication

### 10. MCP Integration

**Tasks:**

- [ ] Research MCP protocol overlap with ACP
- [ ] Design shared schema types between ACPex and future MCPex library
- [ ] Consider extracting shared types into `acp_mcp_types` package

---

## Done ✅

- [x] Remove `:stderr_to_stdout` from transport (was polluting JSON stream)
- [x] Fix Node.js script spawning (detect .js files, spawn with `node`)
- [x] Add debug logging to transport layer
- [x] Fix protocol version type (use integer `1` not string `"1.0"`)
- [x] Update test assertions to accept multiple protocol version formats
- [x] Fix capabilities field name mismatch (`capabilities` vs
      `agentCapabilities`)

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
