# Flatten PocketBase Migration History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 10 historical schema-changing migration files in `services/pocketbase/pb_migrations/` (spanning `1740000100` → `1755000100`) with exactly two new files — `1756000000_schema.go` and `1756000100_seed.go` — that build today's final schema and seed data directly, with zero trace of anything created-then-deleted along the way (`ai_agents`, `cron_jobs`, `ai_prompts`, `ai_models`, `messages`, `chats.agent`, etc.).

**Architecture:** PocketBase has no snapshot/declarative-schema mode of its own — `migratecmd` (registered in `main.go:53` with `Automigrate: true`) always replays registered `migrations.Register(up, down)` functions in timestamp order against a `_migrations` tracking table. So "no migrations" means collapsing history into the smallest possible number of migrations, not eliminating the mechanism. `core.App` exposes `ImportCollectionsByMarshaledJSON(raw []byte, deleteMissing bool) error` (`core/collection_import.go:18`) — PocketBase's own bulk-import primitive, the same one `/api/collections` export/import and this repo's `scripts/export_schema.sh` already speak. The new schema migration embeds today's real, currently-running final schema (captured directly from a freshly-migrated app, not hand-transcribed) as a JSON file via `go:embed` and imports it in one call — this is far less error-prone than hand-writing 22 `core.NewBaseCollection` blocks, and self-verifying: the embedded JSON *is* a working schema because it came from a real running app.

**Tech Stack:** Go 1.24, PocketBase v0.36.1 (`github.com/pocketbase/pocketbase`), existing `pb_migrations` / `pb_migrations_test` packages.

## Global Constraints

- No production data to preserve — VPS will be wiped and reseeded by the user separately (not part of this plan).
- Both new migrations' `down` functions are no-ops — matches this repo's existing `ai_agents`/`cron_jobs` deletion-migration precedent (`1753000000_prune_legacy_ai_config.go`, `1755000100_remove_dead_cron_jobs.go`), and there is no data to protect via rollback.
- New files use fresh timestamps (`1756000000`, `1756000100`), not reused old ones — old timestamp numbers are retired, not recycled.
- Local dev reset is `docker compose down -v` (pb_data is a docker-managed named volume per `docker-compose.yml:11,171,285`, gitignored per `.gitignore:15-16`) — no special migration-runner steps needed for local dev.
- This plan does **not** touch the VPS. It only produces the squashed migration files; rollout is a manual step the user runs themselves (see "Rollout (manual, not automated)" at the end of this document).

---

### Task 1: Capture today's real final schema as ground truth

**Files:**
- Create (temporary, deleted at the end of Task 2): `services/pocketbase/pb_migrations/zzz_dump_test.go`
- Produces (kept): `services/pocketbase/pb_migrations/schema.json`

**Interfaces:**
- Consumes: the current (pre-squash) migration chain, still fully intact at this point.
- Produces: `services/pocketbase/pb_migrations/schema.json` — a bare JSON array of collection objects in the exact shape `app.ImportCollectionsByMarshaledJSON` and `/api/collections` both use (each object has `id`, `name`, `type`, `listRule`/`viewRule`/`createRule`/`updateRule`/`deleteRule`, `fields: [...]`, `indexes: [...]`). Task 2 embeds this file verbatim.

This task's entire point is avoiding manual transcription of 10 migration files (1740000100_consolidated_schema.go is 483 lines alone) into a new file by hand — that's exactly how a subtle bug (a field renamed then never renamed back in your head, an index that changed shape) slips through unnoticed. Instead, run the actual current migration chain against a truly fresh (not PocketBase's bundled demo-fixture) database and dump what really exists.

- [ ] **Step 1: Write the schema-dumping test**

`tests.NewTestApp()` (the usual PocketBase test helper) is NOT safe to use here — when called with no explicit `DataDir` it clones PocketBase's own bundled demo fixture data (`demo1`, `demo2`, a `rel` field on `users`, etc.) as a starting point, then layers our migrations on top. That pollutes the dump with collections that don't belong to this app at all. Build the app manually against a genuinely empty temp dir instead:

```go
// services/pocketbase/pb_migrations/zzz_dump_test.go
package pb_migrations_test

import (
	"encoding/json"
	"fmt"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestDumpFinalSchema(t *testing.T) {
	dataDir := t.TempDir()
	app := core.NewBaseApp(core.BaseAppConfig{DataDir: dataDir, EncryptionEnv: "pb_test_env"})
	if err := app.Bootstrap(); err != nil {
		t.Fatal(err)
	}
	defer app.ResetBootstrapState()
	if err := app.RunAllMigrations(); err != nil {
		t.Fatal(err)
	}

	cols, err := app.FindAllCollections()
	if err != nil {
		t.Fatal(err)
	}

	var raw []*core.Collection
	for _, c := range cols {
		if c.System {
			// true PocketBase-internal collections (_authOrigins, _externalAuths,
			// _mfas, _otps, _superusers, ...) are always created by Bootstrap()
			// itself, not by our migrations — never import these.
			continue
		}
		raw = append(raw, c)
	}

	b, _ := json.MarshalIndent(raw, "", "  ")
	fmt.Println("===SCHEMA_DUMP_START===")
	fmt.Println(string(b))
	fmt.Println("===SCHEMA_DUMP_END===")
}
```

- [ ] **Step 2: Run it and extract the dump**

Run: `cd services/pocketbase && go test ./pb_migrations/... -run TestDumpFinalSchema -v`

Expected: `PASS`, with a `===SCHEMA_DUMP_START===` / `===SCHEMA_DUMP_END===` block containing a JSON array in stdout.

Extract everything between (not including) those two markers into `services/pocketbase/pb_migrations/schema.json`. Verify it's valid and contains exactly 22 collections:

```bash
python3 -c "import json; d=json.load(open('services/pocketbase/pb_migrations/schema.json')); print(len(d)); print(sorted(c['name'] for c in d))"
```

Expected output: `22` followed by this exact sorted list:
```
['chats', 'devices', 'goose_sessions', 'harness_auth', 'harness_models', 'harnesses', 'healthchecks', 'mcp_servers', 'models', 'notification_rules', 'poco_configs', 'prompts', 'provider_keys', 'proposals', 'questions', 'sandbox_agents', 'sandbox_configs', 'schedule_owners', 'sops', 'ssh_keys', 'tool_permissions', 'users']
```

- [ ] **Step 3: Do NOT commit `zzz_dump_test.go` yet**

It gets deleted in Task 2 Step 5 once the real squash files exist and pass their own tests. Leave both `zzz_dump_test.go` and `schema.json` as uncommitted working files for now.

---

### Task 2: Write the squashed schema migration

**Files:**
- Create: `services/pocketbase/pb_migrations/1756000000_schema.go`
- Create: `services/pocketbase/pb_migrations/schema.json` (produced by Task 1, moved into place here)
- Create: `services/pocketbase/pb_migrations/1756000000_schema_test.go`
- Delete: `services/pocketbase/pb_migrations/1740000100_consolidated_schema.go`
- Delete: `services/pocketbase/pb_migrations/1748000100_acp_schema.go`
- Delete: `services/pocketbase/pb_migrations/1748000200_poco_config_fields.go`
- Delete: `services/pocketbase/pb_migrations/1748000300_tool_perms_index.go`
- Delete: `services/pocketbase/pb_migrations/1748000400_drop_unused_fields.go`
- Delete: `services/pocketbase/pb_migrations/1748000500_goose_sessions.go`
- Delete: `services/pocketbase/pb_migrations/1752000000_prune_legacy_runtime.go`
- Delete: `services/pocketbase/pb_migrations/1752000100_poco_config_mode.go`
- Delete: `services/pocketbase/pb_migrations/1753000000_prune_legacy_ai_config.go`
- Delete: `services/pocketbase/pb_migrations/1755000000_schedule_owners.go`
- Delete: `services/pocketbase/pb_migrations/1755000000_schedule_owners_test.go`
- Delete: `services/pocketbase/pb_migrations/1755000100_remove_dead_cron_jobs.go`
- Delete: `services/pocketbase/pb_migrations/1755000100_remove_dead_cron_jobs_test.go`
- Delete: `services/pocketbase/pb_migrations/zzz_dump_test.go` (from Task 1, no longer needed once this task's test passes)

**Interfaces:**
- Consumes: `services/pocketbase/pb_migrations/schema.json` (from Task 1).
- Produces: nothing new consumed by later tasks — `1756000100_seed.go` (Task 3) only depends on the collections this task creates existing by name (`users`, `_superusers`, `tool_permissions`), not on any Go symbol from this file.

- [ ] **Step 1: Write the failing test**

This test currently fails because none of the 10 old migration files have been deleted yet — `schedule_owners` and `cron_jobs`'s absence already hold, but `ai_agents` still exists (not yet pruned away by nothing, since the prune migration is still present)... actually at this point in the plan the OLD migrations are still present and already produce the correct final state (that's the premise of Task 1's dump). So this test will PASS immediately if run now — which is expected and fine, because RED here comes from a different place: write the test now, confirm it passes against the OLD chain (sanity-checking the dump was faithful), THEN delete the old files in Step 3 and confirm the test still passes against ONLY the two new files. The real regression-catching moment is Step 4, not Step 2.

```go
// services/pocketbase/pb_migrations/1756000000_schema_test.go
package pb_migrations_test

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestFinalSchemaCollectionsExist(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	expected := map[string][]string{
		"users":               {"role"},
		"chats":                {"title", "user", "poco_config", "harness_model_override"},
		"sandbox_agents":       {"sandbox_agent_id", "delegating_agent_id", "chat"},
		"ssh_keys":             {"user", "public_key", "fingerprint"},
		"tool_permissions":     {"tool", "pattern", "action", "poco_config", "sandbox_config"},
		"healthchecks":         {"name", "status"},
		"mcp_servers":          {"name", "status", "config"},
		"proposals":            {"name", "content", "authored_by", "status"},
		"sops":                 {"name", "content", "signature", "proposal"},
		"questions":            {"chat", "question", "status"},
		"devices":              {"user", "push_token", "push_service"},
		"notification_rules":   {"user", "rules"},
		"harnesses":            {"name", "cli_id", "acp_transport"},
		"models":               {"name", "provider"},
		"harness_models":       {"harness", "model", "harness_model_id"},
		"provider_keys":        {"user", "provider", "env_vars"},
		"harness_auth":         {"user", "harness", "auth_type", "status"},
		"prompts":              {"name", "body"},
		"poco_configs":         {"name", "harness_model", "system_prompt"},
		"sandbox_configs":      {"name", "harness_model", "system_prompt"},
		"goose_sessions":       {"chat", "user", "goose_session_id"},
		"schedule_owners":      {"user", "goose_schedule_id", "display_name"},
	}

	for name, fields := range expected {
		col, err := app.FindCollectionByNameOrId(name)
		if err != nil {
			t.Fatalf("collection %q not found: %v", name, err)
			continue
		}
		for _, f := range fields {
			if col.Fields.GetByName(f) == nil {
				t.Errorf("collection %q missing field %q", name, f)
			}
		}
	}
}

func TestDeadCollectionsDoNotExist(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	for _, name := range []string{"ai_agents", "ai_prompts", "ai_models", "cron_jobs", "messages"} {
		if _, err := app.FindCollectionByNameOrId(name); err == nil {
			t.Errorf("collection %q should not exist but was found", name)
		}
	}
}

func TestScheduleOwnersUniqueGooseScheduleId(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	col, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatal(err)
	}
	usersCol, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	user := core.NewRecord(usersCol)
	user.SetEmail("scheduler-owner@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	rec := core.NewRecord(col)
	rec.Set("user", user.Id)
	rec.Set("goose_schedule_id", "abc123")
	rec.Set("display_name", "My Schedule")
	if err := app.Save(rec); err != nil {
		t.Fatalf("save schedule_owners record: %v", err)
	}

	dup := core.NewRecord(col)
	dup.Set("user", user.Id)
	dup.Set("goose_schedule_id", "abc123")
	dup.Set("display_name", "Duplicate")
	if err := app.Save(dup); err == nil {
		t.Fatal("expected unique-index violation for duplicate goose_schedule_id")
	}
}

func TestGooseSessionsUniqueIndexes(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	chatsCol, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		t.Fatal(err)
	}
	usersCol, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	sessCol, err := app.FindCollectionByNameOrId("goose_sessions")
	if err != nil {
		t.Fatal(err)
	}

	user := core.NewRecord(usersCol)
	user.SetEmail("goose-user@example.com")
	user.SetPassword("password123")
	if err := app.Save(user); err != nil {
		t.Fatal(err)
	}

	chat := core.NewRecord(chatsCol)
	chat.Set("title", "t")
	chat.Set("user", user.Id)
	if err := app.Save(chat); err != nil {
		t.Fatal(err)
	}

	sess := core.NewRecord(sessCol)
	sess.Set("chat", chat.Id)
	sess.Set("user", user.Id)
	sess.Set("goose_session_id", "gs-1")
	if err := app.Save(sess); err != nil {
		t.Fatalf("save goose_sessions record: %v", err)
	}

	dup := core.NewRecord(sessCol)
	dup.Set("chat", chat.Id)
	dup.Set("user", user.Id)
	dup.Set("goose_session_id", "gs-2")
	if err := app.Save(dup); err == nil {
		t.Fatal("expected unique-index violation for duplicate chat")
	}
}
```

- [ ] **Step 2: Run it to verify it passes against the still-intact old migration chain**

Run: `cd services/pocketbase && go test ./pb_migrations/... -run 'TestFinalSchemaCollectionsExist|TestDeadCollectionsDoNotExist|TestScheduleOwnersUniqueGooseScheduleId|TestGooseSessionsUniqueIndexes' -v`

Expected: `PASS` (all 4 tests) — this is a sanity check that the test itself is correct against known-good current behavior, not the TDD red step. The real red/green cycle for the squash itself happens in Steps 3–4.

- [ ] **Step 3: Write the squashed schema migration**

Move `schema.json` from Task 1 into its final location (it's already there if Task 1 wrote it directly to this path):

```bash
ls services/pocketbase/pb_migrations/schema.json  # should already exist from Task 1
```

```go
// services/pocketbase/pb_migrations/1756000000_schema.go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// Package pb_migrations: this file defines PocketCoder's full PocketBase
// schema in its final, current-state form. It replaces what used to be 10
// separate create/alter/drop migrations (spanning 1740000100–1755000100)
// with one import of a schema snapshot — see schema.json in this directory,
// which is the literal JSON PocketBase's own /api/collections export uses
// (the same shape scripts/export_schema.sh produces). If you need to change
// the schema going forward, edit schema.json directly (or make the change
// via the PocketBase Admin UI locally and re-export it) rather than adding
// another timestamped migration file, until this file grows large enough
// that splitting it out makes sense again.
package pb_migrations

import (
	_ "embed"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

//go:embed schema.json
var schemaJSON []byte

func init() {
	migrations.Register(func(app core.App) error {
		return app.ImportCollectionsByMarshaledJSON(schemaJSON, false)
	}, func(app core.App) error {
		// No-op: there is no production data to protect via rollback, and
		// this repo's existing deletion migrations (e.g.
		// 1753000000_prune_legacy_ai_config.go) already establish the
		// precedent of a no-op down for schema changes with nothing worth
		// reverting to.
		return nil
	})
}
```

- [ ] **Step 4: Delete the 10 old migration files and run the tests — this is the real RED/GREEN moment**

```bash
cd services/pocketbase/pb_migrations
git rm 1740000100_consolidated_schema.go
git rm 1748000100_acp_schema.go
git rm 1748000200_poco_config_fields.go
git rm 1748000300_tool_perms_index.go
git rm 1748000400_drop_unused_fields.go
git rm 1748000500_goose_sessions.go
git rm 1752000000_prune_legacy_runtime.go
git rm 1752000100_poco_config_mode.go
git rm 1753000000_prune_legacy_ai_config.go
git rm 1755000000_schedule_owners.go
git rm 1755000000_schedule_owners_test.go
git rm 1755000100_remove_dead_cron_jobs.go
git rm 1755000100_remove_dead_cron_jobs_test.go
```

Note: `1740000101_consolidated_seed.go` (the seed file) is intentionally NOT deleted yet — Task 3 replaces it. Deleting it here would make every test in this task fail on missing seeded data it doesn't actually check, but leaving stale seed logic referencing deleted collections (`ai_prompts`, `ai_models`, `ai_agents`) around is still fine because those `FindCollectionByNameOrId` calls just no-op (return an error the seed code doesn't currently check) rather than crash — confirmed by this exact behavior already occurring in production today between when `1753000000_prune_legacy_ai_config.go` deleted `ai_agents` and now.

Run: `cd services/pocketbase && go build ./... && go vet ./pb_migrations/...`
Expected: succeeds (the deletions don't break compilation — nothing else in the module imports symbols from the deleted files, since migrations register themselves via `init()`).

Run: `cd services/pocketbase && go test ./pb_migrations/... -v`
Expected: `TestFinalSchemaCollectionsExist`, `TestDeadCollectionsDoNotExist`, `TestScheduleOwnersUniqueGooseScheduleId`, and `TestGooseSessionsUniqueIndexes` all still `PASS` — now running against ONLY `1756000000_schema.go` + the still-present old seed file, proving the squashed schema migration alone reproduces every collection/field/index the old 10-file chain built. If any of these fail, `schema.json` is missing something — re-run Task 1's dump test to re-verify (do NOT hand-patch `schema.json`; regenerate it, since a hand-patch defeats the entire point of Task 1).

- [ ] **Step 5: Delete the Task 1 scratch test**

```bash
git rm services/pocketbase/pb_migrations/zzz_dump_test.go
```

Run: `cd services/pocketbase && go test ./pb_migrations/... -v`
Expected: same 4 tests still `PASS` (this file was never load-bearing, just how `schema.json` got produced).

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/pb_migrations/1756000000_schema.go \
        services/pocketbase/pb_migrations/1756000000_schema_test.go \
        services/pocketbase/pb_migrations/schema.json
git commit -m "feat(pocketbase): squash 10 migrations into one schema import

Replaces the historical create/alter/drop migration chain
(1740000100-1755000100) with a single ImportCollectionsByMarshaledJSON
call against a schema snapshot captured directly from the current
final-state app, not hand-transcribed. Old migration files removed."
```

---

### Task 3: Write the squashed seed migration

**Files:**
- Create: `services/pocketbase/pb_migrations/1756000100_seed.go`
- Delete: `services/pocketbase/pb_migrations/1740000101_consolidated_seed.go`
- Test: `services/pocketbase/pb_migrations/1756000100_seed_test.go`

**Interfaces:**
- Consumes: `users`, `_superusers`, `tool_permissions` collections (from Task 2's `1756000000_schema.go`) by name only — no Go-level dependency.
- Produces: nothing consumed by later tasks.

The current seed file (`1740000101_consolidated_seed.go`) seeds four things: (1) an admin user, (2) an agent user, (3) a superuser, (4) an "AI registry" of a prompt/model/agent record plus 10 `tool_permissions` rows, 4 of which try to link to the agent record it just created. Items (1)–(3) and the `tool_permissions` rows are still meaningful today. The AI-registry prompt/model/agent records are NOT — `ai_prompts`, `ai_models`, and `ai_agents` were deleted by `1753000000_prune_legacy_ai_config.go`, so on every install since that migration landed, those `FindCollectionByNameOrId` calls have silently returned `nil, err` and every subsequent `app.Save` on a record built from a `nil` collection has been failing (silently, since the seed's outer closure only checks `err` on some of these saves and the prompt/model/agent saves are checked — meaning today's seed migration actually already returns an error and seed migration effectively FAILS partway through on every fresh install right now, before reaching the tool_permissions section entirely). This plan fixes that live bug as a side effect of the squash: since the AI-registry section seeds into now-nonexistent collections, it must be deleted, not carried forward.

Confirmed from Task 1's dump: the final `tool_permissions` state is 10 rows, all with empty `poco_config`/`sandbox_config` (never linked to an agent) — the original "per-agent override" section's 4 rows still get created, just without any working link, since the field name it tried to set (`"agent"`) doesn't exist on the collection at all today (fields with unrecognized names are silently ignored by `record.Set`, not errors) — the squashed version reproduces this exact same flat, unlinked shape rather than the original's already-broken attempt to link them.

- [ ] **Step 1: Write the failing test**

```go
// services/pocketbase/pb_migrations/1756000100_seed_test.go
package pb_migrations_test

import (
	"os"
	"testing"

	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestSeedCreatesAdminAgentAndSuperuser(t *testing.T) {
	os.Setenv("POCKETBASE_ADMIN_EMAIL", "admin@example.com")
	os.Setenv("POCKETBASE_ADMIN_PASSWORD", "adminpass123")
	os.Setenv("AGENT_EMAIL", "agent@example.com")
	os.Setenv("AGENT_PASSWORD", "agentpass123")
	os.Setenv("POCKETBASE_SUPERUSER_EMAIL", "super@example.com")
	os.Setenv("POCKETBASE_SUPERUSER_PASSWORD", "superpass123")
	defer func() {
		os.Unsetenv("POCKETBASE_ADMIN_EMAIL")
		os.Unsetenv("POCKETBASE_ADMIN_PASSWORD")
		os.Unsetenv("AGENT_EMAIL")
		os.Unsetenv("AGENT_PASSWORD")
		os.Unsetenv("POCKETBASE_SUPERUSER_EMAIL")
		os.Unsetenv("POCKETBASE_SUPERUSER_PASSWORD")
	}()

	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	admin, err := app.FindAuthRecordByEmail("users", "admin@example.com")
	if err != nil {
		t.Fatalf("admin user not seeded: %v", err)
	}
	if admin.GetString("role") != "admin" {
		t.Errorf("expected admin role, got %q", admin.GetString("role"))
	}

	agent, err := app.FindAuthRecordByEmail("users", "agent@example.com")
	if err != nil {
		t.Fatalf("agent user not seeded: %v", err)
	}
	if agent.GetString("role") != "agent" {
		t.Errorf("expected agent role, got %q", agent.GetString("role"))
	}

	if _, err := app.FindAuthRecordByEmail("_superusers", "super@example.com"); err != nil {
		t.Fatalf("superuser not seeded: %v", err)
	}
}

func TestSeedCreatesTenToolPermissions(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	col, err := app.FindCollectionByNameOrId("tool_permissions")
	if err != nil {
		t.Fatal(err)
	}
	recs, err := app.FindAllRecords(col)
	if err != nil {
		t.Fatal(err)
	}
	if len(recs) != 10 {
		t.Fatalf("expected 10 seeded tool_permissions rows, got %d", len(recs))
	}

	found := false
	for _, r := range recs {
		if r.GetString("tool") == "bash" && r.GetString("pattern") == "ls *" && r.GetString("action") == "allow" {
			found = true
		}
	}
	if !found {
		t.Error("expected a bash/'ls *'/allow row among seeded tool_permissions")
	}
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd services/pocketbase && go test ./pb_migrations/... -run 'TestSeedCreatesAdminAgentAndSuperuser|TestSeedCreatesTenToolPermissions' -v`

Expected: `FAIL` — at this point `1740000101_consolidated_seed.go` still exists but its AI-registry section fails partway through (per the bug described above), meaning either the migration itself errors during `RunAllMigrations()` (causing `tests.NewTestApp()` to fail outright, which surfaces as `t.Fatal` on the first line) or, if it errors are swallowed somewhere in the chain, `tool_permissions` never reaches 10 rows. Confirm the failure message points at seeding, not at your test code being wrong.

- [ ] **Step 3: Delete the old seed file and write the new one**

```bash
git rm services/pocketbase/pb_migrations/1740000101_consolidated_seed.go
```

```go
// services/pocketbase/pb_migrations/1756000100_seed.go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

package pb_migrations

import (
	"os"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		seedUser := func(email, password, role string) error {
			if email == "" || password == "" {
				return nil
			}
			existing, _ := app.FindAuthRecordByEmail("users", email)
			if existing != nil {
				return nil
			}
			collection, err := app.FindCollectionByNameOrId("users")
			if err != nil {
				return err
			}
			record := core.NewRecord(collection)
			record.SetEmail(email)
			record.SetPassword(password)
			record.Set("role", role)
			record.Set("verified", true)
			return app.Save(record)
		}

		if err := seedUser(os.Getenv("POCKETBASE_ADMIN_EMAIL"), os.Getenv("POCKETBASE_ADMIN_PASSWORD"), "admin"); err != nil {
			return err
		}
		if err := seedUser(os.Getenv("AGENT_EMAIL"), os.Getenv("AGENT_PASSWORD"), "agent"); err != nil {
			return err
		}

		superEmail := os.Getenv("POCKETBASE_SUPERUSER_EMAIL")
		superPass := os.Getenv("POCKETBASE_SUPERUSER_PASSWORD")
		if superEmail != "" && superPass != "" {
			existing, _ := app.FindAuthRecordByEmail("_superusers", superEmail)
			if existing == nil {
				collection, err := app.FindCollectionByNameOrId("_superusers")
				if err != nil {
					return err
				}
				super := core.NewRecord(collection)
				super.SetEmail(superEmail)
				super.SetPassword(superPass)
				if err := app.Save(super); err != nil {
					return err
				}
			}
		}

		tpColl, err := app.FindCollectionByNameOrId("tool_permissions")
		if err != nil {
			return err
		}
		seedToolPerm := func(tool, pattern, action string) error {
			rec := core.NewRecord(tpColl)
			rec.Set("tool", tool)
			rec.Set("pattern", pattern)
			rec.Set("action", action)
			rec.Set("active", true)
			return app.Save(rec)
		}

		defaults := [][3]string{
			{"*", "*", "ask"},
			{"bash", "ls *", "allow"},
			{"check_pc_updates", "*", "allow"},
			{"mcp_catalog", "*", "allow"},
			{"mcp_status", "*", "allow"},
			{"mcp_request", "*", "ask"},
			{"bash", "*", "ask"},
			{"edit", "*", "ask"},
			{"skill", "*", "ask"},
			{"poco-agents_*", "*", "ask"},
		}
		for _, d := range defaults {
			if err := seedToolPerm(d[0], d[1], d[2]); err != nil {
				return err
			}
		}

		return nil
	}, func(app core.App) error {
		// No-op: matches 1756000000_schema.go's down and this repo's
		// existing deletion-migration precedent — no data to protect.
		return nil
	})
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd services/pocketbase && go test ./pb_migrations/... -v`

Expected: `PASS` for every test in the package, including `TestSeedCreatesAdminAgentAndSuperuser`, `TestSeedCreatesTenToolPermissions`, and everything from Task 2.

- [ ] **Step 5: Run the full backend test suite and vet**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`

Expected: all pass, no build errors, no vet warnings. This confirms nothing outside `pb_migrations` referenced any symbol from the deleted files.

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/pb_migrations/1756000100_seed.go \
        services/pocketbase/pb_migrations/1756000100_seed_test.go
git commit -m "feat(pocketbase): squash seed migration, drop dead AI-registry seeding

The old seed file's AI-registry section (ai_prompts/ai_models/ai_agents)
seeded into collections deleted by 1753000000_prune_legacy_ai_config.go,
meaning it has been silently failing on every fresh install since. The
squashed seed keeps only what still resolves: admin/agent/superuser
accounts and the 10 default tool_permissions rows."
```

---

### Task 4: Update CLAUDE.md's Model Generation Pipeline note

**Files:**
- Modify: `CLAUDE.md` (repo root)

**Interfaces:**
- Consumes: nothing code-level — this is documentation only.
- Produces: nothing consumed by later tasks.

- [ ] **Step 1: Add a note about the squash to the "Model Generation Pipeline" section**

Read the current section first:

```bash
grep -n "Model Generation Pipeline" -A 10 CLAUDE.md
```

Add one paragraph directly under the `## Model Generation Pipeline` heading, above the numbered steps, so future edits know where schema now lives:

```markdown
## Model Generation Pipeline

PocketBase schema lives in exactly two migration files:
`services/pocketbase/pb_migrations/1756000000_schema.go` (imports
`schema.json`, a full collection-schema snapshot) and
`1756000100_seed.go` (default users/tool-permissions). Make schema
changes by editing `schema.json` directly (or making the change via the
PocketBase Admin UI locally, then re-running `scripts/export_schema.sh`
and copying its output over `schema.json`) rather than appending a new
timestamped migration file — until one of these two files grows large
enough that splitting it out makes sense again.

After changing PB collections/schema, run this sequence:
```

(the existing 5 numbered steps continue unchanged below this)

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: note squashed migration files in Model Generation Pipeline"
```

---

## Verification (run after all tasks)

- [ ] `cd services/pocketbase && go build ./... && go vet ./... && go test ./...` — all green.
- [ ] `ls services/pocketbase/pb_migrations/*.go` — should list exactly 4 files: `1756000000_schema.go`, `1756000000_schema_test.go`, `1756000100_seed.go`, `1756000100_seed_test.go`, plus `schema.json` (not `.go`).
- [ ] `docker compose down -v && docker compose build pocketbase && docker compose up -d pocketbase` locally — confirms a real fresh-volume boot applies the two new migrations cleanly (not just the Go test harness). Check logs for migration errors: `docker compose logs pocketbase | grep -i migrat`.
- [ ] Confirm the app's existing local `pb_data` volume (if any) doesn't need touching for this verification — `down -v` already removes it; this is expected and intentional for this plan's purposes, not a mistake.

## Rollout (manual, not automated)

This plan does not touch the VPS. When ready, the user runs on the VPS themselves:

```bash
docker compose stop pocketbase
docker volume rm pocketcoder_pb_data   # exact volume name may differ — check `docker volume ls` first
docker compose up -d pocketbase
```

This wipes all existing VPS data (expected — no production users to preserve) and lets the two squashed migrations build a fresh schema from scratch.
