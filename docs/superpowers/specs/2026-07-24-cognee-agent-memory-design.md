# cognee Agent Memory — Design Spec

**Date:** 2026-07-24
**Status:** DESIGN — approved for planning.
**Supersedes:** `docs/superpowers/plans/2026-07-14-memory-stack-simplification.md` (targeted the since-deleted `services/interface` container; that plan is stale and will be deleted as part of this work — see Task in the implementation plan).
**Grounded against:** `docker-compose.yml`, `services/pocketbase/internal/hooks/{mcp_gateway.go,goose_config.go,mcp.go}`, `services/pocketbase/internal/gooseconfig/config.go`, `services/pocketbase/pb_migrations/schema.json` (`mcp_servers`, `poco_configs`, `provider_keys` collections), `services/sqlpage/dashboard/{index.sql,config/on_connect.sql}`.

---

## 1. Why this exists

The original memory-simplification plan (2026-07-14) replaced the custom `poco-memory` Rust/SurrealDB MCP server with [cognee](https://github.com/topoteretes/cognee) — an embedded-by-default (SQLite + LanceDB, no external DB services), actively-maintained FOSS agent-memory project that ships a native MCP server (`cognee-mcp`, stdio/SSE/HTTP). That plan was written against the OpenCode-era `services/interface` container (Bun/TS, `command-pump.ts`/`event-pump.ts`, spawning ACP agents directly). That container, and `poco-memory`/`open-notebook`/`open-notebook-mcp`/`surrealdb`, are already fully removed — replaced by the Goose/ACP/AG-UI architecture (`services/goose` + `services/pocketbase/internal/agent/{coordinator,agui,executor,acp}`).

This spec re-derives where cognee plugs into the *current* architecture, so the underlying goal (persistent, queryable agent memory) isn't dropped along with the container it was originally designed for.

## 2. Current state (grounded)

**Two independent MCP-wiring paths already exist**, and it matters which one a new server follows:

- **Docker MCP Gateway catalog path**: the `mcp_servers` PocketBase collection (`name`, `status` [pending/approved/denied/revoked], `config`, `catalog`, `acp_transport`, etc.) drives `hooks/mcp.go`'s `renderMcpConfig`, which writes `/mcp_config/docker-mcp.yaml` + `mcp.env` and restarts the `mcp-gateway` container (Docker's own `mcp-gateway` binary, `docker-compose.yml`'s `mcp-gateway` service, profile `c3`). All *approved* catalog servers are proxied through **one** Goose extension named `"gateway"`, registered once by `hooks/mcp_gateway.go`'s `RegisterMcpGatewayExtension`.
- **Direct ACP live-registration path**: `mcp_gateway.go` itself is the only current example — a one-time, idempotent, retrying call to Goose's `_goose/unstable/config/extensions/add` RPC. This is how a standalone (non-catalog) MCP server gets registered as its own named extension.

`gooseconfig/config.go`'s `RenderConfigYAML` **deliberately never writes an `extensions:` key** to `config.yaml` — its doc comment states Goose is the sole writer of that key (Goose persists live-registered extensions back into the file itself), so anything hand-written there risks being clobbered or drifting.

cognee is not a Docker-MCP-catalog server, so it does not belong on the `mcp_servers`/gateway path — it follows the direct ACP live-registration path instead, as its own named extension, independent of the gateway.

**SQLPage today**: `services/sqlpage/dashboard/{index.sql,config/on_connect.sql}` already establishes the `ATTACH DATABASE` pattern (`ATTACH DATABASE '/database/opencode/opencode.db' AS opencode;`) for querying a second SQLite file alongside PocketBase's own `pb_data`. **Note:** this existing attachment is itself OpenCode-era dead code — `docker-compose.yml`'s `sqlpage` service doesn't mount anything at `/database/opencode`, and `index.sql` queries a `messages` table that no longer exists. This is a pre-existing bug, out of scope here — cognee's dashboard addition is written standalone and does not depend on the broken opencode attachment or its queries.

## 3. Architecture

### 3.1 cognee as its own service

`cognee` becomes a new `docker-compose.yml` service running `cognee-mcp` over HTTP, **not** a sibling process inside another container (there is no `interface` container left to be a sibling of). It gets:

- A new `cognee_data` named volume (SQLite + LanceDB + Kuzu files — cognee's embedded storage).
- A new dedicated network, `pocketcoder-cognee`, shared only by `goose` and `cognee` — mirroring the existing `pocketcoder-mcp-gateway` network's isolation rationale ("carries MCP traffic between Goose and X only, deliberately separate from `pocketcoder-agent` so this addition doesn't touch [PocketBase's sole path to/from Goose]"). `pocketcoder-agent` stays untouched.

### 3.2 Registration: direct ACP live-registration

A new hook, `services/pocketbase/internal/hooks/cognee_extension.go`, copies the shape of `mcp_gateway.go`: on PocketBase startup (`go`-launched from `main.go`'s `OnServe` handler, never blocking startup), in a bounded retry loop, call `_goose/unstable/config/extensions/list` then (if absent) `_goose/unstable/config/extensions/add` to register a `"cognee"` extension (`type: "mcp"`, `server.type: "http"`) pointed at `http://cognee:<port>/mcp`. Same skip-if-agent-profile-unconfigured guard (`GOOSE_ACP_URL`/`GOOSE_SERVER__SECRET_KEY`/`GOOSE_WORKSPACE`) as the gateway registration. `gooseconfig`'s "Goose owns `extensions:`" invariant is preserved — no static entry added to `config.yaml`.

### 3.3 Recall and storage: fully agentic, no new prompt-plumbing

Once registered, cognee's MCP tools (store/search) are just more tools in Goose's normal tool-calling loop — identical in kind to the gateway's proxied tools. Goose (the model) decides when to call them, same as any other extension. This deliberately drops the old plan's Task 2 (`command-pump.ts`/`event-pump.ts` manually injecting recalled memories before every prompt) — that mechanism doesn't exist in the current architecture, and forcing recall on every turn would require new coordinator-level plumbing with no current hook point, for no clear benefit over letting the agent decide.

### 3.4 Providers: LLM reuse (open question) + local embeddings (decided)

cognee needs two providers: an LLM for its knowledge-graph extraction step, and an embedder for the vector-search side.

- **Embeddings: local/self-hosted model, hardcoded, not admin-configurable.** No new API key required. This is a firm decision, not left open.
- **LLM: attempt to reuse the existing MiniMax-via-Anthropic-compatible credentials** (`ANTHROPIC_API_KEY`/`ANTHROPIC_HOST`) via cognee's LiteLLM-based provider config. **Open question, to verify during implementation** against cognee's actual documentation/behavior — MiniMax-via-Anthropic-compat may or may not be supported by cognee's LiteLLM integration. If unsupported, fall back to either a local LLM or a separate minimal-cost provider key — this decision is deferred to implementation, not resolved here.

### 3.5 Admin-configurable cognee model settings

A new collection, **`cognee_config`** (single global settings record; admin-only write, matching `poco_configs`' access pattern): `llm_provider` (text, e.g. `"anthropic"`), `llm_model` (text), `llm_base_url` (text, optional — needed for MiniMax's Anthropic-compatible endpoint), `llm_api_key` (text). Embedding provider/model is **not** a field here — it stays hardcoded per §3.4.

A new hook, `services/pocketbase/internal/hooks/cognee_config.go`, mirrors `RegisterGooseConfigHooks`: CRUD-bound on `cognee_config` (plus an initial render on serve startup), renders a `cognee.env` file into a new `cognee_config` volume, then restarts the `cognee` container via the existing `renderAndRestart` helper. With no `cognee_config` row present, `cognee` falls back to whatever's baked into its own Dockerfile/compose defaults — same fallback shape as Goose running on compose-env defaults with no `poco_config`.

### 3.6 open-notebook

Stays dropped. Already fully removed from `docker-compose.yml` and `services/` — no action needed, just confirming it is not being resurrected as part of this work.

### 3.7 SQLPage visibility

- `cognee_data` mounted read-only into the `sqlpage` service (`cognee_data:/cognee_data:ro`).
- A new `on_connect.sql` entry: `ATTACH DATABASE '/cognee_data/cognee.db' AS cognee;` (additive — does not touch or fix the existing broken `opencode` attachment).
- A new `services/sqlpage/dashboard/memory.sql` page listing recent memories / knowledge-graph entries from `cognee.*` tables. Written standalone; does not join against or depend on the broken `messages`/`opencode.*` queries in `index.sql`.

## 4. File map

### New files
- `services/pocketbase/internal/hooks/cognee_extension.go` — one-time idempotent ACP live-registration of the `"cognee"` Goose extension (mirrors `mcp_gateway.go`).
- `services/pocketbase/internal/hooks/cognee_config.go` — CRUD hooks rendering `cognee.env` from the `cognee_config` collection (mirrors `goose_config.go`).
- `services/sqlpage/dashboard/memory.sql` — dashboard page for cognee memories.
- New PocketBase collection `cognee_config` (added to `services/pocketbase/pb_migrations/schema.json` per this repo's schema-editing convention — see root `CLAUDE.md`).

### Modified files
- `docker-compose.yml`:
  - Add `cognee` service (build or pull `cognee-mcp`, HTTP transport, `cognee_data` volume, `pocketcoder-cognee` network, `cognee_config` volume for `cognee.env`).
  - Add `cognee_data` and `cognee_config` named volumes.
  - Add `pocketcoder-cognee` network.
  - Add `pocketcoder-cognee` to `goose`'s `networks:` list.
  - Mount `cognee_data:/cognee_data:ro` into `sqlpage`.
- `services/sqlpage/dashboard/config/on_connect.sql` — add the cognee `ATTACH DATABASE` line.
- `main.go` — launch `RegisterCogneeExtension`/`RegisterCogneeConfigHooks` alongside the existing `RegisterMcpGatewayExtension`/`RegisterGooseConfigHooks` calls.
- Root `CLAUDE.md` — no change needed (the "exactly two migration files" convention already covers adding `cognee_config` to `schema.json`).

### Deleted files
- `docs/superpowers/plans/2026-07-14-memory-stack-simplification.md` — superseded by this spec; its file map/tasks target the deleted `interface` container and are no longer executable as written.

## 5. Out of scope

- Fixing the pre-existing broken `opencode` SQLite attachment / `messages`-table query in `services/sqlpage/dashboard/index.sql` — a separate, unrelated cleanup item, flagged here for visibility only.
- Any UI (Flutter) surface for browsing memories — SQLPage's `memory.sql` is the only visibility surface this spec adds.
- Resolving the cognee-LLM-provider open question (§3.4) — deferred to implementation.
