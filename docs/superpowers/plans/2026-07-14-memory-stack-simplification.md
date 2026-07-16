# Memory Stack Simplification: cognee replaces poco-memory (+ open-notebook)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the custom-built `poco-memory` Rust MCP server (and its `surrealdb` dependency) with [cognee](https://github.com/topoteretes/cognee), an actively-maintained FOSS agent-memory project that speaks MCP natively. Stop maintaining a homegrown memory engine. Fold the memory process into the `interface` container as a sibling process rather than giving it its own container. Decide the fate of `open-notebook` (recommendation: drop it — see Decision below).

**Why cognee, not the alternatives:** researched mem0, Zep/Graphiti, Letta, cognee, and agentmemory. mem0/Zep/Letta all still require a real external DB (Postgres+pgvector and/or Neo4j) — not actually lighter than the current SurrealDB-based setup, just a different DB vendor. cognee runs embedded by default (SQLite + LanceDB, zero external DB services) and ships a first-class MCP server (`cognee-mcp`) supporting stdio/SSE/HTTP. agentmemory is lighter still but is a very new, marketing-heavy project without cognee's track record (27.8k stars, Apache-2.0, commits daily) — not worth the risk yet.

**Tech stack change:** `cognee-mcp` is Python (CPython), not embeddable into the Bun/TS `interface` binary in-process — cognee ships no PyInstaller/compiled-artifact packaging, and even cognee's own official TS client (`@cognee/cognee-ts`) is just a thin HTTP wrapper around a separately-running Python process. So "fuse into interface" means: same container, sibling OS process, called over local MCP/HTTP — the same pattern already used for `proxy`+`poco-agents` inside `sandbox`.

---

## Decision: drop `open-notebook`?

**Recommendation: yes, drop it**, unless you're actually using its UI or podcast-generation features day to day. Reasoning:
- It requires SurrealDB as a dependency purely for itself once `poco-memory` no longer needs SurrealDB.
- cognee already does document ingestion + knowledge-graph recall, which covers "agent queries a knowledge base" — the part that actually matters for an AI coding agent.
- What you'd lose: open-notebook's NotebookLM-style UI, podcast generation, and multi-format ingestion polish. If you (a human) actually open that UI regularly, keep it standalone and skip Task 4 below.

This plan assumes the drop. If you want to keep `open-notebook`, skip Task 4 and keep `surrealdb` + `open-notebook` in the compose file (drop only `open-notebook-mcp`, since cognee replaces its bridging role too).

---

## Background: what LanceDB is, and how to see the SQL memories

**LanceDB** is an embedded, serverless vector database — think "SQLite, but for embeddings." It stores vector data in a columnar file format directly on local disk, with no separate server process to run or manage. This is *why* cognee's default/embedded mode needs zero external DB containers: relational data goes in a plain SQLite file, vectors go in a LanceDB directory, and (if graph features are used) a Kuzu graph DB file — all just files on a mounted volume, not services.

**Seeing the memories via SQLPage:** since cognee's relational store is SQLite, and SQLPage already talks to a SQLite file (PocketBase's `pb_data`), you don't need a second SQLPage instance or a dual-datasource config — SQLite supports attaching a second database file to one connection. Add an `on_connect.sql` to SQLPage's config that runs `ATTACH DATABASE '/cognee_data/cognee.db' AS cognee;` on every connection, then write dashboard queries that reference `cognee.<table>` alongside PocketBase's own tables. One SQLPage container, two data sources, queryable together (e.g. join a PocketBase chat record with the cognee memories it produced).

---

## File Map

### New files
- `services/interface/entrypoint.sh` — starts `bun src/index.ts` and `cognee-mcp` (or the `cognee` HTTP server) as sibling processes, with the same PID-watchdog/restart-on-death pattern used in `services/sandbox/entrypoint.sh`.
- `services/sqlpage/config/on_connect.sql` — `ATTACH DATABASE` statement bringing cognee's SQLite file into every SQLPage connection.
- `services/sqlpage/dashboard/memory.sql` — a dashboard page querying `cognee.*` tables (and joins against PocketBase records where useful).

### Modified files
- `services/interface/Dockerfile` — add a Python runtime + `cognee`/`cognee-mcp` install (via `uv pip install cognee`), switch `CMD`/`ENTRYPOINT` to the new `entrypoint.sh`.
- `services/interface/src/index.ts` (or a new `src/memory-client.ts`) — add an MCP/HTTP client call to the local cognee sibling process so the agent's `session/prompt` flow can read/write memories.
- `docker-compose.yml`:
  - Remove `poco-memory` service entirely.
  - Remove `open-notebook`, `open-notebook-mcp`, `surrealdb` services (if Decision above is "drop") — or just `open-notebook-mcp` (if keeping open-notebook).
  - Remove the `knowledge` profile if nothing remains under it; otherwise keep it scoped to whatever remains.
  - Add a `cognee_data` named volume, mounted into `interface` (e.g. `/cognee_data`) and read-only into `sqlpage` for the `ATTACH DATABASE` path to resolve.
  - Update `sqlpage`'s volumes to also mount `cognee_data:/cognee_data:ro`.

### Deleted files
- `services/poco-memory/` — entire directory (808 LOC of custom Rust MCP server, replaced outright).
- `services/open-notebook-mcp/` — entire directory (27-line Python shim, no longer needed either way — cognee replaces its bridging role even if `open-notebook` itself is kept).

---

## Task 1: Stand up cognee as a sibling process in `interface`

**Files:** `services/interface/Dockerfile`, `services/interface/entrypoint.sh`

- [ ] Add Python + `uv`/`pip install cognee` (or pull the `cognee/cognee-mcp:main` layer contents) into the `interface` image.
- [ ] Write `entrypoint.sh`: start `cognee-mcp` (stdio or `--transport http --port 8000`, matching whichever mode `interface`'s code will call), start `bun src/index.ts`, trap SIGTERM/SIGINT, PID-watch both, `exit 1` on either dying (mirrors `services/sandbox/entrypoint.sh`'s existing pattern — reuse its shape).
- [ ] Point `LLM_API_KEY` / embedding config at whatever provider `interface` already uses for the agent itself, via env vars in `docker-compose.yml`.
- [ ] Mount `cognee_data` volume for cognee's SQLite/LanceDB/Kuzu storage path.

## Task 2: Wire `interface`'s ACP flow to cognee

**Files:** `services/interface/src/*.ts`

- [ ] Add a small client (MCP client, or plain HTTP if using cognee's REST mode) that `command-pump.ts`/`event-pump.ts` can call to store memories after a turn and recall relevant memories before constructing a prompt.
- [ ] Decide the recall trigger point: inject relevant memories into the system prompt / first user message before calling `connection.prompt(...)`, so this works regardless of which ACP agent (gait, opencode, etc.) is spawned.

## Task 3: Remove `poco-memory`

**Files:** `docker-compose.yml`, `services/poco-memory/`

- [ ] Delete `services/poco-memory/` directory.
- [ ] Remove its `docker-compose.yml` service block and any `knowledge`-profile-only network/volume references it uniquely needed.

## Task 4: Remove `open-notebook` + `surrealdb` (if Decision above is "drop")

**Files:** `docker-compose.yml`, `services/open-notebook-mcp/`

- [ ] Delete `services/open-notebook-mcp/` directory.
- [ ] Remove `open-notebook`, `open-notebook-mcp`, `surrealdb` service blocks, the `pocketcoder-knowledge` network (if nothing else uses it), and their volumes (`surrealdb_data`, `notebook_data`).
- [ ] Remove the `knowledge` profile entirely if nothing remains gated behind it.

## Task 5: SQLPage sees both databases

**Files:** `services/sqlpage/config/on_connect.sql`, `services/sqlpage/dashboard/memory.sql`, `docker-compose.yml`

- [ ] Write `on_connect.sql` with `ATTACH DATABASE '/cognee_data/cognee.db' AS cognee;`.
- [ ] Mount `cognee_data:/cognee_data:ro` into the `sqlpage` service.
- [ ] Add a `memory.sql` dashboard page listing recent memories / knowledge-graph entries from `cognee.*` tables.

## Task 6: Verify

- [ ] `docker compose up` (core, no `knowledge` profile needed anymore) — confirm `interface` container starts both processes and stays healthy.
- [ ] Run a real ACP turn through `interface`, confirm cognee stores a memory (check via the new SQLPage `memory.sql` page).
- [ ] Confirm a *second* turn recalls something the first turn stored (the actual point of persistent memory).
- [ ] Confirm `docker-compose.yml` no longer references `poco-memory`/`open-notebook`/`surrealdb` (or just `open-notebook-mcp`, per Decision) anywhere, and `services/sandbox/entrypoint.sh`-style watchdog in `interface` correctly restarts the container if `cognee-mcp` dies.

---

## Out of scope

- The Go/PocketBase permission-evaluator stub (`internal/permission/evaluator.go`) — unrelated, flagged separately.
- `sqlpage`-into-`pocketbase` container merge — separate, independent trim, not required for this plan.
- Tailscale/Caddy dedup — explicitly deferred (Tailscale is staying).
