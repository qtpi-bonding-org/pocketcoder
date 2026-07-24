# cognee-mcp transport spike

Disposable spike confirming whether `cognee/cognee-mcp:main` is reachable
cross-container as a Goose-compatible MCP transport, per
`docs/superpowers/plans/2026-07-24-cognee-agent-memory.md` Task 1.

## What it proves

1. What cognee-mcp needs in its environment to boot at all (as distinct from
   a transport-layer failure that would look the same from the outside).
2. Whether cognee-mcp's `--transport http` mode (selected via the
   `TRANSPORT_MODE` env var — see below) implements genuine **MCP Streamable
   HTTP**, not SSE mislabeled as HTTP. This matters because Goose v1.43.0
   hard-rejects `sse`-typed MCP servers outright (`spikes/goose-mcp-gateway-attach/README.md`)
   — SSE is not a valid fallback if HTTP doesn't work cleanly.
3. Whether cognee-mcp's DNS-rebinding Host-header allowlist (flagged as a
   likely blocker in the design spec, §3.1) can be widened for cross-container
   access, and how.

## Method

Real containers, no ad-hoc guessing: `cognee/cognee-mcp:main` run directly
(then reproduced via `docker-compose.override.yml` in this directory) on a
disposable bridge network, queried from a second `curlimages/curl` container
on the same network — mirroring `spikes/goose-mcp-gateway-attach/README.md`'s
methodology (real containers, a git-tracked disposable directory, cleaned up
after).

## Result — 2026-07-24

**TRANSPORT: http** (genuine MCP Streamable HTTP — confirmed).

### Step 1 — boot requirements

`docker run --rm cognee/cognee-mcp:main --help` shows a real CLI
(`cognee-mcp [--transport {sse,stdio,http}] [--host] [--port] [--path] ...`),
but **the image's `/app/entrypoint.sh` does not forward `--transport` as a
CLI flag from `command:`/`docker run` args verbatim** — it reads its own
`TRANSPORT_MODE` (default `stdio`) and `HTTP_PORT` (default `8000`) env vars,
and *appends* `--host 0.0.0.0 --port $HTTP_PORT --transport $TRANSPORT_MODE`
to argv **after** whatever was passed at the command line. Since argparse
takes the last occurrence of a repeated flag, passing `--transport http` as a
`command:` arg is silently overridden back to `stdio` by the entrypoint's own
default. **The only correct way to select HTTP mode is the `TRANSPORT_MODE=http`
env var** (plus `HTTP_PORT` if not 8000) — not a `--transport` CLI arg.

Confirmed by testing: the container boots and completes DB migrations/auth
setup with **no `LLM_API_KEY` or embedding vars set at all** — those are only
consumed lazily by actual `remember`/`recall` tool calls, not at boot or by
the MCP `initialize` handshake. For a real deployment they'll still need to
be set (per spec §3.4, local-only embeddings), but they are not a precondition
for the transport question this spike answers.

### Step 2/3 — reachability

With `TRANSPORT_MODE=http`, `HTTP_PORT=8000`, cognee-mcp logs:
```
Running MCP server with Streamable HTTP transport on 0.0.0.0:8000/mcp
...
StreamableHTTP session manager started
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```
i.e. it binds `0.0.0.0` by default (via the entrypoint's own `--host
0.0.0.0`) — no separate bind-address flag was needed.

A same-network `curl POST /mcp` at this point returned **HTTP 421
"Invalid Host header"** — the DNS-rebinding-protection allowlist flagged as a
likely blocker in the design spec (§3.1). Traced to
`mcp/server/transport_security.py` (upstream `mcp` SDK,
`TransportSecurityMiddleware`) and cognee's own `src/server.py`, which reads
a `MCP_ALLOWED_HOSTS` (comma-separated) env var and folds it into the
allowlist alongside a fixed localhost set. Setting
`MCP_ALLOWED_HOSTS=cognee-spike:8000` (the container's own network alias:port)
resolved it immediately.

### Step 4 — diagnosis

With `MCP_ALLOWED_HOSTS` set, a raw JSON-RPC `initialize` POST returns a
genuine **200 OK**, `content-type: text/event-stream`, a real
`mcp-session-id` header, and a correctly-shaped JSON-RPC response body
framed as a Streamable HTTP `event: message` SSE-style chunk (this framing —
a `text/event-stream` response to a POST — **is** the Streamable HTTP spec's
own shape, not a sign of "actually SSE"; MCP's plain-SSE legacy transport is
a *separate*, two-endpoint (`GET /sse` + `POST /messages`) dialect that
cognee-mcp's `sse` mode would use instead, and was not exercised here). A
full handshake with real `protocolVersion`/`capabilities`/`clientInfo`
params returned:
```json
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18","capabilities":{"experimental":{},"prompts":{"listChanged":false},"resources":{"subscribe":false,"listChanged":false},"tools":{"listChanged":false}},"serverInfo":{"name":"Cognee","version":"1.28.1"}}}
```
This is unambiguously genuine MCP Streamable HTTP, matching what Goose
v1.43.0 requires per the gateway spike's prior finding.

### Headline finding

- **TRANSPORT: http**
- **PORT: 8000**
- **FLAGS_REQUIRED (env vars, not CLI flags):**
  - `TRANSPORT_MODE=http` (selects HTTP mode — do not rely on a `--transport`
    CLI arg, it gets overridden by the entrypoint)
  - `HTTP_PORT=8000` (optional — this is already the default, spelled out
    here since `TRANSPORT_MODE` needs setting anyway)
  - `MCP_ALLOWED_HOSTS=cognee:8000` (the tracked compose file's service name)
    — required to defeat the DNS-rebinding Host-header check; without it every
    request 421s regardless of transport correctness
- **MIN_ENV_TO_BOOT:** none of the above are strictly required just to boot
  (defaults to `stdio` with no reachability) — `TRANSPORT_MODE` +
  `MCP_ALLOWED_HOSTS` are required specifically for cross-container HTTP
  reachability, not for the process to start. No `LLM_API_KEY` or embedding
  env var is required for boot or for the MCP `initialize` handshake.
- **IMAGE_TAG_USED_FOR_SPIKE:** `cognee/cognee-mcp:main`

See `docs/superpowers/plans/2026-07-24-cognee-transport-decision.md` for the
canonical decision record consumed by Task 3/6.

## Addendum — persistence + permissions (found during Task 7's SQLPage spike)

Two additional findings, discovered while verifying Task 7's SQLPage
attachment against a real running container (not part of the original
transport question, but block cross-container *persistence*, so recorded
here rather than opening a third spike directory):

1. **cognee does not write into the mounted `cognee_data` volume by
   default.** Its own config (`cognee/base_config.py`, a pydantic
   `BaseSettings`) defaults `data_root_directory`/`system_root_directory` to
   paths baked into the image (`~/.data_storage`, `~/.cognee_system`), not
   `/cognee_data`. Without setting `DATA_ROOT_DIRECTORY=/cognee_data/data`
   and `SYSTEM_ROOT_DIRECTORY=/cognee_data/system` (env vars, case-insensitive
   pydantic-settings match), the volume mount is a no-op — nothing persists,
   and SQLPage's read-only mount has nothing to read.
2. **The volume needs to be pre-owned by uid/gid 1000.** cognee-mcp's image
   runs as a non-root `cognee` user (uid/gid 1000:1000) by default. Docker
   creates a fresh named volume root-owned, so cognee's first write crashes
   with `PermissionError: [Errno 13] Permission denied: '/cognee_data/system'`.
   Fixed in `docker-compose.yml` with a one-shot `cognee-data-init` (`busybox
   chown -R 1000:1000 /cognee_data`) that `cognee` depends on via
   `condition: service_completed_successfully`.
3. **The real relational SQLite file is `/cognee_data/system/databases/cognee_db`**
   (no `.db` extension) once the above two are fixed — confirmed via
   `sqlite3 .tables` against a live container: `data`, `datasets`, `nodes`,
   `edges`, `queries`, `results`, and others. `data` (columns include `name`,
   `mime_type`, `token_count`, `data_size`, `created_at`) is the table that
   holds each ingested memory item — used by `services/sqlpage/dashboard/memory.sql`.
   cognee's `remember` tool without a `session_id` needs a real `LLM_API_KEY`
   to complete its add+cognify pipeline (confirmed: fails with
   `LLMAPIKeyNotSetError` on a placeholder key) — out of scope for this
   spike, but noted since it's why the `data` table was still empty when this
   was checked with a placeholder key.

All three verified against `cognee/cognee-mcp:main` directly (`docker run`,
not this directory's compose override), then re-verified end-to-end against
the real tracked `docker-compose.yml`'s `cognee`/`cognee-data-init` services.

## Cleanup

```bash
docker compose -f docker-compose.override.yml down -v
docker network rm cognee-spike-net   # if created outside compose during manual testing
```
