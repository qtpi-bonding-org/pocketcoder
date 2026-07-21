# Pruning Audit: Stale Docs and Scripts

**Audit Date:** 2026-07-21  
**Scope:** Root markdown docs, client Flutter docs, scripts/, spikes/, and backup files  
**Context:** Project migrated from OpenCode/Interface to Goose (ACP + AG-UI)

---

## Executive Summary

This audit identified **23 candidates** for pruning:
- **9 stale documentation files** (outdated OpenCode/Relay architecture descriptions)
- **8 stale scripts** (debugging/testing tools for discontinued infrastructure)
- **3 backup/cruft files** (IDE configs, stale env backups)
- **1 spike** (completed proof-of-concept, kept as reference)

The stale docs describe the old reasoning engine (OpenCode) and relay architecture, which was superseded by Goose (ACP + AG-UI). The stale scripts test or interact with OpenCode containers, the Relay, or CAO (CLI Agent Orchestrator), none of which are in the current `docker-compose.yml`.

---

## Stale Documentation

| Path | Type | Evidence | Confidence |
|------|------|----------|------------|
| `client/ai-opencode.txt` | doc | Entire file is OpenCode agent loading documentation: "OpenCode does not continuously auto-detect changes to agent `.md` files; it loads them at startup/config reload." References `.opencode` directories and `loadAgent` function from OpenCode source. | **High** |
| `client/FLUTTER_DEVELOPMENT_ROADMAP.md` | doc | Line 53: "Connecting the client to the 'Brain' (OpenCode) and the Sandbox." Line 55: "Custom API Endpoints (via `Relay`)". Describes old OpenCode-based architecture with `Relay` coordination. | **High** |
| `client/FLUTTER_BACKEND_INTEGRATION.md` | doc | 15+ references to OpenCode and Relay. Examples: "OpenCode session ID (NOT a relation)", "Auto-replied to OpenCode", "OpenCode message ID", "relay service only (internal)", "created automatically when OpenCode spawns a subagent". Entire SSE section describes OpenCode's old event system. | **High** |
| `client/FLUTTER_INTEGRATION_GAPS.md` | doc | Line 16: "agentId field exists (string, OpenCode session ID)". Describes gaps against old OpenCode-based integration spec. | **High** |
| `client/FLUTTER_INTEGRATION_TASKS.md` | doc | Line 16: "Verify `agentId` field exists (string, OpenCode session ID)". Task checklist aligned to old OpenCode field mappings. | **High** |
| `DEVELOPMENT.md` | doc | Lines 9–12: Describes "Reasoning (OpenCode)", "Relay (Go/PocketBase)", "Proxy (Rust)", "Sandbox (Tmux/Docker)". Line 63: References `services/opencode/`. Line 69: Describes `/workspace Volume` shared between Sandbox, Proxy, and OpenCode. Entire doc describes old architecture, no mention of Goose. | **High** |
| `README.md` | doc | Line 5: "PocketCoder uses high-leverage 'giant's shoulders' like **PocketBase**, **Tmux**, and **OpenCode**". Line 41: References "OpenCode" as a core tool. Lines 115–150: Table and metrics reference "PocketBase backend & relay", "OpenCode tools, plugins & Interface bridge", "pocketcoder-opencode | AI engine (OpenCode)". No mention of Goose. | **High** |
| `SECURITY.md` | doc | Lines 7–10: "The most critical security feature is the complete separation of **Reasoning** (OpenCode/Poco) from **Execution** (The Sandbox/Sub-agents)". Entire architecture diagram and explanation assumes OpenCode/Relay model. No mention of Goose or ACP. | **High** |
| `CODEBASE.md` | doc | Lines 20, 23, 36–51: References "LLM Hooks. Handles API key persistence and **OpenCode container restart**", "Renders opencode.json permission + agent blocks and **restarts OpenCode**", "OpenCode tools, plugins & Interface bridge", 10+ lines listing OpenCode tools (`check_pc_updates.ts`, `mcp_inspect.ts`, etc.) and Interface bridge code. Counts these in LOC totals. No mention of Goose. | **High** |

---

## Stale Scripts

| Path | Type | Evidence | Confidence |
|------|------|----------|------------|
| `scripts/network_matrix_test.sh` | script | Lines 17–34: Tests TCP connectivity for `opencode:3000`, `sandbox-proxy:3001`, references `pocketcoder-opencode` container. Assumes OpenCode is running. Current `docker-compose.yml` has no opencode service. | **High** |
| `scripts/network_matrix_test.py` | script | Lines 7–47: Documents OpenCode container's shell interception behavior. Line 36: Service mapping for `opencode:3000`. Line 47: `UNTRUSTED_SOURCES = {"pocketcoder-opencode"}`. Entire script assumes OpenCode network topology. | **High** |
| `scripts/debug/export_opencode_session.sh` | script | Lines 7, 11: `docker exec -it pocketcoder-opencode opencode export`. Calls `opencode` CLI which does not exist in Goose. Stale one-off utility. | **High** |
| `scripts/debug/query-agent-tools.sh` | script | Line 7: `docker compose exec -T sandbox opencode run --agent developer`. Calls `opencode run` CLI which is specific to old OpenCode system. Not valid for Goose. | **High** |
| `scripts/investigate/cao_db_query.sh` | script | Lines 13–14: References `pocketcoder-sandbox` container and CAO SQLite database path `/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db`. CAO not found in current `docker-compose.yml`. | **High** |
| `scripts/investigate/cao_db_tables.sh` | script | References CAO database tables in sandbox container. CAO not in current infrastructure. | **High** |
| `scripts/investigate/cao_terminal_logs.sh` | script | References CAO terminal logging infrastructure. CAO not in current infrastructure. | **High** |
| `scripts/debug/sandbox_status.sh` | script | Lines 14–37: Queries tmux sessions and CAO sessions from sandbox container. While sandbox may still exist, CAO is no longer part of the stack. Only the CAO-specific portions (lines 19–37) are stale; tmux portions may still be relevant. | **Medium** |

---

## Backup and Cruft Files

| Path | Type | Evidence | Confidence |
|------|------|----------|------------|
| `.env.backup` | cruft | Lines 3–5: `PORT=3000`, `POCKETBASE_URL=http://pocketbase:8090`, `BRAIN_URL=http://opencode:3000`. Contains stale OpenCode URL reference. Not in `.gitignore`. | **High** |
| `.env.bak` | cruft | Same as `.env.backup`: contains `BRAIN_URL=http://opencode:3000`. Duplicate backup. | **High** |
| `client/melos_pocketcoder_workspace.iml` | cruft | IntelliJ IDE module configuration file (XML). IDE-generated, should not be committed. Best removed; regenerated on project open. | **High** |

---

## Completed Spikes (Decision Records)

| Path | Type | Evidence | Confidence |
|------|------|----------|------------|
| `spikes/goose-acp-http/` | spike | README lines 13–30: "Decision: select Goose v1.36.0 for c2 and use the current Streamable-HTTP ACP profile. Gate A is complete and the developer-tool portion of Gate C is complete." Spike served its purpose (compatibility proof); result was adopted. Valuable as a locked-in decision record and reference for Goose transport dialect. Not stale, but could be archived to separate reference location. | **High** |

---

## Recommendation Summary

### High-Confidence Removals (22 candidates)
- Delete all 9 stale documentation files (Flutter integration docs, root-level architecture docs)
- Delete all 8 stale scripts (network tests, debug utilities referencing defunct containers)
- Delete 3 backup/cruft files (.env backups, .iml)

**Rationale:** These describe or interact with the old OpenCode/Relay/Proxy/CAO infrastructure, which has been completely superseded by Goose (ACP) + Sandbox (Execution). The current `docker-compose.yml` contains no `opencode` or `interface` services; these directories are empty shells with only `node_modules`.

### Medium Confidence (1 candidate)
- Review `scripts/debug/sandbox_status.sh` for CAO references and decide whether to keep tmux portions (may still be useful for observability) or remove entirely.

### Decision Record (1 spike)
- Keep `spikes/goose-acp-http/` as a locked decision record, but consider moving to `docs/decisions/` or `docs/spikes/` for better organization and clarity that it's a reference, not active code.

---

## Appendix: Files Not Flagged (Current/Reference)

The following docs were reviewed and found **still-current**:
- `client/README_MONOREPO.md` — describes Melos monorepo structure (current)
- `client/README.md` — describes Flutter client structure (current)
- `client/CLAUDE.md` — Flutter development guidelines (current)
- `client/DATA_ARCHITECTURE_PLAN.md` — data layer architecture plan (current, references ongoing implementation)
- `CLAUDE.md` — project setup instructions (current, though references `opencode` build step; should be updated)
- `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md` (root), `CODEBASE.md` — reference/policy docs (flagged above for OpenCode content)

---

## Files to Update (not in this audit)

These were not flagged as "delete" but should be updated to remove stale references:
- `CLAUDE.md` (project instructions) — Line 7: `docker compose build pocketbase opencode` should change to `docker compose build pocketbase goose`
- `scripts/generate_audit.sh` — Updates LOC counts for services; should remove references to `services/opencode` and `services/interface` if no longer in CORE_DIRS
