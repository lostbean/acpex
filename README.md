# ACPex

[![Hex.pm](https://img.shields.io/hexpm/v/acpex.svg)](https://hex.pm/packages/acpex)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/acpex/)
[![License](https://img.shields.io/hexpm/l/acpex.svg)](https://github.com/yourusername/acpex/blob/main/LICENSE)

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
- **Non-Blocking Transport Layer**: Uses an Erlang Port
  (`ACPex.Transport.Stdio`) for non-blocking, asynchronous I/O over
  stdin/stdout.
- **Full Protocol Implementation**: Implements the full JSON-RPC 2.0
  specification for bidirectional requests, notifications, and request/response
  correlation.
- **Typed Schema**: All protocol messages are defined as type-safe Elixir
  structs in `ACPex.Schema` for clarity and Dialyzer compatibility.
- **Best Practices**: Follows modern Elixir best practices, using `jason` for
  high-performance JSON parsing and leveraging OTP principles for robustness.

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

  def init(_args) do
    # Return the initial state for your client
    {:ok, %{}}
  end

  def handle_session_update(params, state) do
    IO.inspect(params, label: "Update from agent")
    {:noreply, state}
  end

  def handle_read_text_file(%{"path" => path}, state) do
    case File.read(path) do
      {:ok, content} ->
        {:ok, %{"content" => content}, state}

      {:error, _reason} ->
        # In a real implementation, you would inspect the reason
        {:error, %{code: -32001, message: "File not found"}, state}
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

