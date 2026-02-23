# MCP Gateway Implementation Specification (Dynamic Spin-up)

This document defines the verified "Golden Path" for integrating the Docker MCP Gateway into the PocketCoder architecture, based on sandbox testing in Feb 2026.

## 🏗️ The Verified Setup

### 1. Docker Socket Permissions
- **Security Mode**: Read-Only (`:ro`).
- **Discovery**: The Gateway **can** successfully spin up new containers using a read-only Docker socket mount (`/var/run/docker.sock:/var/run/docker.sock:ro`). Docker's `--rm` flag handles cleanup without requiring explicit write access from the Gateway container.

### 2. Catalog Configuration (`docker-mcp.yaml`)
The catalog must use the flat `registry` schema for standard compatibility.
- **Key Detail**: Use **`longLived`** (CamelCase) for the specification flag.
- **Default (Ephemeral)**: `longLived: false` ensures containers die immediately after each tool call result is returned. This is our standard for maximum security and zero resource leaks.
- **Infrastructure Verification**: `longLived: true` is used only for integration testing to allow time for system assertions (polling `docker ps`).

**Example (Standard PocketCoder Server):**
```yaml
name: docker-mcp
displayName: PocketCoder Dynamic Catalog
registry:
  fetch:
    description: "Web content extractor"
    title: "Fetch"
    type: "server"
    image: "mcp/fetch"
    longLived: false # Container disappears immediately after computed result
```

### 3. Gateway Startup Arguments
The gateway service in `docker-compose.yml` must include these flags:
- `--enable-all-servers`: Resolves all servers in the catalog at startup.
- `--verbose`: Critical for debugging configuration reloads.
- `--transport sse`: Required for dynamic session management.

## 🔄 Lifecycle Management

### Session-Bound Ephemerality
- **Trigger**: When subagent connects via SSE, a unique **Session** is created.
- **Activation**: Calling `mcp-add` or invoking a tool from the catalog triggers the spin-up.
- **Persistence**:
    - If `longLived: false`: Container is created per-call and destroyed immediately after the result (`docker run --rm`).
    - If `longLived: true`: Container stays active as long as the SSE connection is maintained.
- **Clean-up**: When the SSE connection is severed, the Gateway terminates all session-associated containers. **No zombie processes are left behind.**

## 🛠️ Tool Interaction (CLI Syntax)
The `docker mcp tools call` CLI **does not** accept JSON for simple arguments. 
- **Correct**: `docker mcp tools call mcp-add name=fetch`
- **Incorrect**: `docker mcp tools call mcp-add '{"name": "fetch"}'`

## 🤖 Subagent Interaction Logic

Subagents (running in the Sandbox) interact with the Gateway over SSE. This logic must be followed exactly for tool discovery and activation.

### 1. The SSE Handshake
A subagent MUST perform a full MCP handshake to keep the session stable:
1.  **Connect**: `GET http://mcp-gateway:8811/sse`
2.  **Get Endpoint**: Extract the POST URL from the `endpoint` SSE event.
3.  **Initialize**: `POST` to the endpoint with `method: initialize`.
4.  **Acknowledge**: `POST` with `method: notifications/initialized`.

### 2. Activating Tools (`mcp-add`)
Even if a server is in the catalog, it is not "active" until the subagent asks for it.
- **Syntax**: Use the `mcp-add` tool with `key=value` arguments.
- **JSON-RPC Call**:
```json
{
  "jsonrpc": "2.0",
  "id": 123,
  "method": "tools/call",
  "params": {
    "name": "mcp-add",
    "arguments": {
        "name": "fetch"
    }
  }
}
```

### 3. Lifecycle (Connected vs. On-Demand)
- **On-Demand**: Subagents do NOT need to keep their SSE connection open between tasks. If a connection is closed and then reopened for a new tool call, the Gateway will simply spin the container back up.
- **Efficiency**: This ensures maximum resource efficiency and prevents "zombie" containers.
- **Trade-offs**: Closing the connection incurs a "cold-start" delay (container creation) on the next request. For high-frequency tool calls, keeping the session open is an optimization, not a requirement.

## 📋 Integration TODOs

| Component | Task |
| :--- | :--- |
| **Test Helpers** | Update `mcp_add_server` in `tests/helpers/mcp.sh` to use `name=$1` syntax. |
| **BATS Tests** | Update Test 14 in `mcp-full-flow.bats` to use a persistent background client for assertions. |
| **CAO (Sandbox)** | Ensure the OpenCode provider uses a persistent session model (similar to `sse_test.py`). |
