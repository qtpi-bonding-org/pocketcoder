# Plan: Apply test-mcp-install Findings to Main PocketCoder Setup

Based on `docs/MCP_GATEWAY_IMPLEMENTATION_SPEC.md` (the "Golden Path") and the working sandbox in `test-mcp-install/`.

---

## What the Sandbox Proved

The `test-mcp-install/` sandbox validated:
1. Docker socket `:ro` works for spinning up containers (gateway uses `docker run --rm` internally)
2. Flat `registry:` schema in `docker-mcp.yaml` with `longLived: false` (CamelCase) for ephemeral containers
3. Gateway startup flags: `--transport sse --verbose --catalog <path> --enable-all-servers`
4. `docker mcp tools call mcp-add name=fetch` syntax (key=value, NOT JSON)
5. SSE handshake: connect → get endpoint → initialize → notifications/initialized → tools/call
6. Containers die immediately after tool result when `longLived: false`

---

## Deltas: What Needs to Change in Main Setup

### 1. `docker-compose.yml` — Gateway service missing `command`

**Current:** No `command` — relies entirely on entrypoint script.
**Test sandbox:** Uses explicit `command` with all required flags.

**Fix:** Add `command` to the `mcp-gateway` service:
```yaml
mcp-gateway:
  ...
  command: ["--port", "8811", "--transport", "sse", "--verbose", "--catalog", "/root/.docker/mcp/docker-mcp.yaml", "--enable-all-servers"]
```

### 2. `docker/mcp-gateway-entrypoint.sh` — Missing `--enable-all-servers`

**Current:**
```sh
exec docker mcp gateway run --port 8811 --transport sse --catalog="$CATALOG_FILE" --verbose
```

**Fix:** Add `--enable-all-servers`:
```sh
exec docker mcp gateway run --port 8811 --transport sse --catalog="$CATALOG_FILE" --verbose --enable-all-servers
```

Without `--enable-all-servers`, servers in the catalog are not resolved at startup, so `mcp-add` calls fail because the gateway doesn't know about them.

### 3. `docker/mcp-gateway.Dockerfile` — Simplify entrypoint

**Current:** Uses a shell entrypoint that runs `docker mcp catalog init` then `docker mcp gateway run`.
**Test sandbox:** Uses direct `ENTRYPOINT ["docker", "mcp", "gateway", "run"]` with `command` in compose.

**Fix:** Two options:
- **Option A (minimal):** Just fix the entrypoint script (change #2 above). Keep the `catalog init` step.
- **Option B (match sandbox):** Switch to direct entrypoint, pass all args via compose `command`. Drop `catalog init` since we provide our own catalog file.

**Recommendation:** Option A for now — less risk, keeps the init step as a safety net.

### 4. `backend/pkg/relay/mcp.go` — Catalog YAML missing `longLived` field

**Current `renderMcpConfig()` output:**
```yaml
registry:
  fetch:
    title: fetch
    description: Approved by user for PocketCoder
    type: server
    image: mcp/fetch
```

**Test sandbox catalog:**
```yaml
registry:
  fetch:
    description: "Fetches a URL..."
    title: "Fetch"
    type: "server"
    image: "mcp/fetch"
    longLived: false
```

**Fix:** Add `longLived: false` to each server entry in `renderMcpConfig()`. This is the spec's "maximum security and zero resource leaks" mode — containers die immediately after returning a result.

Also missing: `name:` and `displayName:` top-level fields. Add:
```yaml
name: docker-mcp
displayName: PocketCoder Dynamic Catalog
```

### 5. `tests/helpers/mcp.sh` — `mcp_add_server` uses JSON syntax

**Current:**
```sh
mcp_tools_call "mcp-add" "{\"name\": \"$server_name\"}" 120
```

**Spec says:** `docker mcp tools call` does NOT accept JSON for simple arguments.
**Correct:** `docker mcp tools call mcp-add name=fetch`

**Fix:** Change `mcp_add_server()` to use key=value syntax:
```sh
mcp_add_server() {
    local server_name="$1"
    docker exec pocketcoder-mcp-gateway \
        timeout 120 \
        docker mcp tools call mcp-add name="$server_name" 2>&1
}
```

Same fix needed for `mcp_find_server` and `mcp_remove_server`.

### 6. `tests/integration/mcp/mcp-full-flow.bats` — Test 14 (Dynamic MCP spin-up)

**Current:** Uses `docker mcp tools call mcp-add --name "fetch"` and falls back to positional arg.
**Spec says:** Use `name=fetch` (key=value).

**Fix:** Replace the mcp-add call in the "MCP Infra: MCP Gateway spins up MCP server container" test:
```sh
docker exec pocketcoder-mcp-gateway \
    timeout 120 \
    docker mcp tools call mcp-add name="$server_name" 2>&1
```

Remove the fallback retry logic — the key=value syntax is the verified correct form.

### 7. Sandbox SSE Client (CAO/OpenCode Provider) — No persistent session model

**Current:** `sandbox/cao/src/cli_agent_orchestrator/providers/opencode.py` has no MCP SSE client logic. The `MCP_HOST` env var is set but nothing in CAO connects to it yet.

**Spec says:** Subagents must perform a full MCP handshake (connect → initialize → notifications/initialized → tools/call).

**Fix:** This is a future task. The `test-mcp-install/sse_test.py` is the reference implementation for a Python SSE client. When CAO needs to call MCP tools directly, port that pattern into a new module (e.g., `sandbox/cao/src/cli_agent_orchestrator/mcp/client.py`).

**Not blocking** — the current flow uses `docker mcp tools call` from the gateway container, which works for BATS tests. The SSE client is needed when subagents call tools programmatically.

---

## Execution Order

| # | File | Change | Risk |
|---|------|--------|------|
| 1 | `docker/mcp-gateway-entrypoint.sh` | Add `--enable-all-servers` | Low |
| 2 | `backend/pkg/relay/mcp.go` | Add `longLived: false` + top-level `name`/`displayName` to catalog YAML | Low |
| 3 | `tests/helpers/mcp.sh` | Switch to `name=value` syntax for mcp-add/find/remove | Low |
| 4 | `tests/integration/mcp/mcp-full-flow.bats` | Fix mcp-add call syntax, remove fallback | Low |
| 5 | `docker-compose.yml` | Add explicit `command` to mcp-gateway service (optional if #1 is done) | Medium |
| 6 | Future: CAO SSE client | Port `sse_test.py` pattern into CAO | Deferred |

---

## Validation

After applying changes 1-4:
```sh
# Rebuild gateway
docker compose build mcp-gateway

# Restart stack
docker compose up -d

# Run MCP integration tests
bats tests/integration/mcp/mcp-gateway.bats
bats tests/integration/mcp/mcp-full-flow.bats
```

The "MCP Infra: MCP Gateway spins up MCP server container via Dynamic MCP" test should now pass — the gateway will have `--enable-all-servers` and the test will use the correct `name=value` syntax for `mcp-add`.
