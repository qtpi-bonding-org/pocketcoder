---
title: Proxy Reference
head: []
---

# Crate `pocketcoder_proxy`

**Version:** 0.1.0

# Sentinel Proxy
Rust-based bridge that hardens execution calls and provides MCP access.

This sentinel acts as the "Muscle" of the PocketCoder architecture,
ensuring that tools are executed within a secure sandbox environment.

## Core Components

- **Execution Driver**: Manages tmux sessions and command execution in the sandbox.
- **MCP Proxy**: Bridges WebSocket-based Model Context Protocol requests.
- **Shell Bridge**: Implements the `pocketcoder shell` command-line interface.

## Architecture

The proxy runs as a high-performance Rust service that exposes an SSE and WebSocket API.
It translates high-level AI intents into low-level sandbox commands while maintaining
isolation and security.

## Contents

- [Modules](#modules)
  - [`driver`](#driver)
  - [`shell`](#shell)
- [Types](#types)
  - [`AppState`](#appstate)
  - [`Cli`](#cli)
  - [`McpQuery`](#mcpquery)
  - [`Commands`](#commands)
  - [`SessionMap`](#sessionmap)
- [Functions](#functions)
  - [`exec_handler`](#exec-handler)
  - [`health_handler`](#health-handler)
  - [`main`](#main)
  - [`sse_handler`](#sse-handler)

## Quick Reference

| Item | Kind | Description |
|------|------|-------------|
| [`driver`](#driver) | mod | # Execution Driver This module manages the lifecycle of the sandbox execution environment via tmux socket interaction. |
| [`shell`](#shell) | mod | # Shell Bridge This module provides the client-side logic for the `pocketcoder shell` command, which routes commands from the reasoning engine to the persistent proxy. |
| [`AppState`](#appstate) | struct |  |
| [`Cli`](#cli) | struct |  |
| [`McpQuery`](#mcpquery) | struct | Query parameters for established sessions. |
| [`Commands`](#commands) | enum |  |
| [`exec_handler`](#exec-handler) | fn |  |
| [`health_handler`](#health-handler) | fn |  |
| [`main`](#main) | fn |  |
| [`sse_handler`](#sse-handler) | fn |  |
| [`SessionMap`](#sessionmap) | type |  |

## Modules

- [`driver`](driver/index.md#driver) — # Execution Driver
- [`shell`](shell/index.md#shell) — # Shell Bridge


---

## Types

### `AppState`

```rust
struct AppState {
    pub sessions: std::sync::Arc<parking_lot::RwLock<std::collections::HashMap<String, mpsc::Sender<serde_json::Value>>>>,
    pub driver: std::sync::Arc<crate::driver::PocketCoderDriver>,
}
```

#### Trait Implementations

##### `impl<A, B> HttpServerConnExec<A, B> for AppState`

##### `impl Instrument for AppState`

##### `impl<V> VZip<V> for AppState`

- <span id="appstate-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for AppState`

### `Cli`

```rust
struct Cli {
    command: Commands,
}
```

#### Trait Implementations

##### `impl Args for Cli`

- <span id="cli-args-group-id"></span>`fn group_id() -> Option<clap::Id>`

- <span id="cli-args-augment-args"></span>`fn augment_args<'b>(__clap_app: clap::Command) -> clap::Command`

- <span id="cli-args-augment-args-for-update"></span>`fn augment_args_for_update<'b>(__clap_app: clap::Command) -> clap::Command`

##### `impl CommandFactory for Cli`

- <span id="cli-commandfactory-command"></span>`fn command<'b>() -> clap::Command`

- <span id="cli-commandfactory-command-for-update"></span>`fn command_for_update<'b>() -> clap::Command`

##### `impl FromArgMatches for Cli`

- <span id="cli-fromargmatches-from-arg-matches"></span>`fn from_arg_matches(__clap_arg_matches: &clap::ArgMatches) -> ::std::result::Result<Self, clap::Error>`

- <span id="cli-fromargmatches-from-arg-matches-mut"></span>`fn from_arg_matches_mut(__clap_arg_matches: &mut clap::ArgMatches) -> ::std::result::Result<Self, clap::Error>`

- <span id="cli-fromargmatches-update-from-arg-matches"></span>`fn update_from_arg_matches(&mut self, __clap_arg_matches: &clap::ArgMatches) -> ::std::result::Result<(), clap::Error>`

- <span id="cli-fromargmatches-update-from-arg-matches-mut"></span>`fn update_from_arg_matches_mut(&mut self, __clap_arg_matches: &mut clap::ArgMatches) -> ::std::result::Result<(), clap::Error>`

##### `impl<A, B> HttpServerConnExec<A, B> for Cli`

##### `impl Instrument for Cli`

##### `impl Parser for Cli`

##### `impl<V> VZip<V> for Cli`

- <span id="cli-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for Cli`

### `McpQuery`

```rust
struct McpQuery {
    pub session_id: Option<String>,
}
```

Query parameters for established sessions.

#### Fields

- **`session_id`**: `Option<String>`

  Optional session ID to resume or identify the connection

#### Trait Implementations

##### `impl Deserialize<'de> for McpQuery`

- <span id="mcpquery-deserialize"></span>`fn deserialize<__D>(__deserializer: __D) -> _serde::__private228::Result<Self, <__D as >::Error>`

##### `impl DeserializeOwned for McpQuery`

##### `impl<A, B> HttpServerConnExec<A, B> for McpQuery`

##### `impl Instrument for McpQuery`

##### `impl<V> VZip<V> for McpQuery`

- <span id="mcpquery-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for McpQuery`

### `Commands`

```rust
enum Commands {
    Server {
        port: String,
    },
    Shell {
        command: Option<String>,
        args: Vec<String>,
    },
}
```

#### Variants

- **`Server`**

  Start the proxy server (MCP Relay + Execution Bridge)

- **`Shell`**

  Run in shell bridge mode (client)

#### Trait Implementations

##### `impl FromArgMatches for Commands`

- <span id="commands-fromargmatches-from-arg-matches"></span>`fn from_arg_matches(__clap_arg_matches: &clap::ArgMatches) -> ::std::result::Result<Self, clap::Error>`

- <span id="commands-fromargmatches-from-arg-matches-mut"></span>`fn from_arg_matches_mut(__clap_arg_matches: &mut clap::ArgMatches) -> ::std::result::Result<Self, clap::Error>`

- <span id="commands-fromargmatches-update-from-arg-matches"></span>`fn update_from_arg_matches(&mut self, __clap_arg_matches: &clap::ArgMatches) -> ::std::result::Result<(), clap::Error>`

- <span id="commands-fromargmatches-update-from-arg-matches-mut"></span>`fn update_from_arg_matches_mut<'b>(&mut self, __clap_arg_matches: &mut clap::ArgMatches) -> ::std::result::Result<(), clap::Error>`

##### `impl<A, B> HttpServerConnExec<A, B> for Commands`

##### `impl Instrument for Commands`

##### `impl Subcommand for Commands`

- <span id="commands-subcommand-augment-subcommands"></span>`fn augment_subcommands<'b>(__clap_app: clap::Command) -> clap::Command`

- <span id="commands-subcommand-augment-subcommands-for-update"></span>`fn augment_subcommands_for_update<'b>(__clap_app: clap::Command) -> clap::Command`

- <span id="commands-subcommand-has-subcommand"></span>`fn has_subcommand(__clap_name: &str) -> bool`

##### `impl<V> VZip<V> for Commands`

- <span id="commands-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for Commands`

### `SessionMap`

```rust
type SessionMap = std::sync::Arc<parking_lot::RwLock<std::collections::HashMap<String, mpsc::Sender<serde_json::Value>>>>;
```


---

## Functions

### `exec_handler`

```rust
async fn exec_handler(__arg0: axum::extract::State<std::sync::Arc<AppState>>, __arg1: axum::Json<crate::driver::ExecRequest>) -> axum::Json<serde_json::Value>
```

**Types:** [`AppState`](#appstate), [`ExecRequest`](driver/index.md#execrequest)

### `health_handler`

```rust
async fn health_handler() -> &'static str
```

### `main`

```rust
fn main() -> anyhow::Result<()>
```

### `sse_handler`

```rust
async fn sse_handler(__arg0: axum::extract::State<std::sync::Arc<AppState>>, __arg1: axum::extract::Query<McpQuery>) -> axum::response::sse::Sse<impl Stream<Item = anyhow::Result<axum::response::sse::Event, std::convert::Infallible>>>
```

**Types:** [`AppState`](#appstate), [`McpQuery`](#mcpquery)



---
# Module: driver

*[pocketcoder_proxy](../index.md) / [driver](index.md)*

---

# Module `driver`

# Execution Driver
This module manages the lifecycle of the sandbox execution environment
via tmux socket interaction.

## Quick Reference

| Item | Kind | Description |
|------|------|-------------|
| [`CommandResult`](#commandresult) | struct | Result of a command execution in the sandbox. |
| [`ExecRequest`](#execrequest) | struct | Request to execute a command. |
| [`ExecResponse`](#execresponse) | struct |  |
| [`PocketCoderDriver`](#pocketcoderdriver) | struct |  |
| [`default_agent_name`](#default-agent-name) | fn |  |

## Types

### `CommandResult`

```rust
struct CommandResult {
    pub output: String,
    pub exit_code: i32,
}
```

Result of a command execution in the sandbox.

#### Fields

- **`output`**: `String`

  Combined stdout and stderr

- **`exit_code`**: `i32`

  Unix exit code

#### Trait Implementations

##### `impl Clone for CommandResult`

- <span id="commandresult-clone"></span>`fn clone(&self) -> CommandResult` — [`CommandResult`](#commandresult)

##### `impl Debug for CommandResult`

- <span id="commandresult-debug-fmt"></span>`fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result`

##### `impl Deserialize<'de> for CommandResult`

- <span id="commandresult-deserialize"></span>`fn deserialize<__D>(__deserializer: __D) -> _serde::__private228::Result<Self, <__D as >::Error>`

##### `impl DeserializeOwned for CommandResult`

##### `impl<T> FromRef<T> for CommandResult`

- <span id="commandresult-fromref-from-ref"></span>`fn from_ref(input: &T) -> T`

##### `impl<A, B> HttpServerConnExec<A, B> for CommandResult`

##### `impl Instrument for CommandResult`

##### `impl Serialize for CommandResult`

- <span id="commandresult-serialize"></span>`fn serialize<__S>(&self, __serializer: __S) -> _serde::__private228::Result<<__S as >::Ok, <__S as >::Error>`

##### `impl<V> VZip<V> for CommandResult`

- <span id="commandresult-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for CommandResult`

### `ExecRequest`

```rust
struct ExecRequest {
    pub cmd: String,
    pub cwd: String,
    pub usage_id: Option<String>,
    pub session_id: Option<String>,
    pub agent_name: String,
}
```

Request to execute a command.

#### Fields

- **`cmd`**: `String`

  Bash command string

- **`cwd`**: `String`

  Working directory relative to workspace root

- **`usage_id`**: `Option<String>`

  Internal audit ID

- **`session_id`**: `Option<String>`

  Session identifier

- **`agent_name`**: `String`

  Agent identity executing the command (e.g., "poco")

#### Trait Implementations

##### `impl Clone for ExecRequest`

- <span id="execrequest-clone"></span>`fn clone(&self) -> ExecRequest` — [`ExecRequest`](#execrequest)

##### `impl Debug for ExecRequest`

- <span id="execrequest-debug-fmt"></span>`fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result`

##### `impl Deserialize<'de> for ExecRequest`

- <span id="execrequest-deserialize"></span>`fn deserialize<__D>(__deserializer: __D) -> _serde::__private228::Result<Self, <__D as >::Error>`

##### `impl DeserializeOwned for ExecRequest`

##### `impl<T> FromRef<T> for ExecRequest`

- <span id="execrequest-fromref-from-ref"></span>`fn from_ref(input: &T) -> T`

##### `impl<A, B> HttpServerConnExec<A, B> for ExecRequest`

##### `impl Instrument for ExecRequest`

##### `impl Serialize for ExecRequest`

- <span id="execrequest-serialize"></span>`fn serialize<__S>(&self, __serializer: __S) -> _serde::__private228::Result<<__S as >::Ok, <__S as >::Error>`

##### `impl<V> VZip<V> for ExecRequest`

- <span id="execrequest-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for ExecRequest`

### `ExecResponse`

```rust
struct ExecResponse {
    pub stdout: Option<String>,
    pub exit_code: Option<i32>,
    pub error: Option<String>,
}
```

#### Trait Implementations

##### `impl Debug for ExecResponse`

- <span id="execresponse-debug-fmt"></span>`fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result`

##### `impl Deserialize<'de> for ExecResponse`

- <span id="execresponse-deserialize"></span>`fn deserialize<__D>(__deserializer: __D) -> _serde::__private228::Result<Self, <__D as >::Error>`

##### `impl DeserializeOwned for ExecResponse`

##### `impl<A, B> HttpServerConnExec<A, B> for ExecResponse`

##### `impl Instrument for ExecResponse`

##### `impl<V> VZip<V> for ExecResponse`

- <span id="execresponse-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for ExecResponse`

### `PocketCoderDriver`

```rust
struct PocketCoderDriver {
    pub socket_path: String,
    pub session_name: String,
}
```

#### Implementations

- <span id="pocketcoderdriver-new"></span>`fn new(socket: &str, session: &str) -> Self`

- <span id="pocketcoderdriver-session-exists"></span>`fn session_exists(&self, session: &str) -> bool`

- <span id="pocketcoderdriver-exec"></span>`async fn exec(&self, cmd: &str, cwd: Option<&str>, agent_name: &str) -> Result<CommandResult>` — [`CommandResult`](#commandresult)

  Execute a command in the target agent's isolated tmux workspace.

  The proxy strictly targets `pocketcoder:[agent_name]:terminal`.

#### Trait Implementations

##### `impl Debug for PocketCoderDriver`

- <span id="pocketcoderdriver-debug-fmt"></span>`fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result`

##### `impl Deserialize<'de> for PocketCoderDriver`

- <span id="pocketcoderdriver-deserialize"></span>`fn deserialize<__D>(__deserializer: __D) -> _serde::__private228::Result<Self, <__D as >::Error>`

##### `impl DeserializeOwned for PocketCoderDriver`

##### `impl<A, B> HttpServerConnExec<A, B> for PocketCoderDriver`

##### `impl Instrument for PocketCoderDriver`

##### `impl<V> VZip<V> for PocketCoderDriver`

- <span id="pocketcoderdriver-vzip"></span>`fn vzip(self) -> V`

##### `impl WithSubscriber for PocketCoderDriver`


---

## Functions

### `default_agent_name`

```rust
fn default_agent_name() -> String
```



---
# Module: shell

*[pocketcoder_proxy](../index.md) / [shell](index.md)*

---

# Module `shell`

# Shell Bridge
This module provides the client-side logic for the `pocketcoder shell` command,
which routes commands from the reasoning engine to the persistent proxy.

## Quick Reference

| Item | Kind | Description |
|------|------|-------------|
| [`run`](#run) | fn |  |

## Functions

### `run`

```rust
fn run(command: Option<String>, args: Vec<String>) -> anyhow::Result<()>
```

