# Architectural Refinement: The Sovereign Proxy (MCP Consolidation)

## 🎯 Objective
Simplify the PocketCoder architecture by removing redundant proxy layers and slimming down the Reasoning Engine (Brain) to achieve "Humble Minimalism."

## 🏛️ The Current (Redundant) Flow
Currently, the system uses a "Proxy on a Proxy" model:
1. **Brain (OpenCode)** talks via MCP (stdio) to a **Python Subprocess**.
2. **Python Subprocess** (in the Brain container) makes REST calls to the **CAO API** in the Sandbox.
3. **Rust Proxy** sits in the middle but is bypassed for delegation.
4. Result: `Dockerfile.opencode` is "fat" (Node + Python + CAO Source).

## 🚀 The Simplified "Sovereign Proxy" Flow
We will consolidate all tool-handling into the Rust Proxy, turning it into the single gateway for both Brains and Workers.

### 1. The Proxy (Muscle - Rust)
- **Role**: Becomes a first-class MCP Server (providing tools via SSE).
- **Mocking**: Implements the tool definitions previously found in `cao-mcp-server`:
    - `handoff(agent_profile, message, working_directory)`
    - `assign(agent_profile, message, working_directory)`
    - `send_message(receiver_id, message)`
- **Implementation**: These tools are now literal proxies that make HTTP REST calls directly to the Sandbox CAO API (port 9889).
- **Outcome**: The Proxy is the only component that needs to know how to speak both MCP and REST.

### 2. The Brain (Reasoning - Alpine/Bun)
- **Role**: A pure, execution-less reasoning unit.
- **Base image**: Swapped from `node:lts-slim` to `oven/bun:alpine`.
- **Cleanup**: Remove `python3`, `uv`, and the `sandbox/cao` source code from the container.
- **Connection**: Connects to the Proxy via MCP-over-SSE (`http://proxy:3001/mcp`).

### 3. The Sandbox (Execution - Python)
- **Role**: A "Dumb Shell" that exposes tmux via REST.
- **Cleanup**: Delete the `src/cli_agent_orchestrator/mcp_server/` directory entirely.
- **Isolation**: No longer needs to provide its own MCP server; it just listens for REST commands from the Proxy.

## 📈 Benefits
- **Sovereignty**: The Proxy becomes a centralized "Audit Point" for all cross-agent tool calls.
- **Minimalism**: Drastic reduction in Docker image sizes and dependency complexity.
- **Observability**: One central point (the Proxy) logs all tool interactions between agents.

## 🛠️ Implementation Steps
1. **Mock tools in Proxy**: Update `proxy/src/main.rs` to serve MCP tools that call the CAO REST API.
2. **Delete CAO MCP**: Remove the Python MCP code from the `sandbox/cao` directory.
3. **Slim the Brain**: Update `Dockerfile.opencode` to use `bun:alpine` and remove Python/CAO dependencies.
4. **Update Config**: Point `opencode.json` to the Proxy's new MCP SSE endpoint.
