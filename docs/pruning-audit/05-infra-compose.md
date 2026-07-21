# Infrastructure & Compose Audit Report

**Audit Date:** 2026-07-21  
**Scope:** OpenCode/Interface → Goose migration dead weight  
**Status:** Read-only findings; no changes made

---

## Executive Summary

The OpenCode/Interface → Goose (ACP + AG-UI) migration left residual config and dead code paths. Key findings:

- **2 dormant service directories** (`opencode`, `interface`) with no Dockerfiles or compose references
- **5 dead environment variables** set in `.env` but unread by any active service
- **3 deleted DB collections + 4 dropped fields** from legacy runtime (already applied via migrations)
- **1 dormant code package** (`executor/sandbox.go`) preserved for future Goose tool integration
- **1 dormant compose profile** (`c3` / mcp-gateway) not currently used
- **2 unused vendored Rust projects** (`services/poco-agents`, `services/proxy`)

---

## Docker Compose Services Inventory

| Service | Type | Profile | Status | Notes |
|---------|------|---------|--------|-------|
| **pocketbase** | Core Backend | (default) | **LIVE** | Always runs; c1 orchestrator |
| **goose** | Agent Runtime | `agent` | **LIVE** | Optional c2 runtime; authenticated ACP channel only |
| **sqlpage** | Observability | (default) | **LIVE** | SQLPage dashboard for PocketBase data |
| **docker-socket-proxy-write** | Infrastructure | (default) | **LIVE** | Security proxy for PocketBase container restart capability |
| **mcp-gateway** | MCP Server | `c3` | **DORMANT** | Profile c3 not activated; for future cloud agent orchestration |
| **ntfy** | Notifications | `foss` | **CONDITIONAL** | Optional sovereign notification server; profile `foss` |
| **tailscale** | Remote Access | `tailscale` | **CONDITIONAL** | Optional Tailscale tunnel; profile `tailscale` |
| **caddy** | Reverse Proxy | `caddy` | **CONDITIONAL** | Optional HTTPS proxy; profile `caddy` |
| **n8n** | Automation | (hackathon-demo) | **CONDITIONAL** | Workflow automation; separate compose file only |
| **docs** | Documentation | (docs only) | **CONDITIONAL** | Astro site; separate compose file only |
| **agent-c1-test** | Test Runner | `agent-test` | **CONDITIONAL** | Live acceptance tests; profile `agent-test` |

### Compose File Variants

- **docker-compose.yml** — Main production stack (pocketbase, goose, mcp-gateway, docker-socket-proxy, sqlpage, ntfy, tailscale, caddy)
- **docker-compose.agent-test.yml** — C1↔C2 live acceptance runner (goose, pocketbase required)
- **docker-compose.hackathon-demo.yml** — Optional n8n workflow automation
- **docker-compose.docs.yml** — Documentation build/serve (Astro)
- ~~docker-compose.agent.yml~~ **NEVER EXISTED** (see evidence below)

---

## Dead Service Directories

| Path | Type | Evidence | Confidence |
|------|------|----------|------------|
| **services/opencode/** | Dead Service | Directory exists with node_modules (build artifact); no Dockerfile; no git history; not referenced in any compose file; OPENCODE_URL env var unread by any service. Removed in early OpenCode→Claude migration phase. | **HIGH** |
| **services/interface/** | Dead Service | Directory exists with node_modules (build artifact); Dockerfile deleted in commit a77049b18 ("prune: remove interface/sandbox/knowledge services"); not in git; not referenced in any compose file. Interface container was the old agent ACP coordinator, superseded by Goose c2. | **HIGH** |

---

## Dead Environment Variables

| Variable | Set In | Used By | Status | Confidence |
|----------|--------|---------|--------|------------|
| **OPENCODE_URL** | `.env` (value: `http://opencode:3000`) | None (grepped all services, hooks, code) | **DEAD** | **HIGH** — Referenced in old docs (SYSTEM_ARCHITECTURE.md, RUNNING_TESTS.md) but opencode service does not exist |
| **ENABLE_GO_RELAY** | `.env` (value: `true`) | None (no service reads this) | **DEAD** | **HIGH** — Legacy relay was authenticated WebSocket between c1 and old c2; relay was removed in commit 97890fc37 ("feat: authenticate c1↔c2 WebSocket, retire nginx relay") |
| **OPENCODE_EXPERIMENTAL** | `.env` (value: `true`) | None | **DEAD** | **HIGH** |
| **OPENCODE_EXPERIMENTAL_LSP_TOOL** | `.env` (value: `true`) | None | **DEAD** | **HIGH** |
| **OPEN_NOTEBOOK_ENCRYPTION_KEY** | `.env` | None | **DEAD** | **MEDIUM** — Possibly for old notebook feature that was removed |
| **GEMINI_API_KEY** | `.env` | mcp-gateway/config/docker-mcp.yaml (two catalog entries) | **DORMANT** | **HIGH** — mcp-gateway runs only on profile `c3`, which is not activated by default. Gemini MCP provider defined but not used in current Goose stack (only Anthropic/MiniMax in use). |

### Evidence: .env Backup History

`.env.bak` and `.env.backup` retain older configuration:
- COMPOSE_PROJECT_NAME, PORT, POCKETBASE_URL, BRAIN_URL (old opencode endpoint)
- These predate the Goose migration and confirm opencode was a separate service

---

## PocketBase Schema: Deleted & Dropped

### Migration 1752000000_prune_legacy_runtime.go

**Removed collections (forward-only; not reversible):**

| Collection | Reason | Notes |
|-----------|--------|-------|
| **messages** | Goose c2 owns conversation history | Replaced by Goose internal session state; goose_sessions is the c1↔c2 mapping |
| **permissions** | Goose c2 owns tool approvals | Replaced by Goose internal permission state |
| **acp_terminals** | Goose c2 owns terminal state | Replaced by Goose internal shell/terminal tracking |

**Removed fields from chats collection:**

| Field | Reason |
|-------|--------|
| **acp_session_id** | Legacy session mapping to old ACP runtime |
| **engine_type** | Referenced old engine types (opencode, claude-code, cursor, custom); no longer needed |
| **ai_engine_session_id** | OpenCode/legacy engine session ID; Goose uses goose_sessions collection |

Associated indexes dropped:
- `idx_chats_ai_engine_session_id`
- `idx_chats_acp_session_id`

### Migration 1748000400_drop_unused_fields.go

**Removed fields:**

| Field | Collection | Reason |
|-------|-----------|--------|
| **current_role** | chats | Added in 1748000100 but never referenced by any hook or client code |

### Collections Preserved (Dormant but Not Deleted)

| Collection | Status | Reason |
|-----------|--------|--------|
| **sandbox_agents** | Preserved | Part of legacy runtime structure; preserved for future Goose tool integration (see executor/sandbox.go comments) |

---

## Dead Code Paths

| Path | Type | Status | Evidence | Confidence |
|------|------|--------|----------|------------|
| **services/pocketbase/internal/agent/executor/sandbox.go** | ACP Adapter | **DORMANT** | Package header comment: "Package executor preserves the sandbox ACP adapter for a future Goose tool integration. The selected c1 runtime does not currently advertise or call it because Goose's built-in shell executes in c2 rather than via ACP." No imports of executor package found in codebase. | **HIGH** |

---

## Unused Vendored/Build Projects

| Path | Type | Size | Status | Confidence |
|------|------|------|--------|------------|
| **services/poco-agents/** | Rust (Cargo.toml) | ~88 KB | **UNUSED** | No Dockerfile; not referenced in compose files; no imports in active code | **MEDIUM** |
| **services/proxy/** | Rust (Cargo.toml) | ~57 KB | **UNUSED** | No Dockerfile; not referenced in compose files; directory exists but appears abandoned | **MEDIUM** |

---

## Dormant Compose Profile: c3

| Profile | Service | Status | Notes |
|---------|---------|--------|-------|
| **c3** | mcp-gateway | **DORMANT** | MCP Server Gateway for cloud agent orchestration. Dockerfile present; service defined with `profiles: ["c3"]`. **Not activated in current workflow.** Referenced in agent-test comments as intentionally excluded. |

**Purpose:** Would enable dynamic MCP server provisioning and cloud-based agent coordination. Currently superseded by direct c2 Goose integration with local MCP server catalog.

**When activated:** `docker compose --profile c3 up mcp-gateway`

---

## Recommendations

### Cleanup Candidates (No Functional Impact)

1. **Remove dead env vars from .env template** (HIGH priority)
   - Delete: `OPENCODE_URL`, `ENABLE_GO_RELAY`, `OPENCODE_EXPERIMENTAL*`, `OPEN_NOTEBOOK_ENCRYPTION_KEY`, `GEMINI_API_KEY`
   - Rationale: Reduces config surface; prevents confusion for new operators

2. **Clean build artifacts** (LOW priority, manual)
   - Remove: `/services/opencode/node_modules`, `/services/interface/node_modules`
   - Reason: Residual from pre-migration builds; add to `.gitignore` if not already present

3. **Audit & possibly delete services/poco-agents, services/proxy** (MEDIUM priority)
   - Verify: Are these used elsewhere (e.g., Flutter client, deployment scripts)?
   - If unused: Consider moving to `.independent_repos/` or deleting

### Schema Consolidation (Future Phase)

**Note only — do not delete applied migrations.** Future work candidates:

- Consider a **drop-migration for sandbox_agents collection** after confirming Goose tool integration strategy is finalized
- Document `executor/sandbox.go` status in CONTRIBUTING.md as "preserved for future integration; currently dormant"

---

## Cross-References

- **Relay removal:** commit ef543d345 ("fix: repair agent-test wiring and env template after relay removal")
- **Interface/sandbox prune:** commit a77049b18 ("prune: remove interface/sandbox/knowledge services, profile mcp-gateway")
- **OpenCode service removal:** commit a4f213c9c ("feat(compose): remove opencode service, interface now spawns agent CLI in-process")
- **Legacy runtime prune:** migration 1752000000_prune_legacy_runtime.go
- **CLAUDE.md:** Model generation pipeline references PocketBase schema/migrations; update procedures documented there

---

## Audit Methodology

1. **Compose files:** Enumerated all `.yml` files at repo root; parsed service definitions and profile conditions
2. **Service directories:** Listed `/services` and cross-referenced against Dockerfiles and compose references
3. **Environment variables:** Grepped `.env`, `.env.template`, `.env.bak` against all source code (`*.go`, `*.ts`, `*.js`, `*.yaml`)
4. **Git history:** Reviewed commit messages and diffs for migration context
5. **PocketBase schema:** Inspected migration files for dropped collections/fields
6. **Code paths:** Verified dormant executor package has no active callers

---

**End of Report**
