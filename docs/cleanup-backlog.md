# Codebase Cleanup Backlog

Generated: 2026-03-07

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

### 8. Interface uses `"latest"` version pins
- [ ] `services/interface/package.json` — `@opencode-ai/sdk`, `@types/node`, `bun-types` all `"latest"`

### 9. `println!` in production Rust code
- [ ] `services/proxy/src/main.rs:123,141,161,176,179` — Should use `tracing` crate

### 10. Multiple `unwrap()` calls in Rust services
- [ ] `services/poco-agents/src/tools.rs` and `services/proxy/src/driver.rs` — Should use `.expect("reason")` or proper error handling

## Low Priority

### 11. Interface type safety
- [ ] 19 uses of `any` in `services/interface/src/index.ts`
- [ ] 21 hardcoded collection name strings (should be constants)
- [ ] Magic status strings throughout

### 12. Dead files/directories
- [ ] `services/sandbox/test_tmux_head.py` — Orphaned test script (local only, not in repo)
- [ ] `.misc/todelete/` — Stale architectural docs still in repo

### 13. Inconsistent logging prefixes (PocketBase)
- [ ] `tool_permissions.go` uses `[ToolPerms]` (no emoji) while others use emoji prefixes
- [ ] `api/mcp.go` uses plain `❌` without bracketed tags

### 14. Commented-out `pb_backups` volume
- [ ] `docker-compose.yml:12,339-341` — Volume defined but commented out despite backup scripts existing
