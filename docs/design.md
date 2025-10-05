# **Architecting ACPex: A Comprehensive Blueprint for an Elixir Implementation of the Agent Client Protocol**

## **Section 1: Executive Summary & Protocol Disambiguation**

### **1.1. Vision and Purpose**

This document presents the complete technical architecture and implementation
plan for ACPex, a new library for the Elixir programming language designed to
implement the Agent Client Protocol (ACP). The primary objective is to create a
library that is not only fully compliant with the ACP specification but is also
robust, performant, and idiomatic to the Elixir/OTP ecosystem. This library will
serve as a foundational component for developers wishing to build AI-powered
coding agents or integrate ACP support into Elixir-based development tools, such
as IDEs or custom editors. By adhering to the principles of the BEAM virtual
machine, the library will provide a fault-tolerant and highly concurrent
foundation for agent-client communication.

### **1.2. Critical Insight: The "Two ACPs" Problem and Resolution**

A thorough analysis of the agent protocol landscape reveals a significant
potential for confusion: two distinct and fundamentally different protocols
share the "ACP" acronym. A failure to disambiguate these protocols at the outset
would lead to a project that is architecturally incorrect and fails to meet the
user's requirements. This section provides that critical clarification, which
forms the bedrock of this entire technical plan.

#### **The Challenge: A Tale of Two Protocols**

The term "ACP" is used to refer to both the "Agent Client Protocol" and a
separate "Agent Communication Protocol." These are not interchangeable
standards; they solve different problems with different technological
approaches.

- **The RESTful "Agent Communication Protocol"**: This protocol, associated with
  agentcommunicationprotocol.dev, is a REST-based standard designed for
  **inter-agent communication**.1 Its primary goal is to enable AI agents, often
  running on different servers and built with disparate frameworks (like
  LangChain or CrewAI), to discover and collaborate with one another.1 It
  leverages standard HTTP conventions, supports asynchronous and multimodal
  communication, and is intended to break down the silos between independent AI
  systems, even across organizational boundaries.2 Its focus is on a network of
  collaborative, distributed agents.
- **The JSON-RPC "Agent Client Protocol"**: This protocol, originating from Zed
  Industries and detailed at agentclientprotocol.com, is the subject of this
  report. It is a standard designed for communication between a **code editor
  (the client) and a local AI coding agent (the server)**.5 Heavily inspired by
  the Language Server Protocol (LSP), its purpose is to decouple agents from
  editors, allowing any compliant agent to function within any compliant
  editor.5 The agent runs as a subprocess of the editor, and all communication
  occurs over standard input/output ( stdio) using the JSON-RPC 2.0
  specification.5 Its focus is on the user experience of AI-assisted coding
  within a trusted, local development environment.

#### **Resolution and Strategic Implications**

This report and the proposed ACPex library will **exclusively** implement the
JSON-RPC-based **Agent Client Protocol** from agentclientprotocol.com. This
decision is foundational and non-negotiable, as the architectural requirements
of the two protocols are incompatible. All subsequent sections of this document
refer solely to this editor-to-agent protocol.

The existence of this ambiguity necessitates a proactive documentation strategy
for the ACPex library. A developer discovering the library could easily mistake
its purpose, leading to frustration and incorrect implementation efforts.
Therefore, a core feature of the library will be its clear and prominent
documentation that addresses this issue head-on. The project's README.md file
and the main module's documentation on HexDocs must begin with a dedicated
section titled "Which ACP Is This?" This section will concisely explain the
difference between the two protocols, state that this library implements the Zed
Industries' standard for editor integration, and provide a direct link to
agentclientprotocol.com. This preemptive clarification is a crucial element for
successful user onboarding, correctly positioning the library within the broader
AI agent ecosystem, and ultimately fostering adoption by preventing confusion.

## **Section 2: Deep Dive into the Agent Client Protocol Specification**

A successful implementation requires a deep and nuanced understanding of the
protocol's design, communication patterns, and data structures. This section
deconstructs the Agent Client Protocol to inform the architectural decisions
that follow.

### **2.1. Core Philosophy and Architectural Principles**

The Agent Client Protocol (ACP) was created to solve a growing problem in the
AI-assisted coding space: the tight coupling between AI agents and the code
editors they run in.5 Without a standard, every new agent-editor combination
requires a custom, bespoke integration, leading to significant overhead, limited
compatibility, and developer lock-in.5

The core philosophy of ACP is to establish a common language, thereby decoupling
the development of agents from the development of editors.6 This approach
mirrors the success of the Language Server Protocol (LSP), which standardized
communication between editors and language-specific analysis tools.5 By adhering
to the ACP standard, an agent can be written once and used in any editor that
supports the protocol, and vice-versa.

The protocol operates on a specific set of assumptions and principles:

- **Operating Model**: The agent is designed to run as a sub-process spawned and
  managed by the code editor. This local execution model is fundamental to the
  protocol's design.5
- **Communication Channel**: All communication between the editor (client) and
  the agent (server) occurs over the standard input (stdin) and standard output
  (stdout) streams of the agent's process.5
- **Trusted Environment**: The protocol assumes a trusted relationship. The user
  has explicitly chosen to run the agent, and the editor acts as a gatekeeper,
  mediating the agent's access to local resources like the filesystem or a
  terminal. The agent must request permission for such operations.5
- **Underlying Protocol**: The entire message structure is built upon the
  JSON-RPC 2.0 specification.9 This choice provides a lightweight, text-based,
  and transport-agnostic framework that is well-suited for the task. JSON-RPC's
  support for bidirectional requests and notifications is essential for the
  interactive and streaming nature of ACP.7
- **Data Formats**: To promote consistency and avoid reinventing established
  data structures, ACP reuses JSON representations from the Model Context
  Protocol (MCP) where applicable.5 For user-readable text, the default format
  is Markdown, which offers a balance of rich formatting capabilities without
  requiring the editor to implement a full HTML renderer.5

### **2.2. The Symmetric and Stateful Communication Flow**

The communication model of ACP is not a simple, unidirectional request-response
pattern. It is a fully symmetric, stateful, and bidirectional conversation.12
Both the client (editor) and the agent (server) can initiate requests and send
notifications. This symmetry is crucial for features where the agent needs to
query the editor for information or permission before proceeding.9

A typical interaction lifecycle follows a well-defined sequence 9:

1. **Startup**: The editor launches the agent as a child process.
2. **Handshake**: The client sends an initialize request to the agent. This
   initial message allows both parties to negotiate the protocol version and
   exchange information about their respective capabilities (e.g., whether the
   client supports writing files or creating terminals).9
3. **Authentication**: If the agent's capabilities indicate that authentication
   is required, the client sends an authenticate request.9
4. **Session Management**: A single connection can support multiple concurrent
   "trains of thought," each managed as a distinct session.5 The client
   initiates a new conversation by sending a session/new request.
5. **Prompt Turn**: The core interaction begins when the client sends a
   session/prompt request, containing the user's message and any relevant
   context (like the current file or selection).
6. **Streaming Updates**: A key feature of ACP is its real-time feedback
   mechanism. After receiving a prompt, the agent does not wait until it has a
   final answer. Instead, it immediately begins sending a stream of
   session/update notifications back to the client. These notifications can
   contain message chunks, the agent's internal "thoughts," proposed code
   changes as diffs, or information about tool calls it is making.9 This
   provides a rich, interactive user experience.
7. **Bidirectional Requests**: While processing a prompt, the agent may need to
   interact with the user's environment. It accomplishes this by sending
   requests back to the client. For example, it might send an
   fs/read\_text\_file request to read a file or a terminal/create request to
   run a command. The client receives this request, performs the action
   (potentially after prompting the user for permission), and sends a response
   back to the agent, which then continues its work.9
8. **Cancellation**: The user can interrupt the agent at any time. The client
   signals this by sending a session/cancel notification to the agent.9

This complex lifecycle has profound implications for the architecture of an
Elixir implementation. The protocol's design inherently requires a long-running,
stateful process to manage the connection. The need to handle multiple
concurrent sessions, track in-flight requests in both directions (correlating
responses to their original requests via the JSON-RPC id), and process a
continuous stream of notifications rules out a simple, stateless functional
approach. This is the canonical use case for an OTP GenServer. A GenServer
provides a serialized message inbox, explicit state management, and robust
support for asynchronous communication, making it the ideal primitive upon which
to build the core of the ACPex library.

### **2.3. Data Schema and Core Types**

The protocol specifies a comprehensive set of data structures, which are
formally defined in the official JSON Schema available in the protocol's
repository.8 An Elixir implementation must create corresponding

struct definitions to represent these data types, ensuring type safety and ease
of use.

Key structures that the library must model include:

- **Request/Response Pairs**: InitializeRequest and InitializeResponse,
  PromptRequest and PromptResponse, ReadTextFileRequest and
  ReadTextFileResponse, etc..12
- **Notifications**: SessionUpdate is the most prominent notification, which
  itself contains a variety of update types like agent\_message\_chunk,
  tool\_call, or plan\_update.
- **Content Blocks**: The ContentBlock is a versatile structure used to
  represent different kinds of information, such as plain text, code snippets,
  diffs, and images.12
- **Tool and Planning Structures**: Types like ToolCallContent, ToolCallUpdate,
  and Plan are used to communicate the agent's interaction with external tools
  and its high-level execution plan to the user.12

The protocol also mandates specific data conventions that the library must
enforce, such as the requirement that all file paths must be absolute and that
line numbers are 1-based.9

### **2.4. Table of ACP JSON-RPC Methods and Notifications**

The following table provides a comprehensive reference for all methods and
notifications defined in the Agent Client Protocol, derived from the official
specification documentation.9 This serves as the definitive contract for the
library's implementation.

| Message Name             | Direction      | Type         | Parameters             | Response                | Purpose                                                                      |
| :----------------------- | :------------- | :----------- | :--------------------- | :---------------------- | :--------------------------------------------------------------------------- |
| initialize               | Client → Agent | Request      | InitializeRequest      | InitializeResponse      | Negotiate protocol version and exchange client/agent capabilities.           |
| authenticate             | Client → Agent | Request      | AuthenticateRequest    | AuthenticateResponse    | Authenticate with the agent if required by its advertised capabilities.      |
| session/new              | Client → Agent | Request      | NewSessionRequest      | NewSessionResponse      | Create a new, distinct conversation session.                                 |
| session/load             | Client → Agent | Request      | LoadSessionRequest     | LoadSessionResponse     | Resume a previously existing session (if supported by the agent).            |
| session/prompt           | Client → Agent | Request      | PromptRequest          | PromptResponse          | Send a user prompt and its context to the agent to begin a turn.             |
| session/cancel           | Client → Agent | Notification | CancelNotification     | N/A                     | Instruct the agent to cancel any ongoing processing for a session.           |
| session/update           | Agent → Client | Notification | SessionNotification    | N/A                     | Stream progress updates to the client (e.g., thoughts, diffs, tool calls).   |
| fs/read\_text\_file      | Agent → Client | Request      | ReadTextFileRequest    | ReadTextFileResponse    | Request the client to read the contents of a file from the local filesystem. |
| fs/write\_text\_file     | Agent → Client | Request      | WriteTextFileRequest   | WriteTextFileResponse   | Request the client to write content to a file on the local filesystem.       |
| terminal/create          | Agent → Client | Request      | CreateTerminalRequest  | CreateTerminalResponse  | Request the client to create a new terminal and run a command.               |
| terminal/output          | Agent → Client | Request      | TerminalOutputRequest  | TerminalOutputResponse  | Request the output and exit status of a previously created terminal.         |
| terminal/wait\_for\_exit | Agent → Client | Request      | WaitForExitRequest     | WaitForExitResponse     | Wait for a command in a terminal to complete.                                |
| terminal/kill            | Agent → Client | Request      | KillTerminalRequest    | KillTerminalResponse    | Kill the command running in a terminal without releasing the terminal.       |
| terminal/release         | Agent → Client | Request      | ReleaseTerminalRequest | ReleaseTerminalResponse | Release a terminal and its associated resources.                             |

## **Section 3: Architectural Blueprint for the ACPex Library**

This section outlines the high-level architecture for the ACPex library. The
design prioritizes idiomatic Elixir patterns, robustness through OTP principles,
and a clean, developer-friendly public API, drawing inspiration from the
successful designs of the official Rust and TypeScript reference
implementations.

### **3.1. Core Design Philosophy: Adapting the Rust Model to OTP**

The official ACP libraries for Rust and TypeScript employ a highly effective
symmetric design pattern.12 They provide a central

Connection object that manages the low-level protocol and transport, while
exposing Agent and Client interfaces (or traits in Rust) that the end-user
implements to provide the application-specific logic. This cleanly separates the
concerns of protocol machinery from business logic.

The ACPex library will adapt this proven pattern to the Elixir/OTP paradigm:

- **Rust trait / TypeScript interface → Elixir behaviour**: Elixir's behaviour
  module attribute provides a formal contract for a module's public API. The
  library will define ACPex.Agent and ACPex.Client behaviours, specifying the exact
  callbacks (e.g., handle\_prompt/2) that a user's module must implement. This
  provides compile-time checks and clear documentation for developers building
  agents or clients.
- **Connection Object → GenServer Process**: The stateful, long-running nature
  of an ACP connection maps perfectly to an Elixir GenServer. A dedicated
  GenServer process will encapsulate the connection state, manage the I/O
  transport, and handle the serialization and dispatching of JSON-RPC messages.
  This leverages OTP's battle-tested model for concurrent state management and
  fault tolerance.

This approach yields an architecture that is both familiar to those who have
seen other ACP libraries and perfectly idiomatic for experienced Elixir
developers.

### **3.2. Process and Supervision Strategy**

The cornerstone of the library will be a GenServer module, ACPex.Connection. Each
running instance of this GenServer will represent and manage a single, active
agent-client connection over stdio.

The responsibilities of the ACPex.Connection process are as follows:

1. **Transport Management**: Upon initialization, it will spawn and link to a
   dedicated transport process (or port) responsible for the low-level,
   non-blocking reading from stdin and writing to stdout.
2. **State Management**: It will maintain the complete state of the connection,
   including a reference to the user's handler module, the handler's own
   internal state, information about active sessions, and a map of pending
   request IDs to the calling process's address, which is essential for
   correctly routing responses to asynchronous requests.
3. **Message Processing**: It will act as the central dispatcher. It receives
   raw data from the transport, parses it into JSON-RPC messages, and dispatches
   them internally as GenServer calls (for requests) or casts (for
   notifications).
4. **Logic Delegation**: It will invoke the appropriate callbacks on the
   user-provided behaviour module, passing the parsed parameters and allowing
   the user's code to handle the business logic.

To ensure robustness and align with OTP design principles, the library will
provide a child\_spec/1 function. This allows an ACPex.Connection process to be
easily embedded within a standard Elixir supervision tree.15 If the connection
process crashes due to an unexpected error (e.g., a bug in the user's callback
code or a protocol violation), the supervisor can automatically restart it
according to a defined strategy, providing the fault tolerance expected of
Elixir applications.

### **3.3. Public API Design**

The public-facing API will be designed for simplicity and ease of use, exposing
a minimal surface area to the developer.

The primary entry points for starting a connection will be:

- ACP.start\_agent(agent\_module, agent\_init\_args \\\\): This function will
  start and link an ACPex.Connection GenServer configured to act as an **agent**.
  It takes the name of the user's module, which must implement the ACPex.Agent
  behaviour, and optional initial arguments for that module.
- ACP.start\_client(client\_module, client\_init\_args \\\\): This function will
  start and link an ACPex.Connection GenServer configured to act as a **client**.
  It takes the user's client module, which must implement the ACPex.Client
  behaviour.

The core of the user's interaction with the library will be through implementing
one of two behaviours:

- @behaviour ACPex.Agent: Defines the contract for an agent implementation. It
  will specify callbacks like handle\_initialize/2, handle\_new\_session/2, and
  handle\_prompt/2.
- @behaviour ACPex.Client: Defines the contract for a client implementation, with
  callbacks such as handle\_session\_update/2 and handle\_read\_text\_file/2.

Following Elixir conventions, all public functions that can fail will return
tagged tuples, such as {:ok, pid} on success or {:error, reason} on failure,
providing a predictable and pattern-matchable interface for error handling.17

### **3.4. Error Handling Strategy**

The library will employ a clear and robust error handling strategy that
distinguishes between different classes of errors, as is common practice in
Elixir.17

1. **Expected / Recoverable Errors**: These are errors that are part of the
   normal operational flow, such as an agent being unable to fulfill a prompt or
   a requested file not being found. These will be handled gracefully. Functions
   in the public API will return {:error, reason} tuples. Within the protocol,
   these will be translated into valid JSON-RPC error responses containing an
   appropriate error code and message, as defined by the specification.9
2. **Unexpected / Fatal Errors**: These represent programming errors or
   unrecoverable situations. This category includes malformed JSON, violations
   of the JSON-RPC or ACP specifications, or unexpected crashes within a user's
   behaviour callback. In these cases, the ACPex.Connection GenServer will follow
   the "let it crash" philosophy. It will exit, and the linked supervisor will
   be responsible for handling the failure, typically by logging the error and
   restarting the process.

To facilitate internal error signaling, a custom exception, ACPex.ProtocolError,
will be defined using defexception. This will be used internally to signal
unrecoverable protocol violations that should lead to a process crash.18

## **Section 4: Core Module Implementation Plan**

This section provides a more detailed breakdown of the key modules that will
constitute the ACPex library, describing their responsibilities and internal
structure.

### **4.1. ACPex.Connection (The GenServer Core)**

This module is the heart of the library, orchestrating all communication and
state management.

- **State (t)**: The GenServer's state will be encapsulated in a struct, likely
  defined as: Elixir defstruct transport\_pid: nil, handler\_module: nil,
  handler\_state: nil, pending\_requests: %{}, \# Map of request\_id \=\> from()
  sessions: %{}

- **init/1**: The init/1 callback will receive the user's handler module and
  initial arguments. It will start the ACPex.Transport.Stdio process, link to it,
  and initialize the state with the provided handler information.
- **handle\_info({:data, binary}, state)**: This will be the primary message
  loop for incoming data. It receives a complete message binary from the
  transport process. It will be responsible for decoding the JSON, parsing it
  into a JSON-RPC request or notification, and then dispatching it to the
  appropriate handle\_call or handle\_cast function within the same GenServer.
- **handle\_cast({:notification, method, params}, state)**: This handles
  incoming JSON-RPC notifications (which do not require a response). It will
  look up the appropriate callback on the state.handler\_module (e.g.,
  handle\_session\_update) and invoke it with the params and the current
  state.handler\_state.
- **handle\_call({:request, id, method, params}, from, state)**: This handles
  incoming JSON-RPC requests. It will delegate to the appropriate handler
  callback (e.g., handle\_prompt). Crucially, for requests initiated by the
  _other_ side of the connection (e.g., an agent making a request to a client),
  it will store the from address in the pending\_requests map, keyed by the
  request id. When the handler's callback returns a result, the GenServer will
  construct the JSON-RPC response and send it back over the transport.
- **Public API for Handlers**: The ACPex.Connection will also expose a set
  of public functions intended to be called _by the user's handler module_. For
  example, ACPex.Connection.send\_notification(pid, method, params) and
  ACPex.Connection.send\_request(pid, method, params). These functions will send a
  message to the GenServer process, which will then serialize and send the
  message over the transport. send\_request will perform a GenServer.call and
  block until a response with the corresponding id is received.

### **4.2. ACPex.Transport.Stdio (The I/O Layer)**

Directly managing stdin and stdout in a concurrent, non-blocking fashion is a
non-trivial task in Elixir. A naive implementation using IO.read/2 would block
the scheduler thread, severely degrading the performance and responsiveness of
the entire application.

The correct and idiomatic solution is to use an Erlang Port. A port is a special
type of process provided by the Erlang runtime that acts as a bridge to an
external OS process or I/O device. It communicates with the Elixir application
asynchronously via messages, which is ideal for this use case.

The ACPex.Transport.Stdio module will be responsible for:

1. **Spawning and Managing the Port**: It will provide functions to start a port
   connected to the application's standard I/O streams.
2. **Message Framing**: LSP-style protocols, including ACP, do not send raw JSON
   over the wire. They frame each message with headers to allow the receiver to
   identify the boundaries of a complete message. The standard format is:
   Content-Length: \<number\>\\r\\n \\r\\n \<json\_payload\>

   The transport module will be responsible for parsing these headers from the
   incoming byte stream to buffer and emit only complete JSON message binaries.
   When sending data, it will prepend the appropriate Content-Length header to
   the JSON payload before writing it to stdout.

### **4.3. ACPex.Schema (Data Structures)**

This module will serve as a namespace for all the Elixir struct definitions that
map directly to the data types specified in the ACP JSON Schema.13 This provides
a single source of truth for the data shapes used throughout the library and in
the user's code.

- **Structure**: It will contain nested modules for each major type, for
  example: ACPex.Schema.InitializeRequest, ACPex.Schema.ContentBlock,
  ACPex.Schema.Diff.
- **Best Practices**: Each struct will:
  - Use @enforce\_keys for fields that are mandatory according to the protocol
    specification.
  - Include a t() typespec for use with Dialyzer.
  - Have @doc strings explaining the purpose of the struct and its fields.

These structs will be the primary data carriers, passed as arguments to
behaviour callbacks and used to construct outgoing messages.

### **4.4. The Behaviours: ACPex.Agent and ACPex.Client**

These two modules will contain no concrete implementation. Their sole purpose is
to formally define the contracts that user modules must adhere to when creating
an agent or a client. They will consist entirely of @callback and @doc
attributes.

- **@behaviour ACPex.Agent**:
  - @callback handle\_initialize(params :: ACPex.Schema.InitializeRequest.t(),
    state :: term()) :: {:ok, ACPex.Schema.InitializeResponse.t(), new\_state ::
    term()}
  - @callback handle\_new\_session(params :: ACPex.Schema.NewSessionRequest.t(),
    state :: term()) :: {:ok, ACPex.Schema.NewSessionResponse.t(), new\_state ::
    term()}
  - @callback handle\_prompt(params :: ACPex.Schema.PromptRequest.t(), state ::
    term()) :: {:ok, ACPex.Schema.PromptResponse.t(), new\_state :: term()}
  - ...and so on for every other client-to-agent message.
- **@behaviour ACPex.Client**:
  - @callback handle\_session\_update(params ::
    ACPex.Schema.SessionNotification.t(), state :: term()) :: {:noreply,
    new\_state :: term()}
  - @callback handle\_read\_text\_file(params ::
    ACPex.Schema.ReadTextFileRequest.t(), state :: term()) :: {:ok,
    ACPex.Schema.ReadTextFileResponse.t(), new\_state :: term()}
  - ...and so on for every other agent-to-client message.

This explicit contract enables static analysis tools to verify the correctness
of a user's implementation and provides clear, auto-generated documentation.

## **Section 5: Dependencies and Tooling**

A well-designed Elixir library is not only defined by its own code but also by
its judicious choice of dependencies and its integration with the standard
ecosystem tooling.

### **5.1. Dependency Selection and Rationale**

The ACPex library will be intentionally lean, including only essential
dependencies to minimize its footprint and avoid potential conflicts for
downstream users.

- **JSON Codec**: The choice of a JSON library is critical for a protocol that
  is entirely JSON-based. The modern standard in the Elixir community is jason.
  It is demonstrably faster, more memory-efficient, and stricter in its
  adherence to the JSON specification (RFC 8259\) than its predecessor,
  poison.19 For a high-performance protocol library, jason is the unequivocal
  choice.
- **JSON-RPC Implementation**: While several JSON-RPC libraries exist for
  Elixir, such as jsonrpc2 21, they are typically designed for common transports
  like HTTP or raw TCP sockets. These libraries often bring in their own
  dependencies for transport and connection management (e.g., cowboy, ranch).22
  Given that ACP has a specific and unconventional transport layer ( stdio),
  integrating a third-party JSON-RPC library would likely introduce more
  complexity than it solves. The core logic of JSON-RPC 2.0 is relatively
  simple: constructing and parsing messages with jsonrpc, method, params, and id
  fields, and correlating responses to requests via the id.10 This logic can be
  implemented cleanly and efficiently directly within the ACPex.Connection
  GenServer. This approach provides maximum control over the transport layer,
  avoids unnecessary dependencies, and keeps the library focused and
  self-contained.

### **5.2. Table of Core Dependency Evaluation**

The following table summarizes the decision-making process for the library's
core dependencies.

| Component          | Option                  | Pros                                                                                                             | Cons                                                                     | Recommendation & Justification                                                                                                                                                                                     |                                                                                      |                                                                                                                                                                                               |
| :----------------- | :---------------------- | :--------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **JSON Parsing**   | jason                   | \- High performance (speed and memory) 20                                                                        | \- Strict RFC 8259 compliance 19                                         | \- Modern community standard                                                                                                                                                                                       | \- Lacks some convenience features of poison (e.g., decoding directly to structs) 19 | **Adopt jason**. Performance and strictness are paramount for a protocol library. The lack of convenience features is irrelevant as we will be manually decoding into our own schema structs. |
| **JSON Parsing**   | poison                  | \- Mature and widely used in older projects \- More lenient parsing                                              | \- Slower and less memory-efficient than jason 20                        | \- Less strict spec compliance 19                                                                                                                                                                                  | \- Largely superseded by jason in new projects                                       | **Reject poison**. The performance benefits of jason are too significant to ignore for a communication-heavy library.                                                                         |
| **JSON-RPC Logic** | jsonrpc2                | \- Provides a full JSON-RPC 2.0 implementation \- Handles batching and other spec features                       | \- Designed for standard transports (HTTP/TCP), not stdio 22             | \- Introduces additional dependencies (ranch, shackle, etc.) 22                                                                                                                                                    | \- Potential for impedance mismatch with our custom transport                        | **Reject jsonrpc2**. The overhead and potential complexity of adapting it to our specific stdio transport outweigh the benefits.                                                              |
| **JSON-RPC Logic** | In-house Implementation | \- Zero external dependencies \- Full control over transport integration \- Tailored specifically to ACP's needs | \- Requires implementing the request/response correlation logic manually | **Adopt In-house Implementation**. The core JSON-RPC logic is simple enough to implement within the ACPex.Connection GenServer, avoiding dependency bloat and ensuring a perfect fit with the stdio transport layer. |                                                                                      |                                                                                                                                                                                               |

### **5.3. Project Tooling and Best Practices**

The library will be developed and maintained using the standard suite of tools
common to all modern Elixir projects.

- **Project Structure**: The project will be initialized using mix new ACPex
  \--sup. This command scaffolds a standard OTP application structure, including
  a lib directory, a test directory, a mix.exs file, and a placeholder
  application module with a supervision tree.15
- **Code Formatting**: Code style will be strictly enforced using the built-in
  mix format task. This ensures a consistent and readable codebase, which is a
  non-negotiable standard within the Elixir community.15
- **Static Analysis**: To maintain high code quality and catch potential bugs
  before runtime, the project will use:
  - credo for enforcing style guidelines and identifying code smells.
  - dialyzer (via the dialyxir Mix task) for static type analysis and
    identifying specification mismatches.
- **Dependency Management**: All dependencies will be managed in the mix.exs
  file. Dependencies required only for development or testing (such as ex\_doc
  or dialyxir) will be specified with the :only option to ensure they are not
  included when a user adds ACPex to their own project.15

## **Section 6: Testing, Documentation, and Publishing Strategy**

A library is only as good as its reliability and its documentation. This section
outlines the strategy for ensuring ACPex is thoroughly tested, excellently
documented, and properly published for the community.

### **6.1. A Multi-Layered Testing Strategy**

A comprehensive testing strategy is essential for a protocol library where
correctness is paramount. The testing approach will be divided into three
layers:

1. **Unit Tests**: Each individual module will have its own set of unit tests.
   For example, the ACPex.Schema structs will be tested to ensure they are created
   correctly, and the internal logic of the ACPex.Connection GenServer for
   managing state (e.g., adding and removing pending requests) will be tested in
   isolation.
2. **Integration Tests**: This is the most critical layer of testing. Testing
   against actual stdio is notoriously difficult and can lead to flaky tests. To
   solve this, the integration tests will use a **mock transport**. A simple
   ACP.Transport.Mock behaviour will be created, with a mock implementation that
   communicates with the test process via standard Elixir messages instead of
   stdio. The tests will then spawn an ACPex.Connection process using this mock
   transport. This allows the test process to simulate being the "other side" of
   the connection, sending messages to the ACPex.Connection process and asserting
   that it receives the expected responses. This approach enables the simulation
   of a full, bidirectional client-agent conversation, verifying the entire
   message flow, serialization, and logic delegation in a fast, reliable, and
   deterministic manner.
3. **Property-Based Testing**: The StreamData library will be used to create
   property-based tests for the message parser in the ACPex.Transport.Stdio
   module. These tests will generate thousands of variations of valid and
   malformed message frames (e.g., with incorrect Content-Length headers,
   missing newlines, or corrupted JSON) to ensure the parser is robust and does
   not crash on unexpected input.

### **6.2. Documentation as a First-Class Citizen**

The Elixir community places a very high value on documentation, treating it as
an integral part of the software itself.15 The

ACPex library will uphold this standard.

- **API Documentation**: Every public module and function will have complete
  @modledoc and @doc attributes, respectively. These will be written clearly and
  will include examples of usage.
- **Doctests**: Key functions, especially those in the public API, will include
  doctests. These serve a dual purpose: they act as tests that are run with the
  main test suite, and they provide living, verified examples directly within
  the documentation.
- **Guides**: The documentation will go beyond a simple API reference. The ExDoc
  configuration in mix.exs will be set up to include "extra pages" written in
  Markdown. These pages will provide high-level guides, including:
  - A "Getting Started" guide.
  - A tutorial on "Creating Your First Agent."
  - A guide on "Integrating with an Editor" (for client-side implementation).
  - The crucial "Which ACP Is This?" page to address the protocol ambiguity.

This comprehensive approach ensures that users have all the resources they need
to understand and successfully use the library.

### **6.3. Release and Publishing Plan**

The library will be released as a public package for the benefit of the Elixir
community.

- **Versioning**: The project will strictly adhere to the Semantic Versioning
  2.0.0 specification. This provides clear expectations for users about breaking
  changes between releases.15
- **License**: The library will be released under the Apache License 2.0. This
  is a permissive and well-regarded open-source license, and it is consistent
  with the license of the Elixir language itself.15
- **Continuous Integration (CI)**: A CI pipeline, likely using GitHub Actions,
  will be configured. This pipeline will run on every commit and pull request,
  automatically executing the full suite of quality checks: mix format
  \--check-formatted, mix credo, mix dialyzer, and mix test. This ensures that
  the main branch is always in a stable and releasable state.
- **Publishing to Hex.pm**: The library will be published to Hex.pm, the
  official package manager for the Erlang ecosystem. The mix.exs file will be
  fully configured with all necessary metadata, including the package
  description, version, license, and links to the GitHub repository and
  documentation. The mix hex.publish command will be used to push new versions
  to the registry. Upon publishing, the documentation will be automatically
  generated by ExDoc and hosted on HexDocs.

## **Section 7: Conclusion**

The architectural plan detailed in this document provides a comprehensive and
robust foundation for the development of the ACPex library. By addressing the
critical initial ambiguity between the two "ACP" protocols and focusing
exclusively on the Zed Industries' standard for editor-agent communication, the
project is set on a clear and correct path.

The proposed architecture leverages the strengths of the Elixir/OTP ecosystem,
using a GenServer to manage the stateful, concurrent, and bidirectional
communication required by the protocol. This design, inspired by the official
reference implementations in Rust and TypeScript but adapted to be idiomatic to
Elixir, cleanly separates the protocol machinery from user-facing application
logic through the use of behaviours. The deliberate choice to implement the
lightweight JSON-RPC logic in-house and rely on the high-performance jason
library for JSON processing will result in a lean, efficient, and
dependency-minimal package.

Combined with a rigorous multi-layered testing strategy, a commitment to
first-class documentation, and adherence to community best practices for tooling
and publishing, this blueprint outlines a clear path to creating a high-quality,
reliable, and valuable library for the Elixir community. The resulting ACPex
library will empower developers to participate fully in the growing ecosystem of
AI-assisted development tools, building the next generation of intelligent
coding agents on the fault-tolerant and concurrent foundation of the BEAM.

#### **Works cited**

1. Agent Communication Protocol: Welcome, accessed October 4, 2025,
   [https://agentcommunicationprotocol.dev/](https://agentcommunicationprotocol.dev/)
2. What is Agent Communication Protocol (ACP)? \- IBM, accessed October 4, 2025,
   [https://www.ibm.com/think/topics/agent-communication-protocol](https://www.ibm.com/think/topics/agent-communication-protocol)
3. The Agent Communication Protocol (ACP) and Interoperable AI Systems \-
   Macronet Services, accessed October 4, 2025,
   [https://macronetservices.com/agent-communication-protocol-acp-ai-interoperability/](https://macronetservices.com/agent-communication-protocol-acp-ai-interoperability/)
4. i-am-bee/acp: Open protocol for communication between AI agents,
   applications, and humans. \- GitHub, accessed October 4, 2025,
   [https://github.com/i-am-bee/acp](https://github.com/i-am-bee/acp)
5. Agent Client Protocol: Introduction, accessed October 4, 2025,
   [https://agentclientprotocol.com/](https://agentclientprotocol.com/)
6. Agent Client Protocol: The LSP for AI Coding Agents \- PromptLayer Blog,
   accessed October 4, 2025,
   [https://blog.promptlayer.com/agent-client-protocol-the-lsp-for-ai-coding-agents/](https://blog.promptlayer.com/agent-client-protocol-the-lsp-for-ai-coding-agents/)
7. Agent Client Protocol: Making Agentic Editing Portable | Joshua Berkowitz,
   accessed October 4, 2025,
   [https://joshuaberkowitz.us/blog/github-repos-8/agent-client-protocol-making-agentic-editing-portable-907](https://joshuaberkowitz.us/blog/github-repos-8/agent-client-protocol-making-agentic-editing-portable-907)
8. zed-industries/agent-client-protocol \- GitHub, accessed October 4, 2025,
   [https://github.com/zed-industries/agent-client-protocol](https://github.com/zed-industries/agent-client-protocol)
9. Overview \- Agent Client Protocol, accessed October 4, 2025,
   [https://agentclientprotocol.com/protocol/overview](https://agentclientprotocol.com/protocol/overview)
10. JSON-RPC 2.0 Specification, accessed October 4, 2025,
    [https://www.jsonrpc.org/specification](https://www.jsonrpc.org/specification)
11. Why MCP Uses JSON-RPC Instead of REST or gRPC \- Glama, accessed October 4,
    2025,
    [https://glama.ai/blog/2025-08-13-why-mcp-uses-json-rpc-instead-of-rest-or-g-rpc](https://glama.ai/blog/2025-08-13-why-mcp-uses-json-rpc-instead-of-rest-or-g-rpc)
12. agent\_client\_protocol \- Rust \- Docs.rs, accessed October 4, 2025,
    [https://docs.rs/agent-client-protocol](https://docs.rs/agent-client-protocol)
13. accessed December 31, 1969,
    [https://github.com/zed-industries/agent-client-protocol/blob/main/schema/schema.json](https://github.com/zed-industries/agent-client-protocol/blob/main/schema/schema.json)
14. TypeScript \- Agent Client Protocol, accessed October 4, 2025,
    [https://agentclientprotocol.com/libraries/typescript](https://agentclientprotocol.com/libraries/typescript)
15. Library guidelines — Elixir v1.18.4 \- HexDocs, accessed October 4, 2025,
    [https://hexdocs.pm/elixir/library-guidelines.html](https://hexdocs.pm/elixir/library-guidelines.html)
16. Library guidelines — Elixir v1.20.0-dev \- HexDocs, accessed October 4,
    2025,
    [https://hexdocs.pm/elixir/main/library-guidelines.html](https://hexdocs.pm/elixir/main/library-guidelines.html)
17. Error Handling \- Elixir School, accessed October 4, 2025,
    [https://elixirschool.com/en/lessons/intermediate/error\_handling](https://elixirschool.com/en/lessons/intermediate/error_handling)
18. Elixir : Basics of errors and error handling constructs | by Arunmuthuram M
    \- Medium, accessed October 4, 2025,
    [https://arunramgt.medium.com/elixir-basics-of-errors-5265cf67f905](https://arunramgt.medium.com/elixir-basics-of-errors-5265cf67f905)
19. jason v1.4.4 \- HexDocs, accessed October 4, 2025,
    [https://hexdocs.pm/jason/readme.html](https://hexdocs.pm/jason/readme.html)
20. michalmuskala/jason: A blazing fast JSON parser and generator in pure
    Elixir. \- GitHub, accessed October 4, 2025,
    [https://github.com/michalmuskala/jason](https://github.com/michalmuskala/jason)
21. jsonrpc2 \- Hex.pm, accessed October 4, 2025,
    [https://hex.pm/packages/jsonrpc2](https://hex.pm/packages/jsonrpc2)
22. fanduel-oss/jsonrpc2-elixir: JSON-RPC 2.0 for Elixir \- GitHub, accessed
    October 4, 2025,
    [https://github.com/fanduel-oss/jsonrpc2-elixir](https://github.com/fanduel-oss/jsonrpc2-elixir)
23. JSONRPC2 v2.0.0 \- HexDocs, accessed October 4, 2025,
    [https://hexdocs.pm/jsonrpc2/JSONRPC2.html](https://hexdocs.pm/jsonrpc2/JSONRPC2.html)
24. christopheradams/elixir\_style\_guide: A community driven style guide for
    Elixir \- GitHub, accessed October 4, 2025,
    [https://github.com/christopheradams/elixir\_style\_guide](https://github.com/christopheradams/elixir_style_guide)
25. Elixir Dependency Security: Mix, Hex, and Understanding the Ecosystem \-
    Paraxial.io, accessed October 4, 2025,
    [https://paraxial.io/blog/hex-security](https://paraxial.io/blog/hex-security)
26. Library Guidelines — Elixir v1.12.3 \- HexDocs, accessed October 4, 2025,
    [https://hexdocs.pm/elixir/1.12.3/library-guidelines.html](https://hexdocs.pm/elixir/1.12.3/library-guidelines.html)

