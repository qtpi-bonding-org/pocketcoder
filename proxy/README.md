# PocketCoder Proxy
<!-- cargo-rdme start -->

## Sentinel Proxy
Rust-based bridge that hardens execution calls and provides MCP access.

This sentinel acts as the "Muscle" of the PocketCoder architecture,
ensuring that tools are executed within a secure sandbox environment.

### Core Components

- **Execution Driver**: Manages tmux sessions and command execution in the sandbox.
- **MCP Proxy**: Bridges WebSocket-based Model Context Protocol requests.
- **Shell Bridge**: Implements the `pocketcoder shell` command-line interface.

### Architecture

The proxy runs as a high-performance Rust service that exposes an SSE and WebSocket API.
It translates high-level AI intents into low-level sandbox commands while maintaining
isolation and security.

<!-- cargo-rdme end -->
