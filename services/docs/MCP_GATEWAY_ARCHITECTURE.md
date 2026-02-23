# Dynamic MCP Gateway Integration

## Concept

PocketCoder gains the ability to discover, approve, and consume MCP servers from Docker's MCP Catalog at runtime. Poco (the head agent) browses the catalog and requests servers. The user approves. PocketBase provisions them. Subagents in the sandbox use them.

No container gains more privilege than it needs. The linear isolation model is preserved.

## Components

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  MCP Gateway │     │   Sandbox    │     │   OpenCode   │     │  PocketBase  │
│  port 8811   │◄───►│  (subagents) │◄───►│   (Poco)     │◄───►│  (backend)   │
│              │     │              │     │              │     │              │
│  docker sock │     │  docker mcp  │     │  docker mcp  │     │  docker sock │
│  (read-only) │     │  CLI (client)│     │  CLI (catalog│     │  (read-write)│
│              │     │              │     │   read-only) │     │              │
│  Runs MCP    │     │  Connects to │     │  Browses     │     │  Manages     │
│  servers in  │     │  gateway SSE │     │  catalog     │     │  gateway     │
│  containers  │     │  Uses tools  │     │  Requests    │     │  lifecycle   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
```

## Roles

**Poco (OpenCode)** — The brain. Has the `docker mcp` CLI installed for catalog browsing only. Can run `docker mcp catalog show docker-mcp` to discover available MCP servers. Cannot install or enable servers. Cannot reach the gateway network. When Poco identifies an MCP server it needs, it sends a request through the existing relay to PocketBase.

**PocketBase** — The hands. Has read-write docker socket access. Owns the MCP gateway config files. Receives MCP server requests from Poco, surfaces them to the user for approval via the Flutter app, and upon approval: writes the config, and uses the docker socket to bring the gateway up (or restart it) with the new configuration.

**MCP Gateway** — The toolbox. A `docker/mcp-gateway` container with read-only docker socket access. It uses the socket to spin up individual MCP server containers (each server runs isolated). Exposes all enabled servers through a single SSE endpoint on port 8811. Its config is managed entirely by PocketBase.

**Sandbox (subagents)** — The workers. Has the `docker mcp` CLI installed as a client. Subagents connect to the gateway's SSE endpoint (`http://mcp-gateway:8811/sse`) and consume MCP tools. They are the actual users of the MCP servers. Sandbox is on the same network as the gateway.

**Flutter app** — The gatekeeper. Displays MCP server requests to the user. User approves or denies. Same UX pattern as the existing permission gating system.

## Flow

1. User asks Poco to do something that requires an external tool (e.g., "query my postgres database").

2. Poco browses the Docker MCP Catalog using the CLI. Finds the relevant MCP server (e.g., `postgres`).

3. Poco cannot install it — wrong network, no docker socket. He sends a structured request to PocketBase through the relay: "I need the `postgres` MCP server."

4. PocketBase creates a record in an `mcp_requests` collection (or similar) with status `pending`. The Flutter app shows this to the user.

5. User reviews and approves the request in the Flutter app.

6. PocketBase handles provisioning:
   - Updates the approval record to `approved`.
   - Reads all currently approved MCP servers from its database.
   - Renders the gateway catalog (`docker-mcp.yaml`) by upserting from the database — the database is the source of truth, the catalog file is just a projection.
   - Uses the docker socket to start or restart the MCP gateway container with the updated config.

7. PocketBase notifies Poco (via the relay) that the gateway is ready and the requested MCP server is available.

8. Poco spawns a subagent (via CAO handoff/assign) with instructions to use the new MCP tool. The subagent runs in the sandbox, connects to the gateway at `http://mcp-gateway:8811/sse`, and executes the MCP tools.

9. Subagent returns results to Poco. Poco synthesizes and responds to the user.

## Network Topology

```
pocketcoder-memory:   PocketBase ↔ OpenCode
pocketcoder-control:  OpenCode ↔ Sandbox
pocketcoder-mcp:      Sandbox ↔ MCP Gateway ↔ PocketBase
```

The MCP Gateway lives on a new network (`pocketcoder-mcp`) shared with Sandbox and PocketBase. Sandbox connects to consume tools. PocketBase connects to manage the gateway lifecycle. OpenCode (Poco) is deliberately excluded — it can think about MCPs but cannot touch them.

## Docker Socket Access

Two containers need the docker socket, for different reasons:

| Container | Socket Mode | Purpose |
|-----------|-------------|---------|
| MCP Gateway | Read-only | Spin up isolated MCP server containers from the catalog |
| PocketBase | Read-write | Start, stop, and restart the MCP gateway container itself |

Poco and Sandbox have no docker socket access.

## Config as Database Projection

PocketBase's database is the single source of truth for which MCP servers are enabled. The gateway config files on disk are a derived artifact. Every time an MCP server is approved or revoked:

1. Query all approved MCP servers from the database.
2. Render `docker-mcp.yaml` (the catalog of approved servers for the gateway).
3. Write to the shared config volume.
4. Restart the gateway to pick up changes.

This means the config files can always be regenerated from the database. No manual editing. No drift.

## Approval Model

MCP server requests follow the same pattern as the existing permission gating:

- Poco requests → PocketBase records → Flutter shows to user → User approves/denies → PocketBase acts.

The difference is that permission approvals are per-action (ephemeral), while MCP server approvals are persistent — once approved, the server stays enabled across sessions until explicitly revoked.

## Volume Mounts: MCP Config

The MCP gateway config lives on a shared volume (`mcp_config`). Multiple containers mount it with different access levels:

| Container | Mount Path | Mode | Purpose |
|-----------|-----------|------|---------|
| PocketBase | `/mcp_config` | read-write | Renders catalog from database, writes `docker-mcp.yaml` |
| OpenCode (Poco) | `/mcp_config` | read-only | Reads current config to know what's already installed before requesting new servers |
| MCP Gateway | `/root/.docker/mcp` | read-only | Reads config to know which servers to run |
| Sandbox | — | none | Doesn't need config access. Connects to gateway SSE and discovers tools dynamically. |

Poco's read access to the config is important — before requesting a new MCP server, he checks what's already enabled to avoid duplicate requests.

## What Gets Installed Where

| Container | What | Why |
|-----------|------|-----|
| OpenCode | `docker mcp` CLI + config volume (ro) | Catalog browsing and reading current config. Read-only discovery. |
| Sandbox | `docker mcp` CLI | Client connectivity. Subagents use it to interact with the gateway SSE endpoint. |
| PocketBase | Docker socket (rw) + config volume (rw) | Gateway lifecycle management. Writes config, manages gateway container. |
| MCP Gateway | `docker/mcp-gateway` image + docker socket (ro) + config volume (ro) | Runs MCP servers in containers. Exposes unified SSE endpoint. |
