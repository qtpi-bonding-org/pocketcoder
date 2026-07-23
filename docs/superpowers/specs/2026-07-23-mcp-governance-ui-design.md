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

The simpler alternative — adding `goose` to `pocketcoder-tools` (where
`mcp-gateway` already sits alone today) instead of creating a new network —
was considered and rejected only for clarity of intent: a network named
`pocketcoder-tools` reads as "whatever else ends up here later," where a
dedicated `pocketcoder-mcp-gateway` network documents its one purpose and
doesn't implicitly grow scope for unrelated future services. Either
achieves identical isolation today; this is a naming/intent choice, not a
security difference.

**Accepted, not solved, by this network change:** `mcp-gateway` still
mounts `/var/run/docker.sock` read-only (`docker-compose.yml:100`) and
stays on `pocketcoder-docker` alongside PocketBase and the write-scoped
Docker socket proxy. A compromised gateway process retains host-level
Docker access regardless of which network carries goose↔gateway traffic —
this design does not change or reduce that exposure, it only adds `goose`
as a new peer able to reach the gateway's MCP port. That is the same
process-wide blast-radius tradeoff the ownership-map already accepted for
`config/extensions/add` and tool-permission writes being process-wide
rather than per-session (`ownership-map.md`'s Opus-review corrections,
point 5) — noted here explicitly rather than re-litigated.

### Component 3 — One-time gateway registration

New Go code, registered from `services/pocketbase/main.go`'s existing
`app.OnServe()` handler (`main.go:61`) — there is no other goose-health init
path in this codebase; `OnServe` plus the retry below is the concrete
trigger, not a placeholder for one:

1. **Gate on the agent profile being enabled at all.** `coordinator.New`
   already requires `GOOSE_ACP_URL`, `GOOSE_SERVER__SECRET_KEY`, and
   `GOOSE_WORKSPACE` to be set (`coordinator/run.go:111`) — check the same
   three env vars before attempting anything. If any are unset, the `agent`
   Compose profile isn't active (`docker-compose.yml:62` gates the whole
   `goose` service on it) and registration must skip silently, not retry
   against a container that will never exist.
2. If gated-in, call `AdminConn`, then `_goose/unstable/config/extensions/list`
   (or equivalent list call — confirm exact method name against
   `acp-meta.json` at plan-writing time) to check whether an extension
   named `gateway` already exists.
3. If absent, call `_goose/unstable/config/extensions/add` with the exact
   payload verified in the spike (`type: "http"`, name `gateway`, url
   `http://mcp-gateway:8811/mcp`).
4. Bounded retry with backoff (a handful of attempts over ~30-60s, matching
   the gateway's own restart timeout elsewhere in this design) if Goose is
   gated-in but not yet reachable — covers the real container-startup race
   between PocketBase's `OnServe` firing and `goose`'s healthcheck passing.
   Log and give up after the bound; do not block PocketBase startup on it.

**Plan must resolve:** `main.go` does not currently construct a
`*Coordinator` at startup — it's built inside `RegisterAgentApi`, per-request.
The plan needs to wire an accessible `Coordinator` (or just its `AdminConn`)
into this `OnServe` registration path; this is plumbing, not a design
decision, but it must be nailed down before implementation starts.

This runs once per PocketBase process lifetime (or is safely re-run on every
restart — the list-then-add check makes it idempotent either way). It is
the only place in the entire feature that calls `config/extensions/add`.

### Component 4 — `extensions` key dropped from render, tool permissions move to live delivery

Two files change together, not one:

- `services/pocketbase/internal/gooseconfig/config.go`:
  `RenderConfigYAML`/`ConfigInput` stops emitting the `extensions` key
  entirely — delete the `AvailableTools`-to-`extensions` block (`config.go:
  43-53`) and the `AvailableTools` field itself.
- `services/pocketbase/internal/hooks/goose_config.go`: `configInputFor`
  stops populating `AvailableTools` from `tool_permissions` rows
  (`goose_config.go:171-193`).

That deletion removes the **only existing mechanism** that delivers the
tool-permission allowlist to Goose today — confirmed by grep, nothing named
`tools/permissions/set` or `ToolPermissionApplier` exists anywhere in the
Go tree yet, and the foundations plan explicitly defers this
(`2026-07-22-agent-config-foundations.md:17`: *"Shrinking that pipeline
\[…\] is Bucket B/MCP-phase work, a separate plan"* — this spec is that
plan). So this spec must build a minimal replacement, not assume one:

- New: on the same hook events that currently trigger `renderGooseConfig`
  for `tool_permissions` changes (`RegisterGooseConfigHooks`'s
  `registerCrudHooks` loop, `goose_config.go:56`), also call
  `_goose/unstable/tools/permissions/set` over `AdminConn` with the
  resolved active-row allowlist — same resolution logic
  `configInputFor`/`RenderPermissions` already computes, just delivered
  live over ACP instead of baked into `config.yaml`.

  **Plan must resolve:** `RenderPermissions` returns a flat `[]string`
  allowlist scoped to the `developer` extension; `tools/permissions/set`'s
  actual param shape (likely per-tool `(tool, permission-level)` entries,
  not a flat list) has not been confirmed. The plan must verify the exact
  method name and param schema against `acp-meta.json`/`acp-schema.json`
  and design the allowlist→permissions-set mapping explicitly — do not
  assume the flat list can be passed through unchanged.

  The delivery mechanism itself mirrors the exact `CallExtension` pattern
  already proven at `profile.go:130` for `session/system-prompt/set`, and
  matches the ownership-map's own confirmation that `tools/permissions/set`
  is write-only, session-free, and process-wide (`ownership-map.md`'s
  Decisions section).
- This is deliberately scoped to *delivering what `tool_permissions` rows
  already produce* — it is not the separate "Tool-permissions UI" plan
  (editing screens, per-tool approval flows), which stays out of scope
  here per the original foundational-trio decomposition.

After both changes, Goose is the sole writer of `config.yaml`'s
`extensions` key for the lifetime of the process — no special-casing, no
partial-preserve-on-render logic — and tool-permission enforcement keeps
working, just delivered live instead of via boot-time file render. This
ordering matters: land the live delivery in the same change as the
`extensions` deletion, not after it, or there is a real window with no
tool-permission enforcement at all.

### Component 5 — approve/deny/revoke pipeline (unchanged), plus a required create hook

`hooks/mcp.go`'s existing `renderMcpConfig`/restart-on-status-change logic
(the render body itself) is validated as-is by the spike addendum — no
changes to what it renders or how. But its **trigger** is incomplete for
this spec's needs: `RegisterMcpHooks` binds only
`OnRecordAfterUpdateSuccess("mcp_servers")` (`hooks/mcp.go:44`) — there is
no create hook. The existing agent-request → human-approve flow never
needed one, because the agent creates a `pending` row
(`api/mcp.go:110`) and a human's approval is always an *update*. Component
6 breaks that assumption: it creates a row **already** `status: 'approved'`,
which fires `OnRecordAfterCreateSuccess` — nothing is bound to that event,
so a manually-added server would sit in the database and never reach the
gateway's catalog until an unrelated `mcp_servers` update or a PocketBase
restart. Fix, part of this spec: also bind
`app.OnRecordAfterCreateSuccess("mcp_servers")` to the same handler
function `renderAndRestart`/status-switch logic `OnRecordAfterUpdateSuccess`
already uses (extract the shared handler once, bind it to both events).

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
- Any UI or schema change to `tool_permissions` (a "Tool-permissions UI"
  plan — editing screens, per-tool approval flows — stays separate; this
  spec only changes *how* the already-existing rows are delivered to
  Goose, per Component 4). Skills, recipes, prompt templates, and the
  scheduler are untouched entirely (separate Bucket B plans per the
  ownership-map's "foundational trio" decomposition).
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
