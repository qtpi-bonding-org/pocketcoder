# MCP Governance UI — Design

## Problem

PocketCoder already has most of an MCP (Model Context Protocol) approval
workflow built: a `mcp_servers` PocketBase collection with a
request → approve/deny → revoke state machine, a Go hook
(`hooks/mcp.go`) that renders an approved-servers catalog and restarts the
`mcp-gateway` container, and a Flutter screen
(`McpManagementScreen`/`McpCubit`/`McpRepository`) that lists pending/active
servers and lets a human authorize or deny them. None of it has ever worked
end to end: Goose (`c2`) and the Docker MCP Gateway (`c3`) share no Docker
network, nothing ever registers the gateway as a Goose extension, and (as of
this spec) the gateway's transport mode is one Goose v1.43.0 explicitly
rejects. Approving a server today changes files nobody reads.

This spec closes that gap — wiring the existing pieces together so approval
actually reaches Goose — and adds the one missing piece of UI (manual
"add a server" — currently a TODO stub), without changing the governance
data model that's already correct.

## Prior research this spec builds on

- `spikes/goose-acp-config-surface/ownership-map.md` — the Bucket A/B/C/D
  ownership taxonomy. MCP servers are Bucket B with a required governance
  schema (Decision 1): PocketBase owns `requested_by/approved_by/approved_at/
  status/reason`; delivery to Goose was originally assumed to be direct
  per-server `config/extensions/add` calls.
- `docs/superpowers/plans/2026-07-22-agent-config-foundations.md` (in
  progress / being implemented separately) — adds
  `acp.Conn.CallExtension(ctx, method string, params any) (json.RawMessage,
  error)` and `func (c *Coordinator) AdminConn(ctx context.Context)
  (acp.Conn, error)`, a session-free connection to Goose for exactly this
  kind of Settings-style admin call. This spec's Go work depends on both
  existing (see Dependencies below).
- `spikes/goose-mcp-gateway-attach/README.md` — a spike run against the
  real, currently-pinned Goose v1.43.0 image and a real Docker MCP Gateway
  container, which overturned the ownership-map's delivery assumption and
  found the actual production blockers:
  1. Goose v1.43.0's `initialize` advertises `mcpCapabilities.sse: false`.
     Both attachment mechanisms (`session/new.mcpServers` and
     `config/extensions/add`) reject an `sse`-typed server with
     `"SSE is unsupported, migrate to streamable_http"`. The tracked
     `mcp-gateway` container launches with `--transport sse` — a dead end.
  2. The Docker MCP Gateway binary also supports `--transport streaming`,
     serving Streamable-HTTP MCP on `/mcp`. Pointing Goose at that URL with
     `type: "http"` works for both attachment mechanisms, confirmed all the
     way through a real model-invoked tool call
     (`gateway__mcp-find`) against a live gateway process.
  3. `_goose/unstable/config/extensions/add` is connection-scoped
     (session-free — confirmed by calling it before any session existed)
     and persists a real `extensions` entry to `config.yaml`
     (`type: streamable_http`).
  4. A same-spike addendum confirms the gateway's `--watch` flag
     (default `true`, undocumented scope) does **not** hot-reload catalog
     (`--catalog`) contents — tested directly, both an in-place edit and
     the exact atomic temp-file+rename pattern `hooks/mcp.go` already uses
     in production. Only a container restart makes catalog edits visible.
     The existing restart-on-approve step in `hooks/mcp.go` is therefore
     kept exactly as-is, not defensive dead weight.

These findings replace the ownership-map's original per-server delivery
assumption: **PocketCoder never calls `config/extensions/add` per MCP
server.** It is called exactly once, ever (idempotently), to register the
gateway itself. Individual server approval only ever changes the gateway's
own catalog file.

## Architecture

```
Flutter (approve / deny / add)
   │  PocketBase write to mcp_servers.status
   ▼
hooks/mcp.go (existing, unchanged logic)
   │  render docker-mcp.yaml + mcp.env from status='approved' rows
   │  restart mcp-gateway container
   ▼
mcp-gateway (c3)  ── NEW: --transport streaming, not --transport sse
   │  exposes gateway__mcp-find / gateway__mcp-add / etc.
   │  over Streamable-HTTP on :8811/mcp
   ▼  NEW: dedicated Docker network (goose ↔ mcp-gateway only)
goose (c2)
   registered once, at PocketBase startup, via:
   AdminConn → _goose/unstable/config/extensions/add
   { "extension": {"type":"mcp","server":{"type":"http",
     "name":"gateway","url":"http://mcp-gateway:8811/mcp"}}, "enabled": true }
```

Once registered, the gateway extension is permanent (Goose persists it to
`config.yaml`) and every Goose session automatically gets the gateway's
tools. Approving/denying/revoking a server never talks to Goose directly —
it only ever changes what the gateway's catalog contains, which is exactly
the "go through the gateway" shape that's already built and that this spec
makes actually work.

### Component 1 — Gateway transport switch

`docker-compose.yml`'s `mcp-gateway` service command line changes from
`--transport sse` to `--transport streaming`. The gateway then serves
`/mcp` instead of `/sse`; nothing else about its invocation changes
(`--catalog`, `--secrets`, `--enable-all-servers`, `--verbose`, `--log-calls`
all stay).

### Component 2 — Dedicated network

A new bridge network (`pocketcoder-mcp-gateway`) joins only `goose` and
`mcp-gateway`. `pocketcoder-agent` (documented in `docker-compose.yml` as
Goose's sole path to/from PocketBase, publishing no host port) is not
touched — `mcp-gateway` is never added to it, and `goose` keeps its existing
networks unchanged besides this one addition.

### Component 3 — One-time gateway registration

New Go code, added to whichever init path already runs after PocketBase
confirms Goose is healthy (see Task breakdown in the plan — this spec fixes
behavior, the plan fixes exact wiring point):

1. Call `AdminConn`, then `_goose/unstable/config/extensions/list` (or
   equivalent list call — confirm exact method name against
   `acp-meta.json` at plan-writing time) to check whether an extension
   named `gateway` already exists.
2. If absent, call `_goose/unstable/config/extensions/add` with the exact
   payload verified in the spike (`type: "http"`, name `gateway`, url
   `http://mcp-gateway:8811/mcp`).
3. Retry with backoff if Goose isn't reachable yet (same real risk the
   ownership-map already flagged for the `provider_keys`-triggered restart
   window — a Settings/init action landing mid-restart needs to not fail
   silently).

This runs once per PocketBase process lifetime (or is safely re-run on every
restart — the list-then-add check makes it idempotent either way). It is
the only place in the entire feature that calls `config/extensions/add`.

### Component 4 — `extensions` key dropped from `goose_config.go`

`gooseconfig.RenderConfigYAML`/`ConfigInput` stops emitting the
`extensions` key entirely. Today it's the only writer of that key, carrying
the tool-permission allowlist for the `developer` builtin extension
(`AvailableTools map[string][]string`). That allowlist moves to
`tools/permissions/set` (the delivery path the foundational
agent-config-foundations plan's `PerSessionApplier` already builds for tool
permissions — this spec does not duplicate that work, it removes the now-
redundant/conflicting `config.yaml` write). After this change, Goose is the
sole writer of `extensions` for the lifetime of the process — no
special-casing, no partial-preserve-on-render logic. This is a **hard
prerequisite**: without it, the next unrelated `poco_configs`/
`provider_keys`/`tool_permissions`/`harness_models`/`prompts` edit
(any of which currently triggers a full `renderGooseConfig` + restart)
overwrites `config.yaml` and wipes the gateway registration, which would
then have to be re-detected and re-added by Component 3 after every
unrelated Settings change — functionally fine (idempotent) but wasteful and
confusing to debug if left in place instead of fixed at the root.

### Component 5 — approve/deny/revoke pipeline (unchanged)

`hooks/mcp.go`'s `RegisterMcpHooks`/`renderMcpConfig`/restart-on-status-
change logic is validated as-is by the spike addendum — no code changes
needed here. Existing behavior: Flutter write → status change →
`renderMcpConfig` regenerates `docker-mcp.yaml`/`mcp.env` from all
`status='approved'` rows → `restartContainer(GatewayContainer, 30s)`.

### Component 6 — manual "ADD NEW" (new Flutter + one new repo method)

`McpManagementScreen`'s `ADD NEW` button currently does nothing
(`onTap: () {}`). It opens a new dialog collecting `name`, `image`
(optional — `hooks/mcp.go` already defaults to `mcp/<name>` if blank), and
optional config key/value pairs (reusing the existing
`_buildConfigSchemaList`/`TerminalTextField` pattern already built for the
authorize dialog). Submitting calls a new `IMcpRepository.createServer()`
method, which creates an `mcp_servers` row with `status: 'approved'`
directly — no pending state, since a human filling out the form from an
already-`role: admin` authenticated session is the approval. This is
consistent with the existing PocketBase rule
(`mcp_servers.CreateRule = "role = 'agent' || role = 'admin'"`) — no schema
or rule change needed, since the currently-signed-in human in a
single-owner PocketCoder deployment already holds `role: admin` (same rule
that already gates the existing `authorize`/`deny` actions).

## Data model

No schema changes. `mcp_servers` already has exactly the fields Decision 1
in the ownership-map called for
(`status`, `requested_by`, `approved_by`, `approved_at`, `reason`, `image`,
`config`, `config_schema`, `catalog`). One field,
`acp_transport` (`http`/`sse`/`stdio`, added by
`1748000100_acp_schema.go`), becomes unused by this design — it was added
under the original per-server-extension delivery assumption this spec
replaces. Leave it in place (removing a migrated field is unrelated churn);
do not populate or read it going forward.

## Error handling

- **Gateway registration retry**: Component 3's registration call is
  wrapped in a bounded retry (matches the existing restart-window risk
  already flagged for `provider_keys` edits in
  `spikes/goose-acp-config-surface/ownership-map.md`'s Opus-review
  corrections) — log and back off, don't crash PocketBase startup if Goose
  isn't up yet.
- **Gateway container restart mid-tool-call**: Streamable-HTTP is not a
  persistent connection the way SSE is; a tool call landing during the
  ~30s gateway restart window fails as a normal tool-call error surfaced to
  the model — no special handling needed, this is expected and matches how
  any transient tool failure already behaves.
- **Manual-add validation**: empty `name` is rejected client-side (existing
  `TerminalTextField` pattern); no server-side validation beyond the
  existing PocketBase field requirements (`name` required).

## Testing

Extend the existing `tests/agent-c1` bats suite (`docker-compose.agent-test.
yml`) with an MCP-gateway scenario:

1. Bring up `goose` + `mcp-gateway` (streaming transport, new dedicated
   network) + PocketBase.
2. Assert the gateway extension is registered exactly once across two
   PocketBase restarts (idempotency — query `config/extensions/list` via a
   test-only admin-conn helper, or assert via Goose's `config.yaml` inside
   the shared volume).
3. Approve a test server via the existing `/api/pocketcoder/mcp_request`-
   adjacent flow (direct PocketBase record write, matching how
   `McpRepository.authorizeServer` does it).
4. Assert the rendered `docker-mcp.yaml` contains the approved server and
   the gateway container restarted.
5. Assert `gateway__mcp-find` is reachable through a real ACP `tools/list`
   call and returns the approved server — the same proof shape the spike
   already used, made permanent as a regression test.

Flutter: cubit/repository unit tests for `createServer()` following the
existing `authorize`/`deny` test pattern (check for
`test/application/mcp/` or `test/infrastructure/mcp/` at plan-writing time
for the exact existing test file to extend).

## Out of scope

- Hot-reload of the gateway catalog without a restart (spike confirmed
  `--watch` doesn't cover this; not revisited).
- A visual catalog browser for discovering available MCP servers before
  requesting them (the agent's own `gateway__mcp-find`/`mcp_request` flow
  already covers agent-initiated discovery; a human browsing the Docker MCP
  catalog from Flutter is a separate, later feature if wanted).
- Any change to `tool_permissions`, skills, recipes, prompt templates, or
  the scheduler (separate Bucket B plans per the ownership-map's
  "foundational trio" decomposition).
- Removing the unused `acp_transport` field from `mcp_servers`.

## Dependencies

This spec's Go work (Component 3) requires `AdminConn` and `CallExtension`,
both added by `docs/superpowers/plans/2026-07-22-agent-config-foundations.md`
(Tasks 1–2). **Confirmed already landed** as of this spec
(`services/pocketbase/internal/agent/coordinator/admin.go` exists;
`feat(agent): add Coordinator.AdminConn for session-free Goose calls` and
`feat(agent): expose CallExtension on the coordinator's ACP Conn interface`
are on this branch) — the implementation plan for this spec can build on
them directly, no waiting or duplication needed.
