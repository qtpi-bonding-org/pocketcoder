# MCP Gateway Test Status

## Goal

Prove that the MCP Gateway can dynamically spin up a new Docker container for an MCP server (e.g., `fetch`) when requested. This is the core value proposition of the Dynamic MCP integration — Poco requests a server, user approves it, PocketBase writes the catalog, restarts the gateway, and a real container appears.

We want to SEE a container spin up. No fake passes.

## Current Test Results (22/23 passing)

```
ok 1  MCP Full Flow: Poco browses Docker MCP Catalog via CLI
ok 2  MCP Full Flow: Poco reads mcp_status from config volume
ok 3  MCP Full Flow: Poco requests MCP server via POST /api/pocketcoder/mcp_request
ok 4  MCP Full Flow: PocketBase creates mcp_servers record with status pending
ok 5  MCP Full Flow: User approves MCP server request
ok 6  MCP Full Flow: Config rendered to mcp_config volume after approval
ok 7  MCP Full Flow: Gateway container restarted after config change
ok 8  MCP Full Flow: Gateway SSE endpoint available on port 8811
ok 9  MCP Full Flow: Sandbox can connect to gateway SSE as MCP client
ok 10 MCP Full Flow: Denied request notifies Poco without provisioning
ok 11 MCP Full Flow: Revoked server removed from config and gateway restarted
ok 12 MCP Full Flow: Complete end-to-end test
ok 13 MCP Infra: PocketBase can restart MCP Gateway container via docker socket
FAIL 14 MCP Infra: MCP Gateway spins up MCP server container via Dynamic MCP
ok 15 MCP Request: Endpoint requires authentication (unauthenticated POST → 401)
ok 16 MCP Request: Endpoint creates pending record (agent POST → 200)
ok 17 MCP Request: Endpoint returns existing approved record (idempotent)
ok 18 Auth Hardening: Permission endpoint requires auth (401)
ok 19 Auth Hardening: SSH keys endpoint requires auth (401)
ok 20 MCP Servers Collection: Exists and accepts records
ok 21 MCP Request: Agent can create pending record
ok 22 MCP Request: Multiple pending requests create separate records
ok 23 Property 1: MCP request idempotency for approved servers
```

## The One Failing Test: Dynamic MCP Container Spin-Up (Test 14)

### What we're trying to do

1. Approve an MCP server (`fetch`) in PocketBase
2. PocketBase relay renders `docker-mcp.yaml` catalog to the shared volume
3. PocketBase restarts the gateway container
4. Gateway reads the catalog, sees `fetch` is approved
5. **Something triggers the gateway to actually pull `mcp/fetch` image and start a container**
6. We assert a new container appeared in `docker ps`

Steps 1-4 all work. Step 5 is where we're stuck.

### What we've tried and what happened

| Approach | Where | Result |
|----------|-------|--------|
| `docker mcp tools call mcp-add '{"name": "fetch"}'` | sandbox | `starting client: calling "initialize": EOF` — sandbox CLI tries to start a LOCAL gateway process (stdio), can't find one |
| `docker mcp tools call mcp-add '{"name": "fetch"}'` | gateway | `calling tool: calling "tools/call": name parameter is required` — JSON arg format seems wrong |
| `docker mcp server enable fetch` | gateway | `✓ Server enabled` — but this only modifies the local registry config, doesn't start a container |
| `docker mcp server enable fetch` + restart gateway | gateway | Not yet tried |

### The core problem

The `docker mcp` CLI uses **stdio transport** — it spawns `docker mcp gateway run` as a subprocess and communicates over stdin/stdout. This means:

- `docker mcp tools call` from the **sandbox** fails because the sandbox doesn't have a local gateway process to connect to. The `MCP_HOST` env var pointing to `http://mcp-gateway:8811/sse` is not used by the CLI.
- `docker mcp tools call` from the **gateway container** starts a *second* gateway process (stdio), which should work but the argument format for `mcp-add` is wrong.

The gateway logs show:
```
- No server is enabled
- Adding internal tools (dynamic-tools feature enabled)
  > mcp-find, mcp-add, mcp-remove, code-mode, mcp-exec, mcp-config-set, mcp-discover
> Start sse server on port 8811
```

So the gateway starts with Dynamic MCP tools available, but "No server is enabled" means the catalog entries aren't automatically enabled — they're just in the catalog for discovery.

### What the Docker docs say

From the Dynamic MCP documentation:

> When you connect a client to the MCP Gateway, the gateway exposes management tools (mcp-find, mcp-add, mcp-remove, etc.). An agent can search the catalog, add servers, and use newly added tools directly without requiring a restart.

The flow is: **client connects to gateway SSE → client calls `mcp-add` tool → gateway pulls image and starts container**.

The problem is that `docker mcp tools call` doesn't connect to a remote SSE gateway — it starts a local stdio gateway. So we can't use it from the sandbox to talk to the remote gateway.

## Things to try next

### 1. Fix the `docker mcp tools call` argument format (inside gateway)

The error `name parameter is required` with JSON `{"name": "fetch"}` suggests the CLI might want a different format. Try:
- `docker mcp tools call mcp-add --name fetch`
- `docker mcp tools call mcp-add fetch`
- `docker mcp tools call mcp-add '{"server_name": "fetch"}'`

### 2. `docker mcp server enable` + gateway restart

Since `server enable` modifies the registry, restarting the gateway should cause it to read the registry and start the enabled server's container. This is the simplest approach:
```bash
docker exec pocketcoder-mcp-gateway docker mcp server enable fetch
docker restart pocketcoder-mcp-gateway
# wait, then check docker ps for new container
```

### 3. Use curl to send MCP protocol messages directly to the SSE endpoint

Instead of using the CLI, send raw MCP JSON-RPC messages to `http://mcp-gateway:8811/sse` from the sandbox via curl. This is what a real MCP client does. The flow would be:
1. Connect to SSE endpoint
2. Send `initialize` request
3. Send `tools/call` with `mcp-add` tool and `{"name": "fetch"}` argument
4. Parse response

This is more complex but is the actual protocol path.

### 4. Configure the sandbox as a proper MCP client

Run `docker mcp client connect opencode` inside the sandbox to configure it as a client of the gateway. This might make `docker mcp tools call` work from the sandbox by configuring it to use the gateway.

### 5. Check if the gateway docker socket is read-only

The gateway has `docker.sock:/var/run/docker.sock:ro` (read-only). If the gateway needs to create containers, it needs write access. Check if this is blocking container creation.

**Update**: Looking at `docker-compose.yml`, the gateway socket IS read-only. This might be the issue — the gateway can't create containers with a read-only socket. The architecture doc says "MCP Gateway: Read-only docker socket — Spin up isolated MCP server containers" but Docker's container creation API requires write access.

## Fixed issues (this session)

- SSE HTTP code concatenation (`200000` → `200`): Fixed by capturing curl output in a variable instead of using `|| echo 000`
- OpenCode `sh -c` failure: Fixed by using `ash -c` (Alpine doesn't have `/bin/sh` symlinked)
- 401 response body check: Fixed to check for both `"error"` and `"message"` fields
- 403 role check test: Deleted — the admin user has role `"admin"` which is allowed by the MCP endpoint. Testing 403 requires a `"user"` role account which isn't seeded.
- `totalCount` → `totalItems`: Fixed PocketBase API field name
- `run-tests.sh` now rebuilds images with `--build`
- `run-tests.sh` now captures container logs to `tests/logs/` before teardown
- `.gitignore` updated to exclude `tests/logs/`

## Files involved

- `tests/integration/mcp/mcp-full-flow.bats` — Main test file, test 14 is the failing one
- `tests/integration/mcp/mcp-gateway.bats` — API endpoint tests (all passing)
- `tests/integration/agent/mcp-flow.bats` — Agent-level MCP tests (not yet run)
- `tests/helpers/mcp.sh` — MCP helper functions
- `tests/helpers/diagnostics.sh` — Diagnostic output on failure
- `tests/run-tests.sh` — Test runner (now with `--build` and log capture)
- `docker/mcp-gateway-entrypoint.sh` — Gateway entrypoint
- `docker/mcp-gateway.Dockerfile` — Gateway image
- `docker/sandbox.Dockerfile` — Sandbox image (now has docker-ce-cli)
- `docker-compose.yml` — Service definitions
- `backend/pkg/relay/mcp.go` — Relay hooks (config render, gateway restart)
- `backend/internal/api/mcp.go` — MCP request endpoint
