# MCP Gateway Integration — Implementation Plan

Reference: [MCP_GATEWAY_ARCHITECTURE.md](./MCP_GATEWAY_ARCHITECTURE.md)

---

## 1. MCP Gateway Container

New service based on the working example in `test-mcp-install/`.

### Dockerfile (`docker/mcp-gateway.Dockerfile`)

- Base: `alpine:latest`
- Installs: `curl`, `docker-cli`, `ca-certificates`
- Downloads `docker-mcp` binary from GitHub releases (pin version, e.g., `v0.39.3`)
- Sets `DOCKER_MCP_IN_CONTAINER=1`
- Entrypoint: custom script that inits catalog then runs gateway

### Entrypoint (`docker/mcp-gateway-entrypoint.sh`)

```sh
#!/bin/sh
set -e
echo "Initializing MCP catalog..."
docker mcp catalog init
echo "Starting MCP Gateway..."
exec docker mcp gateway run --port 8811 --transport sse --verbose
```

No `--servers` flag. The gateway uses `--catalog` to read `docker-mcp.yaml` from the config volume — a custom catalog of user-approved servers. Subagents use Dynamic MCP (`mcp-find`, `mcp-add`) to add servers from this catalog on-demand. PocketBase controls that file.

### Compose Entry

```yaml
mcp-gateway:
  build:
    context: .
    dockerfile: docker/mcp-gateway.Dockerfile
  container_name: pocketcoder-mcp-gateway
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - mcp_config:/root/.docker/mcp
  environment:
    - DOCKER_MCP_IN_CONTAINER=1
  networks:
    - pocketcoder-mcp
  restart: unless-stopped
```

No host ports. Only reachable within `pocketcoder-mcp`.

---

## 2. Network & Volume Changes

### New Network

```yaml
networks:
  pocketcoder-mcp:
    driver: bridge
```

### Who Joins

| Container | Networks | Why |
|-----------|----------|-----|
| mcp-gateway | `pocketcoder-mcp` | Serves MCP tools |
| sandbox | `pocketcoder-control` + `pocketcoder-mcp` | Subagents consume MCP tools |
| pocketbase | `pocketcoder-memory` + `pocketcoder-mcp` | Manages gateway lifecycle |
| opencode | `pocketcoder-memory` + `pocketcoder-control` | Unchanged. No MCP network. |

### New Volume

```yaml
volumes:
  mcp_config:
```

### Volume Mounts

| Container | Mount | Mode | Purpose |
|-----------|-------|------|---------|
| mcp-gateway | `/root/.docker/mcp` | from volume | Gateway reads config |
| pocketbase | `/mcp_config` | rw | Writes config from DB |
| opencode | `/mcp_config` | ro | Poco reads what's installed |

### PocketBase Docker Socket

PocketBase needs docker socket to manage the gateway container:

```yaml
pocketbase:
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - mcp_config:/mcp_config
  networks:
    - pocketcoder-memory
    - pocketcoder-mcp
```

---

## 3. Poco's Custom Tools (OpenCode Plugin)

This is the key design decision. Instead of Poco using bash (which routes through the shell bridge → sandbox → tmux capture with truncation), we use OpenCode's native custom tools system. Tools defined in `.opencode/tools/` run inside the OpenCode container process directly. They can:

- Execute commands locally in the OpenCode container (no shell bridge)
- Make HTTP calls to PocketBase (OpenCode is on `pocketcoder-memory`)
- Read files from mounted volumes (like `/mcp_config`)
- Return full, untruncated output to the LLM

### Tool: `mcp_catalog` — Browse Available Servers

File: `.opencode/tools/mcp_catalog.ts`

```typescript
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Browse the Docker MCP Catalog to discover available MCP servers. Returns the full list of servers available for installation.",
  args: {
    search: tool.schema.string().optional().describe("Optional search term to filter servers"),
  },
  async execute(args) {
    const cmd = args.search
      ? `docker mcp catalog show docker-mcp 2>&1 | grep -i "${args.search}"`
      : `docker mcp catalog show docker-mcp 2>&1`
    const result = await Bun.$`sh -c ${cmd}`.text()
    return result.trim()
  },
})
```

This runs `docker mcp` inside the OpenCode container. Requires `docker-cli` + `docker-mcp` plugin installed in the OpenCode Dockerfile. No docker socket needed — catalog commands read from the local index.

### Tool: `mcp_status` — Check What's Installed

File: `.opencode/tools/mcp_status.ts`

```typescript
import { tool } from "@opencode-ai/plugin"
import { readFile } from "fs/promises"

export default tool({
  description: "Check which MCP servers are currently enabled in the gateway. Reads the live config.",
  args: {},
  async execute() {
    try {
      const catalog = await readFile("/mcp_config/docker-mcp.yaml", "utf-8")
      return `Currently approved MCP servers (catalog):\n${catalog}`
    } catch {
      return "No MCP servers are currently enabled (config not found)."
    }
  },
})
```

Reads directly from the mounted config volume. No shell, no truncation.

### Tool: `mcp_request` — Request a New Server

File: `.opencode/tools/mcp_request.ts`

```typescript
import { tool } from "@opencode-ai/plugin"

let cachedToken: string | null = null

async function getAgentToken(): Promise<string> {
  if (cachedToken) return cachedToken
  const pbUrl = process.env.POCKETBASE_URL || "http://pocketbase:8090"
  const resp = await fetch(`${pbUrl}/api/collections/users/auth-with-password`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      identity: process.env.AGENT_EMAIL,
      password: process.env.AGENT_PASSWORD,
    }),
  })
  if (!resp.ok) throw new Error(`Agent auth failed: ${resp.status}`)
  const data = await resp.json()
  cachedToken = data.token
  return cachedToken!
}

export default tool({
  description: "Request a new MCP server to be enabled. This sends the request to PocketBase for user approval. The server will be available to subagents after approval.",
  args: {
    server_name: tool.schema.string().describe("Name of the MCP server from the catalog (e.g., 'postgres', 'duckduckgo')"),
    reason: tool.schema.string().describe("Why this server is needed for the current task"),
  },
  async execute(args, context) {
    const pbUrl = process.env.POCKETBASE_URL || "http://pocketbase:8090"
    const token = await getAgentToken()

    const resp = await fetch(`${pbUrl}/api/pocketcoder/mcp_request`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`,
      },
      body: JSON.stringify({
        server_name: args.server_name,
        reason: args.reason,
        session_id: context.sessionID,
      }),
    })

    if (!resp.ok) {
      const err = await resp.text()
      return `Request failed: ${err}`
    }

    const data = await resp.json()
    return `MCP server '${args.server_name}' request submitted (ID: ${data.id}, status: ${data.status}). Waiting for user approval.`
  },
})
```

This makes an HTTP call directly from the OpenCode container to PocketBase. Works because both are on `pocketcoder-memory`.

### OpenCode Dockerfile Changes

Add `docker-cli` and `docker-mcp` plugin to `docker/opencode.Dockerfile`:

```dockerfile
# Add docker-cli for MCP catalog browsing
RUN apk add --no-cache docker-cli && \
    ARCH=$(uname -m) && \
    case $ARCH in \
      x86_64)  M_ARCH="amd64" ;; \
      aarch64) M_ARCH="arm64" ;; \
    esac && \
    VERSION="v0.39.3" && \
    curl -L "https://github.com/docker/mcp-gateway/releases/download/${VERSION}/docker-mcp-linux-${M_ARCH}.tar.gz" -o /tmp/docker-mcp.tar.gz && \
    tar -xzf /tmp/docker-mcp.tar.gz -C /tmp && \
    mkdir -p /usr/local/lib/docker/cli-plugins/ && \
    mv /tmp/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-mcp && \
    rm /tmp/docker-mcp.tar.gz

ENV DOCKER_MCP_IN_CONTAINER=1
```

### OpenCode Environment

The OpenCode container needs `AGENT_EMAIL` and `AGENT_PASSWORD` in its environment so the `mcp_request` tool can authenticate to PocketBase. These are already defined in `.env` — just add them to the opencode service in `docker-compose.yml`:

```yaml
opencode:
  environment:
    - AGENT_EMAIL=${AGENT_EMAIL}
    - AGENT_PASSWORD=${AGENT_PASSWORD}
    - POCKETBASE_URL=http://pocketbase:8090
```

### Auth on the API Endpoint

The `POST /api/pocketcoder/mcp_request` endpoint should validate the Bearer token and check that the caller has the `agent` role. This is the first custom endpoint to enforce auth — the existing `/api/pocketcoder/permission` and `/api/pocketcoder/ssh_keys` endpoints are currently unauthenticated (they rely on network isolation). The MCP endpoint should set the precedent.

In the Go handler:

```go
// Extract and validate auth
authRecord := re.Auth
if authRecord == nil {
    return re.JSON(401, map[string]string{"error": "Authentication required"})
}
role := authRecord.GetString("role")
if role != "agent" && role != "admin" {
    return re.JSON(403, map[string]string{"error": "Insufficient permissions"})
}
```

PocketBase's `re.Auth` automatically resolves the Bearer token from the `Authorization` header. No manual JWT parsing needed.

### Permission Config

Add to `opencode.json`:

```json
"permission": {
  "mcp_catalog": "allow",
  "mcp_status": "allow",
  "mcp_request": "ask"
}
```

Catalog browsing and status checks are safe (read-only). Requesting a new server requires permission gating (user sees it in the approval flow).

### Skill: MCP Discovery Workflow

File: `agents/poco/skills/mcp-gateway/SKILL.md`

```markdown
---
name: mcp-gateway
description: How to discover, request, and use MCP servers via the Docker MCP Gateway.
---

# SKILL: MCP Gateway Integration

When a task requires external tools (databases, APIs, services), use the MCP Gateway workflow.

## Discovery
1. Use the `mcp_status` tool to check what's already enabled.
2. Use the `mcp_catalog` tool to browse available servers. Search by keyword.

## Requesting
3. If the needed server isn't enabled, use `mcp_request` with the server name and reason.
4. Tell the user you've submitted the request and are waiting for approval.
5. When PocketBase notifies you the server is ready, proceed to delegation.

## Delegation
6. Spawn a subagent via `cao_handoff` or `cao_assign`.
7. The subagent profile should include the MCP gateway connection.
8. The subagent connects to `http://mcp-gateway:8811/sse` and uses the MCP tools.
9. You (Poco) do NOT use MCP tools directly. Only subagents in the sandbox can.

## Important
- Never request a server that's already enabled (check `mcp_status` first).
- Always explain to the user what server you need and why.
- MCP tools run in isolated containers managed by the gateway.
```

---

## 4. Docker MCP CLI in Sandbox

Subagents need the `docker mcp` CLI to interact with the gateway as clients.

### Sandbox Dockerfile Changes

Add to `docker/sandbox.Dockerfile` (Debian-based):

```dockerfile
RUN ARCH=$(uname -m) && \
    case $ARCH in \
      x86_64)  M_ARCH="amd64" ;; \
      aarch64) M_ARCH="arm64" ;; \
    esac && \
    VERSION="v0.39.3" && \
    curl -L "https://github.com/docker/mcp-gateway/releases/download/${VERSION}/docker-mcp-linux-${M_ARCH}.tar.gz" -o /tmp/docker-mcp.tar.gz && \
    tar -xzf /tmp/docker-mcp.tar.gz -C /tmp && \
    mkdir -p /usr/local/lib/docker/cli-plugins/ && \
    mv /tmp/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-mcp && \
    rm /tmp/docker-mcp.tar.gz

ENV DOCKER_MCP_IN_CONTAINER=1
```

Note: Sandbox already has `docker-cli` installed (it's in the existing Dockerfile for other purposes). If not, add it.

### Sandbox Environment

```yaml
sandbox:
  environment:
    - MCP_HOST=http://mcp-gateway:8811/sse
    - DOCKER_MCP_IN_CONTAINER=1
```

### Subagent Profile Template

Bake the gateway connection into subagent profiles. When Poco creates a subagent profile in `/root/.aws/cli-agent-orchestrator/agent-store/`, it should include:

```json
{
  "mcpServers": {
    "docker-gateway": {
      "type": "remote",
      "url": "http://mcp-gateway:8811/sse",
      "enabled": true
    }
  }
}
```

This gives every subagent automatic access to whatever MCP servers are currently enabled in the gateway.

---

## 5. PocketBase: Collection & API

### Auth Model

There are two auth layers in PocketBase:

1. **Collection rules** — protect the standard CRUD endpoints (`/api/collections/*/records`). These are already set on all collections (e.g., `ListRule: "@request.auth.id != ''"`, role-based access on chats/messages). These work correctly.

2. **Custom route auth** — must be explicitly added to custom `/api/pocketcoder/*` endpoints. PocketBase's global middleware auto-loads the auth token from the `Authorization` header into `re.Auth`, but it doesn't *require* it. You need either `apis.RequireAuth()` middleware or a manual `re.Auth == nil` check.

Current state of custom endpoints:

| Endpoint | Auth | Status |
|----------|------|--------|
| `GET /api/pocketcoder/artifact/{path}` | `re.Auth == nil` check | ✅ Protected |
| `POST /api/pocketcoder/permission` | None | ❌ Open |
| `GET /api/pocketcoder/ssh_keys` | None | ❌ Open |
| `POST /api/pocketcoder/mcp_request` | New | ✅ Will be protected |

Since PocketBase port 8090 is exposed to the host (for Flutter and admin UI), the unprotected endpoints are reachable by anyone on the host machine.

### Auth Hardening Plan

Add `apis.RequireAuth()` middleware to all custom endpoints. This is the PocketBase-native way — it validates the JWT and rejects unauthenticated requests with 401.

**Permission endpoint** (`backend/internal/api/permission.go`):
```go
e.Router.POST("/api/pocketcoder/permission", func(re *core.RequestEvent) error {
    // ... existing handler ...
}).Bind(apis.RequireAuth())
```

**SSH keys endpoint** (`backend/internal/api/ssh.go`):
```go
e.Router.GET("/api/pocketcoder/ssh_keys", func(re *core.RequestEvent) error {
    // ... existing handler ...
}).Bind(apis.RequireAuth())
```

**MCP request endpoint** (`backend/internal/api/mcp.go`):
```go
e.Router.POST("/api/pocketcoder/mcp_request", func(re *core.RequestEvent) error {
    // ... handler ...
}).Bind(apis.RequireAuth())
```

For the MCP endpoint specifically, also add a role check inside the handler:
```go
role := re.Auth.GetString("role")
if role != "agent" && role != "admin" {
    return re.ForbiddenError("Insufficient permissions", nil)
}
```

This gives us both layers: `apis.RequireAuth()` ensures a valid token exists, and the role check ensures only the agent or admin can submit MCP requests. Regular users can't impersonate Poco.

The artifact endpoint already has a manual `re.Auth == nil` check. It could be migrated to `apis.RequireAuth()` for consistency, but it works as-is.

### New Collection: `mcp_servers`

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `name` | Text | yes | Server name from catalog (e.g., `postgres`) |
| `status` | Select | yes | `pending`, `approved`, `denied`, `revoked` |
| `requested_by` | Text | no | Session ID or agent name |
| `approved_by` | Relation | no | Links to `users` |
| `approved_at` | Date | no | |
| `config` | JSON | no | Per-server config overrides |
| `catalog` | Text | no | Default: `docker-mcp` |
| `reason` | Text | no | Why it was requested |

Migration: `backend/pb_migrations/1740000102_mcp_servers.go`

### Custom API Endpoint

File: `backend/internal/api/mcp.go`

```
POST /api/pocketcoder/mcp_request
{
  "server_name": "postgres",
  "reason": "User needs to query their PostgreSQL database",
  "session_id": "..."
}

Response:
{
  "id": "record_id",
  "status": "pending"
}
```

Creates an `mcp_servers` record with `status: "pending"`. If a record with the same `name` already exists and is `approved`, returns the existing record instead of creating a duplicate.

Register in `backend/main.go` alongside existing API endpoints.

---

## 6. PocketBase: Relay Hook — Config Rendering & Gateway Restart

New file: `backend/pkg/relay/mcp.go`

### Hook Registration

Add `r.registerMcpHooks()` in `relay.go:Start()`.

### On Status Change

```
OnRecordAfterUpdateSuccess("mcp_servers") →
  if status == "approved" → renderMcpConfig() → restartGateway() → notifyPoco()
  if status == "revoked"  → renderMcpConfig() → restartGateway() → notifyPoco()
  if status == "denied"   → notifyPoco()
```

### renderMcpConfig()

1. Query all `mcp_servers` where `status = "approved"`.
2. Write `/mcp_config/docker-mcp.yaml` as a gateway catalog:
   ```yaml
   registry:
     postgres:
       title: postgres
       description: Approved by user for PocketCoder
       type: server
       image: mcp/postgres
     duckduckgo:
       title: duckduckgo
       description: Approved by user for PocketCoder
       type: server
       image: mcp/duckduckgo
   ```
3. Full overwrite each time. DB is source of truth.
4. No `registry.yaml` or `config.yaml` needed — the gateway uses `--catalog` flag to read this file, and Dynamic MCP handles server lifecycle.

### restartGateway()

Use Docker API via Unix socket (Option 1 — no external dependency):

```go
client := &http.Client{
    Transport: &http.Transport{
        DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
            return net.Dial("unix", "/var/run/docker.sock")
        },
    },
}
resp, err := client.Post(
    "http://localhost/containers/pocketcoder-mcp-gateway/restart",
    "",
    nil,
)
```

No `docker-cli` needed in PocketBase. Pure Go HTTP to the socket.

### notifyPoco()

After gateway restart, send a system message to the relevant chat via the existing relay → OpenCode path. Use `prompt_async` to inject:

```
[SYSTEM] MCP server '{name}' is now available. Subagents can connect to the gateway at http://mcp-gateway:8811/sse.
```

For denial:
```
[SYSTEM] MCP server '{name}' request was denied by the user.
```

### On Startup

When PocketBase boots, call `renderMcpConfig()` once to ensure config matches DB state. This handles the case where the DB was modified while the system was down.

---

## 7. Startup Ordering

The gateway is optional. No hard dependencies.

1. **MCP Gateway** starts. Inits catalog. If no servers in config, runs idle.
2. **PocketBase** starts. Calls `renderMcpConfig()` on boot. If approved servers exist and gateway is up, restarts it.
3. **OpenCode** starts. Custom tools available immediately. Can browse catalog and check status.
4. **Sandbox** starts. `MCP_HOST` set. Subagents can connect when gateway has servers.

If gateway is down, everything else works. Subagents just can't use MCP tools.

---

## 8. File Summary

| File | Action | Purpose |
|------|--------|---------|
| `docker/mcp-gateway.Dockerfile` | Create | Gateway container |
| `docker/mcp-gateway-entrypoint.sh` | Create | Catalog init + gateway run |
| `docker-compose.yml` | Modify | Add gateway service, mcp network, volume mounts, docker socket for PB |
| `docker/opencode.Dockerfile` | Modify | Add `docker-cli` + `docker-mcp` plugin + `DOCKER_MCP_IN_CONTAINER` |
| `docker/sandbox.Dockerfile` | Modify | Add `docker-mcp` plugin + `DOCKER_MCP_IN_CONTAINER` |
| `.opencode/tools/mcp_catalog.ts` | Create | Poco tool: browse catalog |
| `.opencode/tools/mcp_status.ts` | Create | Poco tool: check installed servers |
| `.opencode/tools/mcp_request.ts` | Create | Poco tool: request new server (authed) |
| `agents/poco/skills/mcp-gateway/SKILL.md` | Create | Poco skill: MCP workflow |
| `opencode.json` | Modify | Add tool permissions, agent env vars |
| `backend/pb_migrations/1740000102_mcp_servers.go` | Create | New collection |
| `backend/internal/api/mcp.go` | Create | `POST /api/pocketcoder/mcp_request` (with `RequireAuth` + role check) |
| `backend/internal/api/permission.go` | Modify | Add `apis.RequireAuth()` middleware |
| `backend/internal/api/ssh.go` | Modify | Add `apis.RequireAuth()` middleware |
| `backend/pkg/relay/mcp.go` | Create | Approval hooks, config render, gateway restart, notify |
| `backend/pkg/relay/relay.go` | Modify | Register MCP hooks |
| `backend/main.go` | Modify | Register MCP API endpoint |
