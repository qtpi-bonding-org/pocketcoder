# Legacy Runtime Prune — Design Spec

**Date:** 2026-07-18
**Status:** design, pending review
**Supersedes sequencing in:** `docs/superpowers/plans/2026-07-16-pocketbase-goose-legacy-prune.md`
(that plan assumed Flutter cutover *before* the prune; we are pruning *first*).
Dependency evidence: `docs/superpowers/plans/2026-07-17-legacy-runtime-dependency-inventory.md`.

## Goal

Reduce the repository to a clean c1/c2 base before the Flutter AG-UI client is
built: delete the dead OpenCode/Interface runtime, the abandoned knowledge
stack, and the PocketBase collections that duplicate Goose-owned turn state.
This is a **backend + services + infra deletion pass**. It is not a refactor and
it adds no features.

## Architecture context

- **c1** = `pocketbase` (auth, chat ownership/title, the `goose_sessions`
  mapping, the AG-UI bridge in `internal/agent/*` + `internal/api/agent.go`).
- **c2** = `goose` (the agent; ACP over authenticated WebSocket).
- **c3** = `mcp-gateway` (Docker MCP Gateway + Cognee) — dormant, kept, profiled.

Goose is configured entirely on the c2 side (env + Goose recipes). PocketBase
holds **no** agent turn-state for a Goose-backed chat; `goose_sessions` is the
only durable c1 runtime record (per migration `1748000500`).

## Global constraints

- **Forward-only migrations.** Never edit an applied migration. Schema cleanup
  is one new migration, modelled on the existing precedent
  `services/pocketbase/pb_migrations/1748000400_drop_unused_fields.go`.
- **Loud errors, no guards.** Where a *kept* code path still references a
  removed collection/field (cron; the agent-definition config hooks), leave it
  untouched so it fails loudly on use. Do **not** add existence guards or
  no-ops. The only edits to kept code are removing now-dead **startup hook
  bindings** that reference deleted collections (`notifications.go`,
  `timestamps.go`). In PocketBase v0.36 these bind lazily by collection tag, so
  they would not panic at boot — but they are dead references to dropped
  collections and are removed as cleanup, before the migration drops them.
- **Pre-launch.** No users, no data to preserve. Deleting any existing legacy
  records is acceptable; no retention window, no rollback window, no dual runtime.

## Target end state — services

Plain `docker compose up` (no profile) must boot exactly three services:
`pocketbase`, `docker-socket-proxy-write`, `sqlpage`. Everything else is opt-in.

| Service | Role | Boot |
|---|---|---|
| `pocketbase` | c1 backend | default |
| `docker-socket-proxy-write` | hardened socket proxy for c1 container control | default |
| `sqlpage` | observability dashboard over `pb_data` | default |
| `goose` | c2 agent | `agent` profile |
| `mcp-gateway` | c3 (MCP Gateway + Cognee) | **`c3` profile (newly added)** |
| `tailscale` | remote access | `tailscale` profile |
| `caddy` | auto-HTTPS reverse proxy | `caddy` profile |
| `ntfy` | optional self-hosted push backend | `foss` profile |

## Scope

### A. Delete — services and their build contexts

Remove these compose services and delete their `services/<name>/` directories
(build contexts): `interface`, `sandbox`, `surrealdb`, `open-notebook`,
`open-notebook-mcp`, `poco-memory`. There is no standalone `opencode` compose
service — OpenCode ran inside `interface`/`sandbox`; also delete the
`services/opencode/`, `services/interface/`, and `services/poco-memory/`
directories (the other knowledge services are image-based, no build context).

Delete the legacy override `docker-compose.test.yml` — its `test` service
depends on the removed `sandbox`/`opencode` and would otherwise break
`docker compose -f docker-compose.yml -f docker-compose.test.yml config`.
`docker-compose.agent-test.yml` is the live replacement.

Fix the vestigial `depends_on: sandbox` gate on `sqlpage` (sandbox is gone).

**Orphaned after removal (delete their definitions too):**
- Volumes: `shell_bridge`, `notebook_data`, `surrealdb_data`, `fastembed_cache`.
- Networks: `pocketcoder-control`, `pocketcoder-knowledge`.
- Keep: `opencode_workspace` (misnamed but still mounted by pocketbase + goose),
  `pocketcoder-tools` (retained for the kept `mcp-gateway`), `pb_data`,
  `goose_data`, `llm_keys`, `pocketcoder-logs`, `ntfy-*`, `caddy_*`,
  `tailscale_state`.

Add a `profiles: ["c3"]` key to `mcp-gateway` so it stops booting by default.

### B. Delete — collections and fields (one forward-only migration)

New migration `services/pocketbase/pb_migrations/1752000000_prune_legacy_runtime.go`:
- Drop collections: `messages`, `permissions`, `acp_terminals`.
- Drop `chats` fields (and their indexes): `acp_session_id`, `engine_type`,
  `ai_engine_session_id`.

Retained legacy-adjacent collections (out of scope — agent-definition revamp):
`ai_prompts`, `ai_models`, `ai_agents`, `sandbox_agents`, `poco_configs`,
`harnesses`, `models`, `harness_models`, `prompts`, `skills`, `provider_keys`,
`tool_permissions`. Retained config: `mcp_servers` (c3 catalog), `cron_jobs`,
`ssh_keys`, `notification_rules`, `devices`, `proposals`, `sops`.

### C. Delete — backend Go (dead legacy)

- `services/pocketbase/internal/api/permission.go` (old OpenCode "Authority"
  permission evaluator, writes `permissions`).
- `services/pocketbase/internal/hooks/permissions.go` (only touches `permissions`).
- Their registration sites (wherever these routes/hooks are wired into the
  PocketBase bootstrap).

### D. Trim — backend Go (required only to keep PocketBase booting)

These are the sole edits to kept code, because they bind hooks at **startup** to
now-deleted collections:
- `internal/hooks/notifications.go`: remove the
  `OnRecordAfterCreateSuccess("permissions")` draft→push trigger. Keep the
  device/rule/presence push stack and `/api/push` intact.
- `internal/hooks/timestamps.go`: remove `messages`, `permissions`,
  `acp_terminals` from its hardcoded collection list.

### E. Delete — legacy backend tests

`tests/integration/agent/*`, `tests/integration/mcp/mcp-full-flow.bats`,
`tests/integration/auth/permission-gating.bats`, `tests/connection/*opencode*`,
`tests/health/opencode.bats`. Replacement coverage already lives in
`tests/agent-c1/` and `internal/agent/*`.

### F. Clean — env template

`.env.template`: remove the OpenCode-era keys (`POCO_AGENT`, `POCO_AGENT_CMD`,
`ENABLE_GO_RELAY`, `GEMINI_API_KEY`, `OPENCODE_*`, `OPEN_NOTEBOOK_ENCRYPTION_KEY`)
and any knowledge-stack vars. Keep the goose/agent section added on 2026-07-17.

## Known consequences (intended, loud)

These are *kept* code paths left deliberately unrepaired so they fail loudly;
their repair is a named follow-up, not this prune:

1. **Cron is non-functional until its rewire.** `hooks/cron.go` writes to the
   deleted `messages` collection and `api/cron.go::resolveHumanUser` reads the
   deleted `chats.ai_engine_session_id`. A firing cron job or a cron API call
   will error loudly. PocketBase still **boots** (cron callbacks only run on
   fire; the API filter only runs on request). Fixed by the *cron-on-c1* follow-up.
2. **Agent-definition config hooks error if the config UI is used.**
   `hooks/agents.go`, `hooks/llm.go`, `hooks/tool_permissions.go` render config
   files and then restart the removed `pocketcoder-interface` container (via
   `helpers.go`'s `PocoContainer`). Editing an agent-config record will render
   harmlessly to `/workspace/.opencode/` and then error on the missing-container
   restart. Left as-is by choice; repaired in the *agent-definition revamp*.

## Non-goals (explicit follow-ups, not this prune)

- **Flutter AG-UI rebuild** — including deleting the legacy Flutter runtime
  (`infrastructure/hitl/*`, `communication_daos.dart`, permission/chat cubits),
  the Dart model regeneration, and the `pb_schema.json` re-export. The Flutter
  package is **not touched** by this prune; it will fail against the pruned
  backend until the rebuild, which is the immediate next project.
- **Cron-on-c1 rewire** (make a firing cron trigger a c1 run).
- **Agent-definition revamp** (redesign around Goose recipes).
- **c3 / Cognee enablement.**

## Verification

1. `cd services/pocketbase && go build ./... && go test ./...` — green.
2. PocketBase **boots** cleanly (no startup hook binds to a missing collection).
   Bring it up and hit `/api/health`.
3. Default `docker compose up` boots exactly `pocketbase`,
   `docker-socket-proxy-write`, `sqlpage` — nothing else.
4. `docker compose config` validates for the base and for each profile
   (`agent`, `c3`, `tailscale`, `caddy`, `foss`, `agent-test`).
5. The `agent` profile still passes the `live_acp` coordinator test and the
   `tests/agent-c1` suite wiring (auth + turn + 401).
6. Repo-wide grep finds no remaining reference to any deleted service, volume,
   network, collection, or field (outside historical docs/migrations).

## Ordering

1. Delete dead Go (C) + trim boot-critical Go (D) — so the binary no longer
   references the collections about to be dropped at startup.
2. Add the forward-only migration (B).
3. Remove services + orphaned volumes/networks + service dirs (A), profile
   `mcp-gateway`, clean `.env.template` (F), delete legacy tests (E).
4. Run verification. Each step is independently committable.
