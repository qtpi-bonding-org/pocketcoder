# PocketBase Go Backend Audit: Dead Code Analysis

**Audit Date:** 2026-07-21  
**Build/Vet Status:** ✅ PASS (no errors)  
**Go Module:** `github.com/qtpi-automaton/pocketcoder/backend`  
**Scope:** `services/pocketbase/internal/` + top-level Go files

## Summary

The PocketBase backend successfully compiles and passes Go vet checks. However, several packages and files are confirmed dead code orphaned by the migration from OpenCode/Interface to Goose (ACP + AG-UI) and the detached sandbox executor path.

**Build Result:** `go build ./...` → OK (no output)  
**Vet Result:** `go vet ./...` → OK (no output)

---

## Findings

| File/Package | Candidate | Evidence | Confidence |
|---|---|---|---|
| `internal/agents/` | Empty orphan directory (no `.go` files) | Directory exists but is empty; zero imports found via `grep -r "internal/agents"` | **High** |
| `internal/auth/` | Empty orphan directory (no `.go` files) | Directory exists but is empty; zero imports found via `grep -r "internal/auth"` | **High** |
| `internal/permission/` | Unused package `evaluator.go` | Zero imports of `permission` package; `Evaluate()` function is exported but never called. Package defines default "draft" permission approval (obsolete design). Commit `6f2e6eac7` deleted the route that used this. | **High** |
| `internal/utils/` | Unused package `wildcard.go` | Zero imports of `utils` package; `MatchWildcard()` is exported but never called. Glob-to-regex matcher was likely used by permission evaluator (now deleted). | **High** |
| `internal/agent/executor/` | Dormant sandbox executor adapter | Package preserved "for a future Goose tool" (line 1 comment); never imported or called in main code. Tests exist (`sandbox_test.go`) but package is not integrated. Detached in commit `9664ae558`. | **High** |
| `internal/hooks/cron.go` line 37-38 | Stale documentation comment | Comment references "Interface event pump picks up and forwards to OpenCode" — this path is retired. Actual code creates messages for Goose agent (correct), but comment is obsolete. | **Medium** |
| `internal/hooks/mcp.go` line 40 | Stale documentation comment | Comment references "The interface receives status updates via PocketBase realtime subscriptions" — this refers to the retired Interface service. Actual MCP rendering (lines 54-77) is active and correct. | **Medium** |
| `internal/provisioning/sops.go` line 16 | Deprecated OpenCode workspace path | Code reads SOPs from `/workspace/.opencode/proposals/` — path references legacy OpenCode directory structure. No other references to OpenCode client code, but path naming is stale. | **Low** |
| `pb_migrations/1752000100_poco_config_mode.go` line 23 | Dead code comment | Inline comment "dead OpenCode bundle" marks removal of old `config` field. This is a migration housekeeping comment (acceptable). | **Low** |

---

## Orphaned Services (Docker/docker-compose.yml)

### Services Removed from docker-compose.yml
- **`opencode`** service: Deleted entirely (referenced in git history `a4ce522bc`, `40afe95ca`, `6a655afa8`)
- **`interface`** service: Deleted entirely (referenced in git history `a77049b18`)
- **`sandbox`** service: Deleted entirely (referenced in git history `a77049b18`)

The docker-compose.yml still defines a volume `opencode_workspace:` (line 288) and mounts it to `/workspace` in `pocketbase` and `goose` containers, but there is no service that produces content there — this volume may be for test fixtures or external workspace.

---

## Package Import Analysis

Reference counts across internal packages (non-test code):

```
agent/         7 refs  ✅ ACTIVE (coordinator, acp, agui exports)
agents/        0 refs  ❌ DEAD
api/           2 refs  ✅ ACTIVE (main.go imports)
auth/          0 refs  ❌ DEAD
filesystem/    1 ref   ✅ ACTIVE (main.go imports)
gooseconfig/   1 ref   ✅ ACTIVE (main.go imports)
hooks/         1 ref   ✅ ACTIVE (main.go imports)
permission/    0 refs  ❌ DEAD
provisioning/  1 ref   ✅ ACTIVE (main.go imports)
utils/         0 refs  ❌ DEAD
executor/      0 refs  ❌ DEAD (internal/agent subpackage)
```

---

## Related Git Commits

These commits document the migration that left dead code:

- **`9664ae558`** (2026-07-16): `refactor(agent): detach dormant sandbox execution path`  
  Removed 110 LoC from `internal/agent/coordinator/run.go`; preserved `executor/sandbox.go` for future integration.

- **`1234ef4fe`** (2026-07-19): `refactor(hooks): retire OpenCode renders for Goose config pipeline`  
  Deleted **498 LoC** across 5 files:
  - `internal/agents/bundler.go` (79 LoC) — OpenCode bundler
  - `internal/hooks/agents.go` (74 LoC) — OpenCode agent hook handlers
  - `internal/hooks/llm.go` (112 LoC) — LLM key rendering (replaced by Goose config)
  - `internal/hooks/tool_permissions.go` (220 LoC) — OpenCode tool approval flow

- **`6f2e6eac7`** (2026-07-07): `prune: delete dead OpenCode permission route and hook`  
  Removed route that called `internal/permission.Evaluate()`

---

## Recommendations

### Immediate Action: Remove Dead Code

1. **Delete empty directories:**
   ```bash
   rm -rf internal/agents/ internal/auth/
   ```

2. **Delete unused packages:**
   ```bash
   rm -rf internal/permission/
   rm -rf internal/utils/
   rm -rf internal/agent/executor/
   ```

3. **Fix stale comments:**
   - `internal/hooks/cron.go` line 37-38: Update comment to reference Goose agent instead of Interface
   - `internal/hooks/mcp.go` line 40: Update comment to remove Interface reference

### Medium-Term: Workspace Path Cleanup

Review the `/workspace/.opencode/proposals/` path in `internal/provisioning/sops.go`:
- Decide whether to rename to a neutral path (e.g., `/workspace/.pocketcoder/proposals/`) or document why OpenCode naming persists for backward compatibility.

### Optional: Complete Sandbox Executor Cleanup

If the dormant sandbox executor (`internal/agent/executor/sandbox.go`) is not planned for future use:
- Remove the package and its tests
- It was preserved "for a future Goose tool integration" but Goose's built-in shell executes in c2, making this adapter unnecessary

---

## Active Goose Integration (Not Flagged)

The following code paths are **live and active** and should NOT be modified:

- `internal/agent/coordinator/` — C1 orchestrator (main agent coordinator)
- `internal/agent/acp/` — C1 WebSocket ACP bridge
- `internal/agent/agui/` — AG-UI event stream adapter
- `internal/gooseconfig/` — Goose config.yaml/keys.env rendering
- `internal/hooks/goose_config.go` — Goose config hooks + container restart
- `internal/api/agent.go` — Agent run stream + prompt endpoints

All active Goose code compiles cleanly and has correct references.
