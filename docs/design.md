# **Building acp\_ex: An Architectural Blueprint for an Elixir Agent Client Protocol Library**

## **Section 1: Executive Summary: A Blueprint for acp\_ex**

### **1.1. Report Mandate and Purpose**

This report presents a comprehensive architectural blueprint for the development
of acp\_ex, an idiomatic Elixir library for the Agent Client Protocol (ACP). The
primary objective is to provide a detailed technical guide that enables Elixir
developers to build both ACP-compliant Artificial Intelligence (AI) agents and
client-side integrations, such as plugins for code editors. The design detailed
herein prioritizes robustness, idiomatic Elixir patterns, and alignment with the
official protocol specification, ensuring that the resulting library can serve
as a foundational component for AI-powered developer tooling within the Elixir
ecosystem.

### **1.2. The Strategic Imperative for ACP**

The software development landscape is undergoing a significant paradigm shift,
marked by the deep integration of AI assistants into the coding workflow.
Historically, these AI tools have been tightly coupled with specific Integrated
Development Environments (IDEs), creating fragmented ecosystems and vendor
lock-in. The Agent Client Protocol emerges as a strategic solution to this
problem, proposing an open standard for communication between any code editor
and any AI coding agent. In much the same way that the Language Server Protocol
(LSP) successfully decoupled language-specific intelligence from editors, ACP
aims to unbundle AI assistance, fostering a "Bring Your Own Agent" environment.
By establishing a universal interface, ACP allows developers to mix and match
their preferred editors and AI agents, promoting innovation and
interoperability. The development of acp\_ex is therefore a critical step to
ensure the Elixir ecosystem can fully participate in and contribute to this next
generation of development tools.

### **1.3. Proposed Architecture at a Glance**

The proposed architecture for acp\_ex is fundamentally rooted in the principles
of OTP (Open Telecom Platform), leveraging Elixir's core strengths in
concurrency, state management, and fault tolerance. The design is symmetric and
behaviour-based, reflecting the bidirectional nature of the protocol itself. The
core of the system will be modeled using GenServer processes to manage the state
of individual connections and conversation sessions. These processes will be
organized within a robust supervision tree, managed by Supervisor processes, to
ensure resilience and self-healing capabilities. This OTP-centric approach
provides a highly scalable and maintainable foundation that is perfectly suited
to the stateful, long-running, and interactive communication patterns defined by
the ACP specification.

### **1.4. Key Recommendations and Roadmap**

This report puts forth several key recommendations that form the foundation of
the acp\_ex library. First, it addresses and resolves a critical ambiguity in
the agent protocol landscape, clearly distinguishing the target Zed Industries
ACP from other similarly named protocols. Second, it advocates for the adoption
of a symmetric API design, inspired by the official Rust reference
implementation, which is realized in Elixir through the use of OTP behaviours.
This provides a clear and powerful contract for developers building either
agents or clients. Third, it details a layered OTP process model that cleanly
separates transport, connection, and session logic. Finally, the report outlines
a comprehensive strategy for testing, documentation, and community engagement.
The successful implementation of this blueprint will provide the Elixir
community with a powerful tool, fostering a new wave of interoperable AI-powered
development experiences.

## **Section 2: Deconstructing the Agent Client Protocol (ACP)**

A successful implementation of any protocol library begins with a deep and
precise understanding of the specification itself. This section provides an
exhaustive analysis of the Agent Client Protocol, establishing its technical
underpinnings, scope, and relationship to other protocols in the ecosystem. This
foundational knowledge is essential before proceeding to Elixir-specific
architectural design.

### **2.1. The Agent Protocol Landscape: Establishing a Clear Focus**

The term "Agent Protocol" has been applied to several distinct initiatives,
creating a potential for significant confusion. It is therefore critical to
begin by unambiguously identifying the target protocol for the acp\_ex library.
The focus of this report is exclusively on the **Agent Client Protocol (ACP)**
as specified by Zed Industries and documented at agentclientprotocol.com. This
protocol is specifically designed to standardize communication between code
editors (Clients) and AI coding assistants (Agents) that run as local
subprocesses, communicating over standard I/O via JSON-RPC. This protocol must
be clearly distinguished from the similarly named **Agent Communication Protocol
(ACP)**, an initiative from IBM's BeeAI project. The IBM protocol is
architecturally different, utilizing REST-based communication over HTTP and
focusing on broader interoperability between disparate agentic systems, often
across organizational boundaries. An engineer mistaking one for the other would
make fundamentally incorrect architectural choices, such as building an HTTP
server instead of a stdio stream processor. To further situate the Zed ACP, it
is useful to contrast it with other protocols in the agentic landscape. The
**Model Context Protocol (MCP)**, which ACP leverages, is a standard for
providing AI models with access to tools and data sources. The **Agent-to-Agent
(A2A) Protocol** focuses on enabling collaborative tasks between multiple
autonomous agents. Finally, the **Agent-User Interaction (AG-UI) Protocol** is
designed to standardize how agents connect to user-facing applications, focusing
on generative UI and real-time chat experiences. The Zed ACP's unique niche is
the high-fidelity, low-latency, and deeply integrated experience of an AI agent
operating directly within a developer's code editor. The following table
provides a clear summary of these distinctions. **Table 1: The Agent Protocol
Landscape**

| Protocol Name                      | Primary Proponent  | Transport                     | Core Use Case                                 | Key Differentiator                                |
| :--------------------------------- | :----------------- | :---------------------------- | :-------------------------------------------- | :------------------------------------------------ |
| **Agent Client Protocol (ACP)**    | **Zed Industries** | **JSON-RPC over stdio**       | **In-editor AI coding assistance**            | **LSP-like decoupling of editor and agent**       |
| Agent Communication Protocol (ACP) | IBM / BeeAI        | REST over HTTP                | Cross-platform, multi-agent collaboration     | REST-based, no SDK required, offline discovery    |
| Model Context Protocol (MCP)       | Anthropic          | JSON-RPC (stdio, SSE)         | Exposing tools and data to AI models          | Standard for providing context, not agent control |
| Agent-to-Agent Protocol (A2A)      | A2AProtocol.org    | JSON-RPC, gRPC, REST          | Collaborative tasks between autonomous agents | Focus on agent-to-agent discovery and interaction |
| Agent-User Interaction (AG-UI)     | CopilotKit         | Event-based (SSE, WebSockets) | Connecting agents to user-facing applications | Focus on generative UI and human-in-the-loop chat |

### **2.2. Core Architecture: JSON-RPC 2.0 over Standard I/O**

The technical foundation of ACP is intentionally simple and pragmatic, adopting
proven patterns from existing developer tool standards. The protocol is built
upon the **JSON-RPC 2.0 specification**, which defines a lightweight remote
procedure call protocol using JSON. This standard provides a clear structure for
all communication, which is categorized into three message types:

1. **Requests:** A message containing an id, a method name, and params. The
   recipient must reply with a corresponding Response message carrying the same
   id.
2. **Responses:** A message containing the id of the original request and either
   a result field for successful executions or an error object for failures.
3. **Notifications:** A message with no id field. It is a one-way communication
   that does not expect a response, making it ideal for streaming progress
   updates.

The transport mechanism for these JSON-RPC messages uses newline-delimited JSON
(ndjson), where each complete message is a single JSON object terminated by a
newline character. When a user activates an AI agent, the client (editor) spawns
the agent as a **subprocess**. Communication then occurs bidirectionally over the
standard input (stdin) and standard output (stdout) streams of the subprocess.
Each JSON-RPC message is encoded as a single line: `{...json...}\n`. This format
simplifies parsing and provides natural message boundaries. This bidirectional
channel is crucial to the protocol's design. It allows not only for the client
to send requests to the agent (e.g., "refactor this function") but also for the
agent to send requests back to the client. This reverse channel is essential for
workflows like requesting user permission for a sensitive operation (e.g.,
running a terminal command) or asking the client to read a file from the local
filesystem.

### **2.3. The ACP Lifecycle: A Session-Centric Approach**

Communication in ACP follows a well-defined lifecycle centered around the
concept of a "session," which represents a single, stateful conversation between
the user and the agent. The typical message flow proceeds through several
distinct phases :

1. **Initialization Phase:** The connection begins with the client sending an
   initialize request to the agent. This initial handshake is used to negotiate
   the protocol version and exchange capability information. For example, the
   agent might advertise that it supports loading previous sessions, while the
   client might advertise that it can provide terminal access. If the agent
   requires authentication, the client follows up with an authenticate request.
2. **Session Setup:** Once initialized, the client must establish a session. It
   does this by sending either a session/new request to create a new, clean
   conversation context, or a session/load request to resume a previous session
   if the agent advertised this capability. The agent responds with a unique
   session\_id that will be used in all subsequent messages for that
   conversation.
3. **Prompt Turn:** This is the core interactive loop of the protocol. A "turn"
   begins when the client sends a session/prompt request to the agent,
   containing the user's message and any relevant context (like selected code or
   open files). The agent then begins processing this request. During this
   processing, the agent provides real-time feedback to the client by sending a
   stream of session/update notifications. These notifications can contain
   various types of information :
   - **Message Chunks:** Partial responses from the language model as they are
     generated.
   - **Thoughts:** Explanations of the agent's reasoning process.
   - **Tool Calls:** Information about which tools the agent intends to use.
   - **Plans:** A step-by-step outline of how the agent will tackle a complex
     task.

If the agent needs to perform a privileged action, it will pause and send a
request back to the client, such as session/request\_permission or
fs/read\_text\_file. The client is responsible for handling this request (e.g.,
by showing a confirmation dialog to the user) and sending a response back to the
agent. At any point, the client can send a session/cancel notification to
interrupt the agent's work. The turn concludes when the agent has finished its
work and sends the final response to the original session/prompt request, which
includes a stop\_reason such as done or cancelled.

### **2.4. Strategic Dependencies: The Model Context Protocol (MCP)**

A critical design principle of ACP is its conscious decision not to "reinvent
the wheel". Where possible, ACP reuses data structures and concepts from the
**Model Context Protocol (MCP)**, an open standard from Anthropic designed to
connect AI systems with data sources and tools. This symbiotic relationship is
fundamental to understanding ACP's practical application. While ACP standardizes
the communication channel between the _editor_ and the _agent_, MCP standardizes
the channel between the _agent_ and its _tools_ (e.g., file system access, API
clients, test runners). An ACP agent, in order to be useful, must almost
invariably be an MCP client. It receives a high-level task from the user via an
ACP session/prompt request. To fulfill that task, it then uses the MCP protocol
to discover and call the necessary tools, which might be exposed by an MCP
server running within the editor or elsewhere. This relationship has direct
implications for the design of an ACP library. Data structures related to tool
calls, tool results, code diffs, and resource links within ACP are intentionally
designed to be compatible with their MCP counterparts. This ensures seamless
integration and allows an agent to pass information from its MCP tool
interactions directly into the session/update notifications it sends back to the
editor via ACP. Therefore, a well-designed acp\_ex library must define its
schema for these shared concepts with an eye toward future compatibility with a
potential mcp\_ex library, ensuring the two can work together harmoniously
within the broader Elixir AI ecosystem.

## **Section 3: Architectural Vision: An Idiomatic Elixir Implementation with OTP**

Translating the ACP specification into a functional library requires choosing an
architectural paradigm that aligns with both the protocol's requirements and the
host language's strengths. For Elixir, the clear and compelling choice is to
build the library's core on the foundation of OTP. This section outlines the
high-level architectural vision, justifying the use of OTP and mapping the
protocol's abstract concepts to concrete OTP components.

### **3.1. Why OTP is the Ideal Paradigm for ACP**

The Open Telecom Platform (OTP) is not merely a library but a set of design
principles and behaviours for building concurrent, fault-tolerant, and scalable
applications. These principles map almost perfectly to the challenges presented
by the Agent Client Protocol.

- **State Management:** The ACP is inherently stateful. A connection has a state
  (uninitialized, initialized, authenticated), and each session maintains a
  history of the conversation. The GenServer behaviour provides a robust and
  standardized pattern for encapsulating this state within a lightweight
  process. By isolating state within a process and allowing access only through
  a defined message-passing API, GenServer eliminates entire classes of bugs
  related to shared mutable state and provides a clear, single-threaded model
  for reasoning about state changes.
- **Concurrency:** The protocol specification allows for multiple concurrent
  sessions per connection. The OTP actor model, where each process is a
  lightweight, isolated actor, is the ideal solution for managing this
  concurrency. In the proposed acp\_ex architecture, each session (session\_id)
  will be managed by its own dedicated GenServer process. This natural mapping
  provides concurrency out of the box, simplifies the logic by isolating the
  state of each session, and ensures that a computationally intensive task in
  one session does not block the processing of messages for other sessions.
- **Fault Tolerance:** AI agent operations can be long-running and are
  susceptible to failure, whether due to bugs in the agent's logic, network
  errors when calling external tools, or invalid responses from a language
  model. The OTP Supervisor is designed specifically for this reality. By
  organizing the GenServer processes that manage connections and sessions into a
  supervision tree, the library can automatically detect failures and apply
  predefined restart strategies. This ensures that the crash of a single session
  process does not bring down the entire agent connection, providing the
  self-healing and resilient properties for which Elixir and OTP are renowned.

### **3.2. The acp\_ex Supervision Tree**

The logical, nested structure of the ACP—a connection contains multiple
sessions, and each session processes a sequence of prompts—translates directly
into a hierarchical OTP supervision tree. This structure provides clear lines of
ownership and fault isolation. The proposed supervision strategy is as follows:

1. **AcpEx.Application:** The top-level OTP Application module. Its primary role
   is to start the main supervisor for the library.
2. **AcpEx.ConnectionSupervisor:** A DynamicSupervisor responsible for starting
   and stopping Connection.GenServer processes. A new connection process would
   be started for each agent or client instance.
3. **AcpEx.Connection.GenServer:** A GenServer that manages the state for a
   single agent-client connection. It handles the initial initialize and
   authenticate messages and is responsible for starting its own
   SessionSupervisor.
4. **AcpEx.SessionSupervisor:** A supervisor, likely a DynamicSupervisor, that
   lives under a Connection.GenServer. It is responsible for starting, stopping,
   and monitoring the GenServer processes for all active sessions within that
   connection.
5. **AcpEx.Session.GenServer:** The workhorse GenServer that manages the state
   for a single conversation session, identified by its session\_id. It handles
   session/prompt, session/cancel, and other session-specific messages. For
   long-running prompts, it can spawn Task processes to perform the work
   asynchronously without blocking its own message loop.

This architecture creates a clear mapping from the protocol's concepts to the
library's components, as detailed in the table below. **Table 2: Mapping ACP
Concepts to acp\_ex OTP Components**

| ACP Concept                 | acp\_ex Component                                   | OTP Behaviour | Core Responsibility                                                     |
| :-------------------------- | :-------------------------------------------------- | :------------ | :---------------------------------------------------------------------- |
| Agent Subprocess Lifecycle  | AcpEx.Application                                   | Application   | Starts the top-level supervisor for the agent/client instance.          |
| Agent-Client Connection     | AcpEx.Connection.GenServer                          | GenServer     | Handles initialize/authenticate, manages session supervisors.           |
| Conversation Session        | AcpEx.Session.GenServer                             | GenServer     | Manages state for a single session\_id, handles prompt/cancel.          |
| Long-running Prompt Turn    | Task (spawned by Session.GenServer)                 | Task          | Executes the agent's core logic asynchronously, preventing blocking.    |
| Fault Tolerance & Lifecycle | AcpEx.ConnectionSupervisor, AcpEx.SessionSupervisor | Supervisor    | Monitors and restarts failed processes according to defined strategies. |

### **3.3. The Transport Layer: A Dedicated Ndjson Port/Process**

To maintain a clean separation of concerns, the low-level logic of reading from
stdin and writing to stdout should be isolated from the high-level application
logic of the GenServers. This will be achieved by creating a dedicated transport
module, AcpEx.Transport.Ndjson. This module will be responsible for the raw I/O
operations using the newline-delimited JSON (ndjson) format. It will be
implemented as a GenServer that manages an Elixir Port connected to the standard
I/O of the BEAM virtual machine. Its responsibilities will include:

- Continuously reading data from stdin, buffering until a complete line is
  received.
- Passing each complete line to a JSON parser (e.g., Jason).
- Upon successful parsing, dispatching the decoded JSON-RPC message to the
  appropriate Connection.GenServer or Session.GenServer for processing.
- Receiving outbound messages from the application GenServers.
- Encoding these messages into JSON strings.
- Writing the resulting JSON strings to stdout, followed by a newline character
  (`\n`), as per the ndjson specification.

This architectural choice decouples the core protocol logic from the transport
mechanism. The Connection and Session GenServers can operate purely in terms of
Elixir data structures, unaware of the underlying JSON serialization or I/O
details. This not only simplifies their implementation but also makes the
library more extensible, as it would be straightforward to add alternative
transport layers (e.g., WebSockets) in the future by simply creating a new
module that adheres to the same internal dispatching interface.

## **Section 4: Core Library Implementation: Modules, Data Structures, and APIs**

With the high-level OTP architecture established, this section details the
concrete implementation plan for the acp\_ex library. It covers the proposed
project structure, the translation of the protocol schema into Elixir data
structures, and the design of the public-facing API that developers will use to
build agents and clients.

### **4.1. Project Structure and Dependencies**

The library will follow the standard Elixir project structure, which can be
scaffolded using the command $ mix new acp\_ex \--sup. This command creates a
new Mix project with a skeleton for an OTP application and its top-level
supervisor, aligning perfectly with the proposed architecture. The directory
structure will be organized to promote clarity and separation of concerns:

- lib/acp\_ex.ex: The main application module, responsible for starting the
  top-level supervisor.
- lib/acp\_ex/application.ex: The OTP Application behaviour implementation.
- lib/acp\_ex/transport/ndjson.ex: The dedicated module for handling standard I/O
  with newline-delimited JSON (ndjson) message framing.
- lib/acp\_ex/protocol/connection\_supervisor.ex: The supervisor for connection
  processes.
- lib/acp\_ex/protocol/connection.ex: The GenServer implementation for managing
  a single connection.
- lib/acp\_ex/protocol/session\_supervisor.ex: The supervisor for session
  processes.
- lib/acp\_ex/protocol/session.ex: The GenServer implementation for managing a
  single session.
- lib/acp\_ex/schema/: A directory containing modules that define Elixir structs
  for every data type in the ACP JSON schema. For example,
  lib/acp\_ex/schema/initialize\_request.ex.
- lib/acp\_ex/agent.ex: The definition of the AcpEx.Agent behaviour.
- lib/acp\_ex/client.ex: The definition of the AcpEx.Client behaviour.
- test/: The directory for all ExUnit tests, mirroring the lib/ structure.

The primary external dependency for the library will be a robust JSON parser.
**Jason** is the recommended choice due to its high performance and its status
as the de-facto standard in the Elixir community. For development and testing,
adding a library like ex\_json\_schema could be beneficial for validating that
all incoming and outgoing messages strictly adhere to the official schema.json.

### **4.2. Schema Definition: From JSON to Elixir Structs**

A cornerstone of a robust and maintainable protocol library is a strong, static
type system. While Elixir is dynamically typed, it provides structs as a
mechanism for defining structured, compile-time-checked data containers. Every
object defined in the official ACP schema.json will be mapped to a corresponding
Elixir defstruct. For example, the InitializeRequest would be defined in
lib/acp\_ex/schema/initialize\_request.ex as:
`defmodule AcpEx.Schema.InitializeRequest do`
`@enforce_keys [:protocol_version]`
`defstruct [:protocol_version, :client_info, :authentication_methods]` `end`

Using @enforce\_keys will ensure that any attempt to create a struct without the
required fields will fail at compile time, catching bugs early. To handle the
translation between Elixir's snake\_case atom keys and JSON's camelCase string
keys, a custom Jason.Encoder protocol implementation will be created for a base
struct or via a shared utility. This will allow for idiomatic Elixir code (e.g.,
req.protocol\_version) while ensuring correct serialization for transport (e.g.,
{"protocolVersion": "..."}). This approach provides the dual benefits of
compile-time safety within the Elixir code and strict protocol compliance on the
wire.

### **4.3. The Symmetric API: AcpEx.Agent and AcpEx.Client Behaviours**

The most critical aspect of the library's public API is its design, which must
be both powerful and intuitive for Elixir developers. The official Rust
reference implementation provides an excellent architectural pattern: a
symmetric design where a developer implements a specific trait (Agent or
Client), and the library provides a connection object that exposes the API for
the other side. This elegant pattern can be directly translated into Elixir
using behaviours. This approach avoids the need for two separate libraries and
provides a clear, formal contract for developers. A developer wishing to create
an AI agent will implement the AcpEx.Agent behaviour, while a developer building
an editor plugin will implement the AcpEx.Client behaviour.

#### **4.3.1. The @behaviour AcpEx.Agent**

This behaviour defines the set of callbacks that an agent developer must
implement. The acp\_ex library will handle the underlying GenServer management
and protocol communication, invoking these callbacks at the appropriate times.
Key callbacks would include:

- c:handle\_initialize(init\_request, connection\_state): Called when the client
  sends the initialize request. The implementer returns the agent's
  capabilities.
- c:handle\_new\_session(new\_session\_request, connection\_state): Called to
  create a new session. The implementer can perform setup and return the initial
  state for the new session.
- c:handle\_prompt(prompt\_request, session\_state, client\_proxy): The core
  callback for handling a user prompt. The session\_state is managed by the
  underlying Session.GenServer. The client\_proxy is an abstraction (e.g., a PID
  or a struct of function closures) that allows the agent logic to send
  notifications and requests back to the client (e.g.,
  ClientProxy.send\_update(proxy, update\_payload)).

#### **4.3.2. The @behaviour AcpEx.Client**

This behaviour defines the callbacks for a developer implementing the client
side of the protocol, such as an editor integration. Key callbacks would
include:

- c:handle\_update(session\_update\_notification, session\_state): Called
  whenever the agent sends a session/update notification. The client implementer
  would use this to update the UI.
- c:handle\_request\_permission(permission\_request, session\_state,
  agent\_proxy): Called when the agent requests permission for an action. The
  client logic would prompt the user and use the agent\_proxy to send the
  response.
- c:handle\_read\_file(read\_file\_request, session\_state, agent\_proxy):
  Called when the agent requests to read a file from the client's filesystem.

This behaviour-based design provides a clean separation between the library's
internal machinery and the user's application logic, resulting in an API that is
both idiomatic and easy to use.

### **4.4. Public Interface**

The primary entry points for the library will be simple, high-level functions
that abstract away the complexity of starting the OTP supervision tree and
transport layer.

- AcpEx.start\_agent(agent\_module, initial\_args): This function is the main
  entry point for an agent. It takes the user's agent implementation module
  (which must adhere to the AcpEx.Agent behaviour) and some initial arguments.
  Internally, it starts the AcpEx.Application supervision tree, including the
  Stdio transport listener, and prepares to handle incoming client connections.
- AcpEx.start\_client(client\_module, initial\_args, agent\_command): This is
  the corresponding entry point for a client. It takes the user's client
  implementation module (@behaviour AcpEx.Client), initial arguments, and the
  command needed to spawn the agent as a subprocess (e.g., {"gemini",
  \["acp"\]}). The function will spawn the external agent process, start the
  client-side supervision tree, and establish the stdio communication pipes.

These two functions will constitute the primary public-facing API, providing a
simple and clear starting point for any developer looking to integrate ACP into
their Elixir application.

## **Section 5: Building Reference Implementations**

To validate the architectural design and provide a clear, practical guide for
users, the library's development should include the creation of two reference
implementations: a simple agent and a corresponding client. These examples serve
as executable documentation, demonstrating the core workflows and API usage
patterns for both sides of the protocol.

### **5.1. The Agent: A Simple "Code Refactor" Agent**

This reference implementation will demonstrate how to build a basic AI agent
using the acp\_ex library. The agent will be capable of performing a trivial
"refactoring" task, such as reversing the content of a function provided in a
prompt. The implementation process would be as follows:

1. **Project Setup:** A new Mix project is created, e.g., $ mix new
   refactor\_agent \--sup, and acp\_ex is added as a dependency in mix.exs.
2. **Implement the AcpEx.Agent Behaviour:** A new module, RefactorAgent.Impl, is
   created. This module will be declared with @behaviour AcpEx.Agent.
3. **Implement Callbacks:**
   - handle\_initialize/2: This callback will be implemented to return a simple
     InitializeResponse struct, declaring the agent's name and basic
     capabilities.
   - handle\_new\_session/2: This callback will simply return an empty map or a
     basic struct to serve as the initial session state.
   - handle\_prompt/3: This is the core logic. The function will: a. Receive the
     PromptRequest struct. It will pattern match on the content blocks to find a
     text block containing the code to be refactored. b. Use the client\_proxy
     argument to send a session/update notification with a "thought" message,
     e.g., AcpEx.ClientProxy.send\_update(proxy, %Update{thought: "Okay, I will
     refactor this code by reversing it."}). This demonstrates the streaming
     notification feature. c. Perform the simple string manipulation on the
     code. d. Construct a PromptResponse struct containing a diff or a patch
     that represents the change. The response will have a stop\_reason of :done.
     e. Return the response, which the acp\_ex library will then send back to
     the client, concluding the prompt turn.
4. **Application Entry Point:** The main application module will be modified to
   call AcpEx.start\_agent(RefactorAgent.Impl,) in its start/2 function, which
   starts the agent and makes it listen on stdio.

This simple agent provides a complete, end-to-end example of the agent-side
workflow, from initialization to handling a prompt and streaming updates.

### **5.2. The Client: A Command-Line Interaction Tool**

To interact with and test the RefactorAgent, a corresponding command-line client
will be built. This tool will demonstrate how to use the client-side API of
acp\_ex to spawn an agent, send prompts, and receive responses. The
implementation process for the client would be:

1. **Project Setup:** A new Mix project is created, e.g., $ mix new acp\_cli.
   acp\_ex is added as a dependency.
2. **Implement the AcpEx.Client Behaviour:** A module, AcpCli.Impl, is created
   with @behaviour AcpEx.Client.
3. **Implement Callbacks:**
   - handle\_update/2: This callback will be implemented to handle incoming
     session/update notifications from the agent. It will simply print the
     content of the notification (e.g., thoughts, message chunks) to the
     console, prefixed with \`\`. This demonstrates how a client can receive and
     display real-time progress from the agent.
   - Other callbacks like handle\_request\_permission/3 can be implemented with
     stub responses, e.g., printing a message and automatically denying the
     request.
4. **Main Interaction Loop:** A main function will be created to drive the
   client. This function will: a. Call AcpEx.start\_client(AcpCli.Impl,,
   {"path/to/refactor\_agent/run\_script",}). This spawns the agent from the
   previous section as a subprocess and starts the client-side OTP supervision
   tree. The function returns a proxy object for communicating with the agent.
   b. Enter a loop that reads a line of input from the user's terminal
   (IO.gets/1). c. Package the user's input into a PromptRequest struct. d. Use
   the agent proxy returned by start\_client to send the prompt to the agent,
   e.g., AcpEx.AgentProxy.send\_prompt(proxy, prompt\_request). e. The final
   response from the agent will be delivered asynchronously. The client can
   either be designed to wait for it or simply rely on the handle\_update
   callback to print all incoming messages.

This command-line client validates the entire communication loop from the other
side, demonstrating how to spawn and interact with an ACP agent using the
library. Together, these two reference implementations provide a powerful
learning tool and a solid foundation for more complex projects.

## **Section 6: Path to Production: Testing, Documentation, and Publishing**

Creating a high-quality, community-trusted open-source library involves more
than just writing functional code. A rigorous approach to testing, a commitment
to comprehensive documentation, and a clear strategy for publishing and
community engagement are essential for long-term success and adoption. This
section outlines the non-functional requirements for taking acp\_ex from a
prototype to a production-ready package.

### **6.1. A Comprehensive Testing Strategy**

A robust testing suite is non-negotiable for a library that handles complex,
stateful, and bidirectional communication. The testing strategy for acp\_ex
should be multi-layered to ensure correctness at every level of the stack.

- **Unit Tests:** These tests will focus on individual components in isolation.
  - **Schema Tests:** For every Elixir struct defined in the AcpEx.Schema
    namespace, there will be a corresponding unit test. These tests will verify
    that Jason.encode/1 correctly serializes the struct into a JSON string with
    camelCase keys and that Jason.decode/1 correctly deserializes a valid JSON
    string back into the struct. This ensures protocol compliance at the data
    structure level.
  - **Logic Tests:** The internal logic of the Connection.GenServer and
    Session.GenServer modules will be tested directly using the GenServer test
    API. This allows for testing state transitions and message handling logic
    without involving the transport layer.
- **Integration Tests:** These tests will validate the interaction between
  different components of the library. A key integration test will involve
  creating a test that spawns a mock agent process and a mock client process
  within the same test suite. These processes will not communicate over actual
  stdio but through a simulated channel (e.g., using Elixir's message passing).
  This test will verify the entire JSON-RPC message flow, from the client
  sending an initialize request to the agent handling a prompt and streaming
  back update notifications.
- **Property-Based Testing:** For the AcpEx.Transport.Stdio module, which is
  responsible for parsing raw input, property-based testing is an ideal
  approach. Using a library like StreamData, tests can be written to generate a
  vast number of valid and malformed JSON-RPC messages. This will test the
  parser's robustness against edge cases, incomplete messages, and invalid JSON,
  ensuring that the transport layer is resilient and does not crash on
  unexpected input.

### **6.2. Documentation as a First-Class Citizen**

The Elixir community places a high value on excellent documentation, and acp\_ex
must adhere to this standard to gain adoption. Documentation should be treated
as an integral part of the development process, not an afterthought.

- **Inline Documentation:** Every public module and function must be documented
  using @moduledoc and @doc respectively. Documentation strings should be clear,
  concise, and include examples where appropriate.
- **Typespecs:** All public functions must have @spec definitions. Typespecs
  provide static analysis benefits through tools like Dialyzer and serve as a
  precise form of documentation for function signatures.
- **Doctests:** Examples within the documentation should be written as doctests.
  This ensures that the examples are always correct and up-to-date, as they are
  executed as part of the standard test suite.
- **Generated Documentation:** The project will be configured to use ExDoc to
  generate a high-quality HTML documentation website. This site will be
  automatically published to HexDocs upon publishing the package.
- **Guides and Tutorials:** The ExDoc configuration will include "extra pages"
  to provide long-form content beyond the API reference. These pages should
  include:
  - A "Getting Started" guide that walks a new user through adding acp\_ex to
    their project.
  - Detailed tutorials based on the reference implementations from Section 5,
    showing how to build both an agent and a client step-by-step.
  - An "Architecture" page that explains the OTP design, the supervision tree,
    and the role of each major component, empowering advanced users to
    understand the library's internals.

### **6.3. Publishing and Community Engagement**

Once the library is stable and well-documented, it should be published to the
Hex package manager to make it accessible to the Elixir community.

- **Publishing Checklist:** The mix.exs file must be correctly configured with
  metadata, including the package name, version, description, license (e.g.,
  Apache 2.0 or MIT, common in the Elixir ecosystem ), and links to the GitHub
  repository and documentation.
- **Community Building:** To foster a healthy community around the library, the
  project should adopt best practices from successful open-source projects. This
  includes creating a CONTRIBUTING.md file with clear guidelines for
  contributions. Furthermore, leveraging the GitHub Discussions feature, as seen
  in the main agent-client-protocol repository, can provide a valuable forum for
  questions, suggestions, and general conversation, lowering the barrier for
  community involvement.

## **Section 7: Strategic Recommendations and Future Roadmap**

This final section synthesizes the key architectural decisions presented in this
report and outlines a potential roadmap for the future development and evolution
of the acp\_ex library. These recommendations are designed to ensure the library
is not only a successful implementation of the current protocol but also a
flexible foundation for future innovation in Elixir-based AI tooling.

### **7.1. Summary of Key Architectural Decisions**

The architecture proposed in this blueprint is the result of a series of
strategic decisions designed to create a robust, idiomatic, and maintainable
library. The most critical of these decisions are:

1. **An OTP-Centric Foundation:** The choice to model the entire system using
   OTP behaviours (GenServer, Supervisor, Application) is the central
   architectural pillar. This approach directly addresses the protocol's
   requirements for state management, concurrency, and fault tolerance,
   leveraging the core strengths of the Elixir platform to produce a resilient
   and scalable implementation.
2. **A Symmetric Behaviour-Based API:** Adopting the symmetric API pattern from
   the Rust reference implementation, realized through the AcpEx.Agent and
   AcpEx.Client behaviours, provides a powerful and intuitive contract for
   developers. This design elegantly handles the protocol's bidirectional nature
   and offers a clean separation between the library's internal workings and the
   user's application logic.
3. **A Layered, Decoupled Design:** The architecture intentionally separates
   concerns into distinct layers. The Schema modules handle data structure
   definitions, the Transport module manages low-level I/O, and the Protocol
   modules contain the core stateful logic. This decoupling simplifies each
   component and makes the overall system easier to test, maintain, and extend.

### **7.2. Future Roadmap and Potential Extensions**

With a solid foundation in place, the acp\_ex library can evolve to support a
wider range of use cases and integrations. The following are potential avenues
for future development:

- **Alternative Transports:** The explicit separation of the transport layer
  from the protocol logic means that the library is not intrinsically tied to
  stdio. A future version could introduce alternative transport modules. A prime
  candidate would be a **WebSocket transport** (AcpEx.Transport.WebSocket). This
  would enable web-based IDEs or applications (e.g., a Phoenix LiveView-based
  editor) to connect to acp\_ex agents running on a server, significantly
  broadening the library's applicability beyond local subprocesses.
- **mcp\_ex Integration:** As established, a useful ACP agent will almost
  certainly need to be an MCP client. The logical next step for the ecosystem is
  the development of a companion **mcp\_ex library** for building MCP servers
  and clients in Elixir. The acp\_ex library's schema modules for shared data
  types (like tool calls and resource links) should be designed from the outset
  to be easily extracted into a shared dependency that both libraries can use,
  ensuring seamless and correct integration between them.
- **Phoenix Framework Integration:** Building on the concept of a WebSocket
  transport, a dedicated **acp\_ex\_phoenix** integration library could be
  created. This library could provide helpers, such as a Phoenix Channel
  implementation, that make it trivial to host an acp\_ex agent within a
  standard Phoenix web application. This would unlock powerful scenarios, such
  as building collaborative, multi-user, AI-powered tools directly on the web
  using the Phoenix framework.

### **7.3. Concluding Remarks**

The Agent Client Protocol represents a pivotal moment in the evolution of
developer tooling, promising a future of interoperable, intelligent, and
customizable coding environments. The acp\_ex library, as architected in this
report, is designed to be more than a simple protocol implementation. It is a
strategic asset that will empower the Elixir community to be an active and
innovative participant in this future. By embracing the strengths of OTP and
providing an idiomatic, developer-friendly API, acp\_ex can serve as the
foundation for a new generation of AI-powered development tools, assistants, and
workflows, ensuring that Elixir remains a premier platform for building the next
wave of software applications.

#### **Works cited**

1\. Agent Client Protocol: Introduction, https://agentclientprotocol.com/ 2\.
Agent Client Protocol: The LSP for AI Coding Agents \- PromptLayer Blog,
https://blog.promptlayer.com/agent-client-protocol-the-lsp-for-ai-coding-agents/
3\. Agent Client Protocol: Making Agentic Editing Portable | Joshua Berkowitz,
https://joshuaberkowitz.us/blog/github-repos-8/agent-client-protocol-making-agentic-editing-portable-907
4\. Overview \- Agent Client Protocol,
https://agentclientprotocol.com/protocol/overview 5\. What is Agent
Communication Protocol (ACP)? \- IBM,
https://www.ibm.com/think/topics/agent-communication-protocol 6\. i-am-bee/acp:
Open protocol for communication between AI agents, applications, and humans. \-
GitHub, https://github.com/i-am-bee/acp 7\. Agent Communication Protocol:
Welcome, https://agentcommunicationprotocol.dev/ 8\. Introducing the Model
Context Protocol \- Anthropic,
https://www.anthropic.com/news/model-context-protocol 9\. Specification \- A2A
Protocol, https://a2a-protocol.org/dev/specification/ 10\. Agent2Agent Protocol
In Super Detail \+ Full Example(Server\&Client) With OpenAI Agent As
Coordinator(TS) | by Itsuki,
https://javascript.plainenglish.io/agent2agent-protocol-in-super-detail-full-example-server-client-with-openai-agent-as-7734584e4e7b
11\. AG-UI: the Agent-User Interaction Protocol. Bring Agents into Frontend
Applications. \- GitHub, https://github.com/ag-ui-protocol/ag-ui 12\. Schema \-
Agent Client Protocol, https://agentclientprotocol.com/protocol/schema 13\.
Exploring Elixir's OTP Behaviors: A Comprehensive Guide \- CloudDevs,
https://clouddevs.com/elixir/otp-behaviors/ 14\. A Brief Guide to OTP in Elixir
\- Hacker News, https://news.ycombinator.com/item?id=24637121 15\. Library
guidelines — Elixir v1.20.0-dev \- HexDocs,
https://hexdocs.pm/elixir/main/library-guidelines.html 16\. Library Guidelines —
Elixir v1.12.3 \- HexDocs,
https://hexdocs.pm/elixir/1.12.3/library-guidelines.html 17\. Parse and Generate
JSON with Elixir \- MojoAuth,
https://mojoauth.com/parse-and-generate-formats/parse-and-generate-json-with-elixir
18\. Packages \- Hex.pm, https://hex.pm/packages?letter=J 19\.
agent-client-protocol \- crates.io: Rust Package Registry,
https://crates.io/crates/agent-client-protocol 20\.
zed-industries/agent-client-protocol \- GitHub,
https://github.com/zed-industries/agent-client-protocol 21\.
agent\_client\_protocol \- Rust \- Docs.rs,
https://docs.rs/agent-client-protocol 22\. Discussions \- zed-industries
agent-client-protocol \- GitHub,
https://github.com/zed-industries/agent-client-protocol/discussions

