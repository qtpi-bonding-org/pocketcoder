# Legacy Runtime Prune Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the repo to a clean c1/c2 base by deleting the dead OpenCode/Interface runtime, the abandoned knowledge stack, and the PocketBase collections that duplicate Goose-owned turn state.

**Architecture:** Pure deletion pass over PocketBase Go, docker-compose, service build contexts, and legacy tests. One forward-only migration drops legacy collections/fields. No features added, no refactors.

**Tech Stack:** Go (PocketBase v0.36.1 `core` API), docker-compose, bats.

**Design spec:** `docs/superpowers/specs/2026-07-18-legacy-runtime-prune-design.md`

## Global Constraints

- **Forward-only migrations.** Never edit an applied migration. Model the new one on `services/pocketbase/pb_migrations/1748000400_drop_unused_fields.go` (uses `FindCollectionByNameOrId`, `Fields.GetByName`, `Fields.RemoveById`, `app.Save`, with a down-migration).
- **Loud errors, no guards.** The only edits to *kept* code are those needed to keep PocketBase **booting** (Tasks 1–2). Do NOT add existence guards to cron or the agent-definition config hooks; they must fail loudly on use — repaired by named follow-ups.
- **Pre-launch:** deleting any existing legacy records is acceptable.
- Backend working dir for all Go commands: `services/pocketbase`.
- Flutter is NOT touched by this plan (separate rebuild).

---

## File Structure

- `services/pocketbase/main.go` — Modify: unregister deleted permission route + hook (lines 47, 73).
- `services/pocketbase/internal/api/permission.go` — Delete.
- `services/pocketbase/internal/hooks/permissions.go` — Delete.
- `services/pocketbase/internal/hooks/notifications.go` — Modify: remove the `permissions` create trigger (line 139 block); keep the push stack.
- `services/pocketbase/internal/hooks/timestamps.go` — Modify: remove `"messages"`, `"permissions"` from the collection list (line 50).
- `services/pocketbase/pb_migrations/1752000000_prune_legacy_runtime.go` — Create: drop `messages`, `permissions`, `acp_terminals`; drop `chats` fields `acp_session_id`, `engine_type`, `ai_engine_session_id` + their indexes.
- `docker-compose.yml` — Modify: delete 6 services, orphan volumes/networks, fix `sqlpage` depends_on, add `c3` profile to `mcp-gateway`.
- `services/interface/`, `services/opencode/`, `services/sandbox/`, `services/open-notebook-mcp/` — Delete directories (build contexts).
- `.env.template` — Modify: drop OpenCode/knowledge-era keys.
- `tests/integration/agent/*`, `tests/integration/mcp/mcp-full-flow.bats`, `tests/integration/auth/permission-gating.bats`, `tests/connection/*opencode*`, `tests/health/opencode.bats` — Delete.

---

## Task 1: Delete the dead permission Go path

**Files:**
- Delete: `services/pocketbase/internal/api/permission.go`
- Delete: `services/pocketbase/internal/hooks/permissions.go`
- Modify: `services/pocketbase/main.go:47,73`

**Interfaces:**
- Consumes: nothing.
- Produces: removes symbols `hooks.RegisterPermissionHooks`, `api.RegisterPermissionApi`. No other package may reference them after this task.

- [ ] **Step 1: Confirm no other caller references the two symbols**

Run: `cd services/pocketbase && grep -rn "RegisterPermissionHooks\|RegisterPermissionApi" --include='*.go' .`
Expected: only `main.go:47`, `main.go:73`, and the definitions in the two files to be deleted.

- [ ] **Step 2: Delete the two files**

```bash
cd services/pocketbase
git rm internal/api/permission.go internal/hooks/permissions.go
```

- [ ] **Step 3: Remove the two registration lines from `main.go`**

Delete exactly two lines: `hooks.RegisterPermissionHooks(app)` (line 47) and `api.RegisterPermissionApi(app, e)` (line 73). Do NOT delete the `// 2. Register Global Sovereign Hooks` or `// B. Register Custom API Endpoints` comments — they are generic section headers, not permission-specific.

- [ ] **Step 4: Build**

Run: `cd services/pocketbase && go build ./...`
Expected: exit 0, no "declared and not used" / undefined-symbol errors.

- [ ] **Step 5: Full unit tests still green**

Run: `cd services/pocketbase && go test ./...`
Expected: PASS (the `internal/agent/*` suites and everything else).

- [ ] **Step 6: Commit**

```bash
git add -A && git commit -m "prune: delete dead OpenCode permission route and hook"
```

---

## Task 2: Trim boot-critical hooks that bind to deleted collections

`messages`/`permissions` are dropped in Task 3. These hooks bind to those collections at registration. In PocketBase v0.36 the bindings are lazy-by-tag (they won't panic at boot — they'd just never fire), but they are dead references to about-to-be-dropped collections, so remove them here, before the migration.

**Files:**
- Modify: `services/pocketbase/internal/hooks/notifications.go:139`
- Modify: `services/pocketbase/internal/hooks/timestamps.go:50`

**Interfaces:**
- Consumes: nothing.
- Produces: `RegisterNotificationHooks` no longer binds any `permissions` hook; `RegisterGlobalTimestamps` no longer touches `messages`/`permissions`. The `/api/push` endpoint and the device/rule/presence push stack are unchanged.

- [ ] **Step 1: Remove the `permissions` create trigger in `notifications.go`**

Delete the orphaned comment at line 138 (`// Hook: permission created -> push notification`) AND the entire block starting at line 139:
```go
app.OnRecordAfterCreateSuccess("permissions").BindFunc(func(e *core.RecordEvent) error {
    // ...
})
```
Remove the whole statement (from `app.OnRecordAfterCreateSuccess("permissions")` through its closing `})`) plus the comment line above it. Leave the rest of `RegisterNotificationHooks` and `RegisterPushApi` intact. `core` stays imported (still used by `RegisterPushApi`).

- [ ] **Step 2: Trim the timestamps collection list**

In `timestamps.go:50`, change:
```go
collections := []string{"chats", "messages", "permissions", "usages", "ssh_keys", "poco_configs"}
```
to:
```go
collections := []string{"chats", "usages", "ssh_keys", "poco_configs"}
```

- [ ] **Step 3: Build**

Run: `cd services/pocketbase && go build ./...`
Expected: exit 0. (`core` stays used in `notifications.go`; no import change expected.)

- [ ] **Step 4: Unit tests green**

Run: `cd services/pocketbase && go test ./...`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A && git commit -m "prune: stop binding startup hooks to messages/permissions"
```

---

## Task 3: Forward-only migration dropping legacy collections and fields

**Files:**
- Create: `services/pocketbase/pb_migrations/1752000000_prune_legacy_runtime.go`

**Interfaces:**
- Consumes: the migration framework (`migrations.Register`), same as `1748000400`.
- Produces: after `migrate up`, collections `messages`/`permissions`/`acp_terminals` are absent and `chats` has no `acp_session_id`/`engine_type`/`ai_engine_session_id` field or matching index.

- [ ] **Step 1: Write the migration**

Create `services/pocketbase/pb_migrations/1752000000_prune_legacy_runtime.go`:
```go
package pb_migrations

import (
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// Removes Goose-superseded turn-state: the messages/permissions/acp_terminals
// collections and the legacy chats session-id/engine fields. Goose owns
// conversation, tool, approval, and terminal state; goose_sessions is the only
// c1 runtime mapping. Forward-only; deleting pre-launch records is acceptable.
func init() {
	migrations.Register(func(app core.App) error {
		for _, name := range []string{"messages", "permissions", "acp_terminals"} {
			col, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				continue // already absent
			}
			if err := app.Delete(col); err != nil {
				return err
			}
		}
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		chats.Indexes = dropIndexes(chats.Indexes, "idx_chats_ai_engine_session_id", "idx_chats_acp_session_id")
		for _, f := range []string{"acp_session_id", "engine_type", "ai_engine_session_id"} {
			if field := chats.Fields.GetByName(f); field != nil {
				chats.Fields.RemoveById(field.GetId())
			}
		}
		return app.Save(chats)
	}, func(app core.App) error {
		// Down: no-op. Pre-launch prune is not reversible by design; recreating
		// empty legacy collections would serve no purpose.
		return nil
	})
}

// dropIndexes returns the index definitions that do not mention any of names.
func dropIndexes(indexes []string, names ...string) []string {
	kept := make([]string, 0, len(indexes))
	for _, idx := range indexes {
		drop := false
		for _, n := range names {
			if strings.Contains(strings.ToLower(idx), strings.ToLower(n)) {
				drop = true
				break
			}
		}
		if !drop {
			kept = append(kept, idx)
		}
	}
	return kept
}
```

- [ ] **Step 2: Build**

Run: `cd services/pocketbase && go build ./...`
Expected: exit 0.

- [ ] **Step 3: Apply migrations against a throwaway data dir**

Run:
```bash
cd services/pocketbase && rm -rf /tmp/pb_prune_check && go run . migrate up --dir /tmp/pb_prune_check
```
Expected: migrations apply through `1752000000` with no error. (If the binary needs superuser env, this still exercises the migration registration + up path.)

- [ ] **Step 4: Assert the collections are gone**

`go run . migrate collections` does NOT list collections (it writes a snapshot migration file), so boot the server against the throwaway dir and check the API:
```bash
cd services/pocketbase && (timeout 12 go run . serve --http=127.0.0.1:8098 --dir /tmp/pb_prune_check &) ; sleep 8
for c in messages permissions acp_terminals; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:8098/api/collections/$c/records")
  echo "$c -> $code"
done
pkill -f "serve --http=127.0.0.1:8098" 2>/dev/null || true
```
Expected: each collection prints `404` (collection no longer exists). A `200`/`403` means the drop did not apply.

- [ ] **Step 5: Commit**

```bash
rm -rf /tmp/pb_prune_check
git add -A && git commit -m "prune: drop messages/permissions/acp_terminals collections and legacy chat fields"
```

---

## Task 4: Delete legacy backend tests

**Files:**
- Delete: `tests/integration/agent/*`, `tests/integration/mcp/mcp-full-flow.bats`, `tests/integration/auth/permission-gating.bats`, `tests/connection/*opencode*`, `tests/health/opencode.bats`

**Interfaces:** none.

- [ ] **Step 1: Confirm these are the frozen legacy tests**

Run: `ls tests/integration/agent tests/integration/mcp tests/integration/auth tests/connection tests/health 2>/dev/null`
Expected: shows the files named above exist.

- [ ] **Step 2: Delete them**

```bash
cd /Users/aicoder/Documents/pocketcoder
git rm -r tests/integration/agent
git rm tests/integration/mcp/mcp-full-flow.bats tests/integration/auth/permission-gating.bats tests/health/opencode.bats
git rm tests/connection/*opencode*
```
(If a listed path does not exist, skip it and note the discrepancy in the commit body.)

- [ ] **Step 3: Verify the current suite is untouched**

Run: `ls tests/agent-c1/`
Expected: `acceptance.bats  README.md  run.sh` still present.

- [ ] **Step 4: Commit**

```bash
git commit -m "prune: delete frozen OpenCode-era integration tests"
```

---

## Task 5: Remove dead services from compose and their build contexts

**Files:**
- Modify: `docker-compose.yml`
- Delete: `services/interface/`, `services/opencode/`, `services/sandbox/`, `services/open-notebook-mcp/`

**Interfaces:**
- Produces: default `docker compose up` boots only `pocketbase`, `docker-socket-proxy-write`, `sqlpage`. `mcp-gateway` is behind the new `c3` profile.

- [ ] **Step 1: Remove the six service blocks**

Delete these top-level service blocks from `docker-compose.yml`: `interface`, `sandbox`, `surrealdb`, `open-notebook`, `open-notebook-mcp`, `poco-memory`.

- [ ] **Step 2: Fix `sqlpage`'s vestigial dependency**

In the `sqlpage` service, remove `sandbox` from its `depends_on` (keep the `pocketbase` condition).

- [ ] **Step 3: Profile the mcp-gateway**

In the `mcp-gateway` service, add:
```yaml
    profiles: ["c3"]
```

- [ ] **Step 4: Remove orphaned volumes and networks**

Under `volumes:` delete `shell_bridge`, `notebook_data`, `surrealdb_data`, `fastembed_cache`.
Under `networks:` delete `pocketcoder-control`, `pocketcoder-knowledge`.
Do NOT remove `opencode_workspace` (still mounted by pocketbase + goose), `pocketcoder-tools` (kept for mcp-gateway), or any other retained volume/network.

- [ ] **Step 5: Delete the service build-context directories**

```bash
cd /Users/aicoder/Documents/pocketcoder
git rm -r services/interface services/opencode services/sandbox services/open-notebook-mcp services/poco-memory
```
(`services/surrealdb` and `services/open-notebook` do not exist — those services are image-based, nothing to delete. Only `poco-memory` among the knowledge services has a build context.)

- [ ] **Step 5b: Delete the legacy OpenCode test-compose override**

`docker-compose.test.yml` wires a `test` service to the now-deleted `sandbox` and `opencode` (`depends_on: sandbox`/`opencode`, `SANDBOX_HOST=sandbox`, `OPENCODE_URL`). It is the OpenCode-era test harness; `docker-compose.agent-test.yml` is the live replacement.
```bash
git rm docker-compose.test.yml
```
(Also remove its now-orphaned `pocketcoder-opencode-sdk` network if that network is defined only in this file — confirm with `grep -rn pocketcoder-opencode-sdk docker-compose*.yml`.)

- [ ] **Step 6: Validate every compose profile parses**

Run:
```bash
cd /Users/aicoder/Documents/pocketcoder
for p in "" "--profile agent" "--profile c3" "--profile tailscale" "--profile caddy" "--profile foss"; do
  echo "profile: ${p:-<default>}"
  AGENT_TEST_EMAIL=x AGENT_TEST_PASSWORD=x GOOSE_SERVER__SECRET_KEY=x ANTHROPIC_API_KEY=x \
    docker compose $p config >/dev/null && echo OK || echo FAIL
done
AGENT_TEST_EMAIL=x AGENT_TEST_PASSWORD=x GOOSE_SERVER__SECRET_KEY=x ANTHROPIC_API_KEY=x \
  docker compose -f docker-compose.yml -f docker-compose.agent-test.yml --profile agent --profile agent-test config >/dev/null && echo "agent-test OK" || echo "agent-test FAIL"
```
Expected: every line prints `OK`.

- [ ] **Step 7: Confirm the default service set is exactly three**

Run: `cd /Users/aicoder/Documents/pocketcoder && docker compose config --services | sort`
Expected: exactly `docker-socket-proxy-write`, `pocketbase`, `sqlpage`.

- [ ] **Step 8: Commit**

```bash
git add -A && git commit -m "prune: remove interface/sandbox/knowledge services, profile mcp-gateway"
```

---

## Task 6: Clean the env template

**Files:**
- Modify: `.env.template`

**Interfaces:** none.

- [ ] **Step 1: Remove OpenCode/knowledge-era keys**

Delete these lines/sections from `.env.template`: the `POCO_AGENT`/`POCO_AGENT_CMD` block, `GEMINI_API_KEY`, the `ENABLE_GO_RELAY` "Relay Configuration" block, the `OPEN_NOTEBOOK_ENCRYPTION_KEY` "Knowledge Base" block, and the `OPENCODE_EXPERIMENTAL*`/`OPENCODE_ENABLE_EXA` "Experimental" block. Keep the PocketBase credential, agent (`GOOSE_*`, `ANTHROPIC_*`), Caddy, and Tailscale sections.

- [ ] **Step 2: Verify nothing kept references a removed key**

Run: `cd /Users/aicoder/Documents/pocketcoder && grep -rn "POCO_AGENT\|ENABLE_GO_RELAY\|OPENCODE_EXPERIMENTAL\|OPEN_NOTEBOOK_ENCRYPTION_KEY" docker-compose.yml services/ 2>/dev/null | grep -v node_modules || echo "NO LIVE REFERENCES"`
Expected: `NO LIVE REFERENCES` (any remaining hit is in a deleted dir and must be gone after Task 5).

- [ ] **Step 3: Commit**

```bash
git add .env.template && git commit -m "prune: drop OpenCode/knowledge keys from .env.template"
```

---

## Task 7: Whole-repo verification and dangling-reference sweep

**Files:** none (verification only).

- [ ] **Step 1: Backend builds and tests green**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: PASS.

- [ ] **Step 2: PocketBase boots cleanly**

Run:
```bash
cd services/pocketbase && rm -rf /tmp/pb_boot_check && timeout 15 go run . serve --http=127.0.0.1:8099 --dir /tmp/pb_boot_check &
sleep 8 && curl -fsS http://127.0.0.1:8099/api/health && echo " HEALTH OK"; kill %1 2>/dev/null; rm -rf /tmp/pb_boot_check
```
Expected: `{"...":"...","code":200,...}` then `HEALTH OK`, with no startup panic about a missing collection.

- [ ] **Step 2b: Boot log must be free of dead-hook binding errors**

Confirm the boot in Step 2 logs nothing about binding hooks to `messages`, `permissions`, or `acp_terminals`.

- [ ] **Step 3: No dangling references to anything deleted**

Run:
```bash
cd /Users/aicoder/Documents/pocketcoder
grep -rn "goose-acp-relay\|open-notebook\|surrealdb\|poco-memory\|services/interface\|services/opencode\|services/sandbox\|RegisterPermissionHooks\|RegisterPermissionApi\|acp_terminals\|acp_session_id" \
  --include='*.go' --include='*.yml' --include='*.sh' --include='*.template' . 2>/dev/null \
  | grep -v node_modules | grep -v "pb_migrations/17" | grep -v "docs/"
# Bare service names in any compose file (catches override files the path-grep misses):
grep -rn "\bsandbox\b\|\bopencode\b\|\binterface\b" docker-compose*.yml 2>/dev/null | grep -v "^docker-compose.yml:.*# "
```
Expected: no output from either. Any hit outside applied migrations/docs is a miss to fix. Two EXPECTED, intentionally-left-loud hits that are NOT misses: `hooks/cron.go` (`messages` write) and `api/cron.go` (`ai_engine_session_id` read) — the known cron follow-up. Note them explicitly if they appear so a reviewer confirms they are deliberate, not oversights.

- [ ] **Step 4: The agent path still works end-to-end**

Run the live coordinator test against a local goose v1.43.0 (per `internal/agent/coordinator/live_test.go`) OR at minimum:
Run: `cd services/pocketbase && go test ./internal/agent/...`
Expected: PASS. If Docker is available, bring up `--profile agent` and confirm `tests/agent-c1/run.sh` starts (goose + pocketbase, no relay).

- [ ] **Step 5: Final commit if any sweep fixes were needed**

```bash
git add -A && git commit -m "prune: fix dangling references found in verification sweep" || echo "nothing to fix"
```

---

## Self-Review notes

- **Spec coverage:** Services delete (Task 5), collections/fields (Task 3), dead Go (Task 1), boot-critical trims (Task 2), tests (Task 4), env (Task 6), verification incl. default-3-services and loud-cron acknowledgement (Task 7). Covered.
- **Intentionally NOT done (loud, per spec):** cron's `messages` write + `ai_engine_session_id` read; the agent-definition config hooks' interface-container restart. These stay broken-on-use until their follow-ups; Task 7 Step 3 flags them so a reviewer distinguishes them from oversights.
- **Out of scope:** Flutter package, Dart model regen, `pb_schema.json` re-export, cron rewire, agent-def revamp, c3/Cognee enablement.
