# Codebase Cleanup Backlog

Generated: 2026-03-07
Updated: 2026-03-08

## Critical / High Priority

### 1. ~~Pervasive stale CAO references~~ ✅
- [x] `services/opencode/opencode.json` — `"cao_*"` → `"poco-agents_*"`
- [x] `services/pocketbase/pb_migrations/1740000101_consolidated_seed.go` — `"cao_*"` → `"poco-agents_*"`
- [x] `services/pocketbase/internal/hooks/llm.go` — Comment updated
- [x] `docs/current-state.md` — Removed `cao_db`, updated sandbox description
- [x] `services/docs/CAO_INTEGRATION.md` — Deprecation notice added
- [x] `services/docs/SYSTEM_ARCHITECTURE.md` — 14 edits, all CAO → poco-agents
- [x] `tests/helpers/cao.sh` — Renamed to `poco-agents.sh`, bats files updated

### 2. ~~Dangling derive macro~~ ✅
- [x] `services/proxy/src/driver.rs` — Orphaned `#[derive]` removed

### 3. ~~Hardcoded `/tmp` file in proxy~~ ✅
- [x] `services/proxy/src/driver.rs` — Now uses unique per-execution temp files with cleanup

### 4. ~~Interface error handling gaps~~ ✅
- [x] Subscription callbacks wrapped in try/catch
- [x] `handleUserMessage` wrapped in try/catch
- [x] `startCommandPump()` now has reconnection with exponential backoff

### 5. ~~Health check gives false positives~~ ✅
- [x] `commandPumpHealthy` only set after all subscriptions succeed

## Medium Priority

### 6. ~~Duplicated Docker restart logic (PocketBase)~~ ✅
- [x] Extracted shared `restartContainer()` into `docker.go`
- [x] `llm.go`, `mcp.go`, `tool_permissions.go` all use shared function
- [x] Standardized timeout to 30s

### 7. ~~Inconsistent hook registration signatures (PocketBase)~~ ✅
- [x] All hooks standardized to `core.App` interface

### 8. ~~Interface uses `"latest"` version pins~~ ✅
- [x] `services/interface/package.json` — Pinned `@opencode-ai/sdk: "^1.2.15"`, `bun-types: "^1.3.10"`, `@types/node: "^25.3.3"`

### 9. ~~`println!` in production Rust code~~ ✅
- [x] `services/proxy/src/main.rs` — Replaced with `tracing` crate (`tracing-subscriber` init + `tracing::info!`)

### 10. ~~Multiple `unwrap()` calls in Rust services~~ ✅
- [x] `services/poco-agents/src/tools.rs` — `expect()` replaced with `.ok_or_else()` returning MCP error
- [x] `services/poco-agents/src/agent.rs` — `Regex::new().unwrap()` → `.expect("reason")`
- [x] `services/proxy/src/driver.rs` — `unwrap()` replaced with `matches!()` pattern
- [x] `services/proxy/src/shell.rs` — `stdout().flush().unwrap()` → `.ok()`

## Low Priority

### 11. ~~Interface type safety~~ ✅
- [x] Added TypeScript interfaces (`ChatRecord`, `MessageRecord`, etc.)
- [x] Added `Collections`, `Status`, `EventType` constants
- [x] Replaced 19 `any` types with proper types

### 12. Dead files/directories
- [ ] `.misc/todelete/` — Stale architectural docs still in repo

### 13. ~~Inconsistent logging prefixes (PocketBase)~~ ✅
- [x] `tool_permissions.go` — Added `⚙️` emoji prefix
- [x] `api/mcp.go` — Added `[MCP]` bracketed tags

### 14. Commented-out `pb_backups` volume
- [ ] `docker-compose.yml:12,339-341` — Volume defined but commented out despite backup scripts existing
