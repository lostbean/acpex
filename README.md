# ACPex

[![Hex.pm](https://img.shields.io/hexpm/v/acpex.svg)](https://hex.pm/packages/acpex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/acpex/)
[![License](https://img.shields.io/hexpm/l/acpex.svg)](https://github.com/lostbean/acpex/blob/main/LICENSE)

`ACPex` is a robust, performant, and idiomatic Elixir implementation of the
Agent Client Protocol (ACP).

## Which ACP Is This?

**IMPORTANT**: There are two different protocols that use the "ACP" acronym:

1. **Agent Communication Protocol**
   ([agentcommunicationprotocol.dev](https://agentcommunicationprotocol.dev)) -
   A REST-based protocol for inter-agent communication across distributed AI
   systems.

2. **Agent Client Protocol**
   ([agentclientprotocol.com](https://agentclientprotocol.com)) - A JSON-RPC
   based protocol for communication between code editors and local AI coding
   agents.

**This library implements #2** - the JSON-RPC based protocol from Zed Industries
for editor-to-agent communication over stdio. If you're looking to build
distributed AI agent networks, this is not the library you need.

## Overview

The Agent Client Protocol enables code editors to communicate with AI coding
agents through a standardized interface, similar to how the Language Server
Protocol (LSP) works for language servers. This library provides the core
components to build AI-powered coding agents or integrate ACP support into
Elixir-based development tools.

Built on OTP, `ACPex` provides a fault-tolerant and highly concurrent foundation
for agent-client communication.

## Features

- **Core OTP Architecture**: A central `ACPex.Connection` GenServer manages the
  stateful, bidirectional JSON-RPC communication, with clear `ACPex.Client` and
  `ACPex.Agent` behaviours.
- **Non-Blocking Transport Layer**: Uses native Erlang Ports for robust,
  non-blocking, asynchronous newline-delimited JSON (ndjson) I/O over
  stdin/stdout with automatic process cleanup and line-buffered message framing.
- **Full Protocol Implementation**: Implements the full JSON-RPC 2.0
  specification for bidirectional requests, notifications, and request/response
  correlation.
- **Typed Schema System**: Complete Ecto.Schema-based type system for all
  protocol messages with automatic camelCase ↔ snake_case conversion via
  `:source` field mappings. All 27 protocol types implemented with compile-time
  validation.
- **Best Practices**: Follows modern Elixir best practices, using `jason` for
  high-performance JSON parsing, `ecto` for schemas, and leveraging OTP
  principles for robustness.

## Installation

The package can be installed by adding `acpex` to your list of dependencies in
`mix.exs`:

```elixir
def deps do
  [
    {:acpex, "~> 0.1.0"}
  ]
end
```

## Usage

To create a client that connects to an agent (e.g., for an editor integration),
you implement the `ACPex.Client` behaviour.

```elixir
defmodule MyEditor.Client do
  @behaviour ACPex.Client

  alias ACPex.Schema.Client.{FsReadTextFileResponse, FsWriteTextFileResponse}
  alias ACPex.Schema.Session.UpdateNotification

  def init(_args) do
    # Return the initial state for your client
    {:ok, %{}}
  end

  def handle_session_update(%UpdateNotification{} = notification, state) do
    IO.inspect(notification.update, label: "Update from agent")
    {:noreply, state}
  end

  def handle_fs_read_text_file(request, state) do
    case File.read(request.path) do
      {:ok, content} ->
        response = %FsReadTextFileResponse{content: content}
        {:ok, response, state}

      {:error, _reason} ->
        {:error, %{code: -32001, message: "File not found"}, state}
    end
  end

  def handle_fs_write_text_file(request, state) do
    case File.write(request.path, request.content) do
      :ok ->
        response = %FsWriteTextFileResponse{}
        {:ok, response, state}

      {:error, _reason} ->
        {:error, %{code: -32002, message: "Failed to write file"}, state}
    end
  end

  # ... implement other callbacks defined in ACPex.Client
end

# Start the client, connecting to an agent executable
{:ok, pid} = ACPex.start_client(MyEditor.Client, [], agent_path: "/path/to/my/agent")
```

Similarly, to create an agent, you implement the `ACPex.Agent` behaviour and
start it with `ACPex.start_agent/3`.

## Documentation

Full API documentation can be found at <https://hexdocs.pm/acpex>.

## License

This project is licensed under the Apache-2.0 License.
