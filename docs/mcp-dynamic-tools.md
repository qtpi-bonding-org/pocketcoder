# MCP Dynamic Tool Discovery — Architecture & Gotchas

_Last updated: 2026-02-28. Written after a deep debugging session successfully getting `n8n` tool creation working end-to-end._

---

## Architecture Overview

PocketCoder uses a layered communication model:

```
┌────────────┐   HTTP/SSE    ┌──────────────┐   stdio (JSON-RPC)  ┌───────────────────────┐
│  Sandbox   │ ──────────▶  │  MCP Gateway │ ──────────────────▶ │  n8n (Docker container │
│ (OpenCode) │              │  (port 8811)  │                     │  spun up on demand)    │
└────────────┘              └──────────────┘                      └───────────────────────┘
```

**Hop 1 (Sandbox → Gateway):** Standard HTTP/SSE. OpenCode connects to `http://mcp-gateway:8811/sse`.

**Hop 2 (Gateway → Tool Container):** The `docker-mcp` gateway spawns each tool as a separate Docker container and communicates via **stdio (stdin/stdout)**. There is no HTTP here — the gateway writes JSON-RPC to the container's stdin and reads from its stdout.

---

## How Tools Become Available Dynamically

1. PocketBase maintains a table of **approved MCP servers** (`mcp_servers`).
2. On startup (and on record change), the PocketBase relay (`mcp.go`) regenerates two files in the shared `/mcp_config` volume:
   - `docker-mcp.yaml` — the catalog telling the gateway what servers exist and what secrets they need.
   - `mcp.env` — the actual secret values (API keys, URLs, etc.) in `.env` format.
3. The gateway reads these on startup and after restarts.
4. At **session time**, the agent calls `mcp-add <server-name>` to add a server to the current session. The gateway then spawns the container and registers its tools.
5. The tools (e.g. `n8n_create_workflow`) then appear in the `tools/list` response for that session only.

---

## Critical Lesson: stdio vs. HTTP is the Inner Transport

> **The `MCP_MODE` environment variable you inject into the tool container is NOT about how the sandbox connects to the gateway. It is about how the gateway connects to the tool container's inner process.**

- The sandbox always speaks HTTP/SSE to the gateway.
- The gateway speaks `stdio` to each dynamically-spawned Docker container.
- `MCP_MODE=stdio` tells the tool image to expect JSON-RPC on stdin/stdout instead of running an HTTP server.

---

## Critical Lesson: The ASCII Banner Problem

**The root cause of "Tool not found" failures was this gateway log line:**

```
Can't start n8n: failed to connect: calling "initialize": invalid character 'â' looking for beginning of value
```

The `mcp/n8n` image printed a large ASCII-art "Anonymous Usage Statistics" banner to **stdout** on boot. Since stdout is the stdio channel for JSON-RPC, the gateway tried to parse the banner as JSON and failed, silently skipping the tool registration.

**Fix:** Always inject these two env vars for `mcp/n8n`:
- `N8N_MCP_TELEMETRY_DISABLED=1` — disables the banner
- `MCP_MODE=stdio` — explicitly puts the server in clean stdio mode

**Lesson for other tools:** If a server image prints *anything* to stdout before the JSON-RPC handshake, tools will silently fail to register. Check the gateway `--verbose` logs for `'invalid character'` errors.

---

## Critical Lesson: The `secrets:` Catalog Block Syntax

The `docker-mcp.yaml` custom catalog format requires a specific YAML structure to forward environment variables into spawned containers. Several things do NOT work:

❌ **Does NOT work** — `environment:` block with `${VAR}` expansion:
```yaml
environment:
  MCP_MODE: ${MCP_MODE}
```

❌ **Does NOT work** — `env:` list format:
```yaml
env:
  - name: MCP_MODE
    value: ${MCP_MODE}
```

✅ **Works** — `secrets:` list with `name` and `env` keys, sourced from `mcp.env`:
```yaml
secrets:
  - name: MCP_MODE
    env: MCP_MODE
  - name: N8N_MCP_TELEMETRY_DISABLED
    env: N8N_MCP_TELEMETRY_DISABLED
```

The `name` field is the key in `mcp.env` (the secrets file). The `env` field is the environment variable name injected into the container. The gateway reads the `.env` file specified via the `--secrets` flag and expands them.

---

## How PocketBase Manages This Automatically

`services/pocketbase/pkg/relay/mcp.go` → `renderMCPCatalog()`:

1. Reads all approved `mcp_servers` records from the database.
2. For each record, writes a `registry` entry in `docker-mcp.yaml` with the correct `secrets:` block.
3. For each config key/value pair in the record's `config` JSON field, writes to `mcp.env`.
4. Restarts the gateway container so it reloads the catalog.

So to add a new MCP server with credentials, you simply:
1. Create a record in the `mcp_servers` PocketBase collection with `name`, `image`, and `config` (a JSON object of env var key-value pairs).
2. The relay auto-generates the catalog and restarts the gateway.

---

## Debugging Checklist

If tools fail to appear after `mcp-add`:

1. **Check gateway logs** for `Can't start <server>`:
   ```sh
   docker compose logs mcp-gateway --tail 50
   ```
2. **Look for `invalid character` errors** — this is the ASCII banner problem. Ensure `MCP_MODE=stdio` and any telemetry-disabling env vars are in the `config` field of the server record.
3. **Check the generated catalog**:
   ```sh
   docker compose exec mcp-gateway cat /root/.docker/mcp/docker-mcp.yaml
   docker compose exec mcp-gateway cat /root/.docker/mcp/mcp.env
   ```
   Verify your `secrets:` block is present and `mcp.env` has the correct values.
4. **Run the reference test script** from inside the sandbox:
   ```sh
   docker compose exec sandbox node /workspace/debug/test-n8n.js
   ```
   This script performs the full flow: SSE connect → init → mcp-config-set → mcp-add → tools/list → n8n_create_workflow.

---

## Reference: Verified Working Test Script

`scripts/debug/test-n8n.js` — tested successfully on 2026-02-28. Creates a real workflow in n8n with ID `4nX5xJlUPaVLit4k`.

**Key things the script demonstrates:**
- How to establish an SSE session and use the `sessionid` for POST calls.
- How to call `mcp-config-set` before `mcp-add` to inject runtime config.
- That `mcp-add` returns `"0 tools"` — this is normal! Tools are registered internally; they won't show in the `mcp-add` response.
- After `mcp-add`, the tools appear directly in `tools/list` (NOT via `mcp-exec` — direct tool calls work fine).
- The correct n8n workflow structure: must include at least 2 nodes with a proper connection.

---

## Notes on Protocol Version Negotiation

The gateway log shows:
```
Protocol version negotiated: client requested 2025-06-18, server will use 2025-03-26
```

This is a non-fatal warning. The docker-mcp binary uses a newer MCP spec version than `n8n-mcp`. This does not prevent operation.
