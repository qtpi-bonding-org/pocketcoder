# Codebase Cleanup Backlog

Generated: 2026-03-07

## Critical / High Priority

### 1. Pervasive stale CAO references (~53 files)
CAO → poco-agents migration is incomplete.

- [ ] `services/opencode/opencode.json:10` — `"cao_*": "ask"` permission still active while MCP is `poco-agents`
- [ ] `services/pocketbase/pb_migrations/1740000101_consolidated_seed.go:150` — Seeds dead `cao_*` tool permissions
- [ ] `services/pocketbase/internal/hooks/llm.go:117` — Comment references CAO
- [ ] `docs/current-state.md` — Claims `cao_db` volume (doesn't exist), describes sandbox as "tmux + CAO"
- [ ] `services/docs/CAO_INTEGRATION.md` — Entire file is stale
- [ ] `services/docs/SYSTEM_ARCHITECTURE.md` — 15+ CAO references
- [ ] `tests/helpers/cao.sh` — Legacy helper with backward-compat wrapper; loaded by 2 test files

### 2. Dangling derive macro
- [ ] `services/proxy/src/driver.rs:70` — Orphaned `#[derive(Debug, Deserialize)]` with no struct following it

### 3. Hardcoded `/tmp` file in proxy
- [ ] `services/proxy/src/driver.rs:125,142` — Uses `/tmp/pocketcoder_out.txt` for all command output. Concurrent executions will collide.

### 4. Interface error handling gaps
- [ ] `services/interface/src/index.ts:260-278` — PocketBase subscription callbacks have no try/catch
- [ ] `services/interface/src/index.ts:292-306` — `handleUserMessage` has no error handling around SDK calls
- [ ] `startCommandPump()` has no reconnection/recovery logic (unlike `startEventPump()`)

### 5. Health check gives false positives
- [ ] `services/interface/src/index.ts:432-453` — `commandPumpHealthy` set to `true` immediately after subscribing, not after confirming subscriptions work

## Medium Priority

### 6. Duplicated Docker restart logic (PocketBase)
- [ ] `llm.go:128-169` and `mcp.go:171-212` — Near-identical Docker restart code. Extract to shared utility. Inconsistent timeouts (30s vs 10s).

### 7. Inconsistent hook registration signatures (PocketBase)
- [ ] Some hooks take `*pocketbase.PocketBase`, others take `core.App`. Standardize.

### 8. Sandbox MCP server is a 923-line monolith
- [ ] `services/sandbox/cao/src/cli_agent_orchestrator/mcp_server/server.py` — Duplicated code in `_create_terminal()`, conditional tool duplication (450+ lines), bare `except: pass` blocks

### 9. Interface uses `"latest"` version pins
- [ ] `services/interface/package.json` — `@opencode-ai/sdk`, `@types/node`, `bun-types` all `"latest"`

### 10. `println!` in production Rust code
- [ ] `services/proxy/src/main.rs:123,141,161,176,179` — Should use `tracing` crate

### 11. Multiple `unwrap()` calls in Rust services
- [ ] `services/poco-agents/src/tools.rs` and `services/proxy/src/driver.rs` — Should use `.expect("reason")` or proper error handling

## Low Priority

### 12. Interface type safety
- [ ] 19 uses of `any` in `services/interface/src/index.ts`
- [ ] 21 hardcoded collection name strings (should be constants)
- [ ] Magic status strings throughout

### 13. Dead files/directories
- [ ] `services/sandbox/test_tmux_head.py` — Orphaned test script
- [ ] `services/sandbox/agents/sandbox_agents/` — Empty directory with only `.gitkeep`
- [ ] `.misc/todelete/` — Stale architectural docs still in repo

### 14. Unresolved TODOs
- [ ] `services/sandbox/cao/.../q_cli.py:31,150,157` — 3 TODOs about dead code removal
- [ ] `services/sandbox/cao/.../logging.py:24` — Prints `CAO_LOG_LEVEL` in user-facing message

### 15. Inconsistent logging prefixes (PocketBase)
- [ ] `tool_permissions.go` uses `[ToolPerms]` (no emoji) while others use emoji prefixes
- [ ] `api/mcp.go` uses plain `❌` without bracketed tags

### 16. Commented-out `pb_backups` volume
- [ ] `docker-compose.yml:12,339-341` — Volume defined but commented out despite backup scripts existing
