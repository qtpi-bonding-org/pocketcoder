# Scheduler UI + Retirement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give PocketCoder a real UI for Goose's scheduler (create/list/pause/rename/run-now/delete recurring recipe runs), with fired runs imported into the normal chat feed, and retire the broken bespoke `cron_jobs` feature left over from the OpenCode era.

**Architecture:** Two independent halves. (1) Synchronous CRUD routes (`services/pocketbase/internal/api/schedules.go`) that the Flutter Scheduler screen calls directly, each opening a fresh `AdminConn` and forwarding to Goose's `_goose/unstable/schedules/*` methods, backed by a new `schedule_owners` PocketBase collection that tracks per-user ownership (Goose's own schedule namespace has no user concept). (2) An async importer (`services/pocketbase/internal/hooks/schedule_importer.go`) — a `app.Cron()`-driven poll plus a run-now fast path — that notices when a schedule has fired and turns the resulting Goose session into an ordinary `chats` + `goose_sessions` row, which the existing chat-open replay mechanism (`StreamColdReplay`) then renders with zero new message-persistence code.

**Tech Stack:** Go (PocketBase hooks/migrations, ACP coordinator, `github.com/coder/acp-go-sdk`), Dart/Flutter (Cubit/freezed/injectable).

## Global Constraints

- Goose version pinned: `v1.43.0` (`services/goose/Dockerfile`) — every ACP method name/shape in this plan is verified against that exact tag, cloned at `.independent_repos/goose_reference` (gitignored, not committed).
- `client/CLAUDE.md` rules apply to all Flutter work: never use `!`; cubits are plain `Cubit<T>` (this codebase's actual precedent for every prior screen, not the documented `AppCubit<T>`); state is `@freezed` + `IUiFlowState` with `status`/`error`, `status: UiFlowStatus.success` set explicitly; every repository method wrapped in `tryMethod` with a typed exception; DI via `@injectable`(cubits)/`@lazySingleton`(repos); l10n dot-notation keys via `context.l10n.*`, never hardcode user-facing strings.
- Root `CLAUDE.md`'s PocketBase Schema Conventions rule applies to Task 1: PocketBase always owns its own PK; an external system's id is a plain field, never the PK.
- Root `CLAUDE.md`'s Model Generation Pipeline applies to Task 6 (schema migration): rebuild containers → export schema → regenerate Dart models → `build_runner build`.
- This repo has no production instances yet, so dead-collection removal is done directly (a clean deletion migration, or flattening into a base-schema file when the collection is self-contained in one file) rather than layered backwards-compatible migrations — see Task 6 for the precedent this plan follows (`1753000000_prune_legacy_ai_config.go`, not the "flatten into base schema" shortcut used for `skills`, since `cron_jobs` is entangled across three migration files).
- `RecipeDto` (Goose, `acp-schema.json`) requires only `{title, description}`; `prompt` is optional but is the only field this plan ever sets beyond title/description. No `cwd` field exists — an imported chat's working directory on replay is whatever the viewer's active `poco_config` resolves to, not necessarily where the recipe ran. Documented, not fixed (Goose-side limitation, out of this plan's control).
- Out of scope (do not build): editing a schedule's recipe/prompt after creation, a cron-expression builder/preset UI, `running-job/kill` and `running-job/inspect`, recipe authoring beyond the single `prompt` field.

---

## File Structure

**Go — new:**
- `services/pocketbase/pb_migrations/1755000000_schedule_owners.go` — `schedule_owners` collection.
- `services/pocketbase/pb_migrations/1755000100_remove_dead_cron_jobs.go` — retirement migration.
- `services/pocketbase/internal/api/schedules.go` — CRUD + run-now routes, request/response structs mirroring Goose's schedule schemas.
- `services/pocketbase/internal/api/schedules_test.go`
- `services/pocketbase/internal/hooks/schedule_importer.go` — `ImportSession` (exported, shared by the poller and the run-now fast path), `importFn`, `RegisterScheduleImportHooks`.
- `services/pocketbase/internal/hooks/schedule_importer_test.go`

**Go — modified:**
- `services/pocketbase/main.go` — register the new API/hooks; remove the old cron registrations (Task 6).

**Go — deleted (Task 6):**
- `services/pocketbase/internal/api/cron.go`
- `services/pocketbase/internal/hooks/cron.go`

**Flutter — new (mirrors the `skills` package shape, the closest existing example — a pure-passthrough-plus-one-owner-table screen):**
- `lib/domain/models/schedule.dart`
- `lib/domain/scheduler/i_scheduler_repository.dart`
- `lib/infrastructure/scheduler/scheduler_repository.dart`
- `lib/application/scheduler/scheduler_cubit.dart`, `scheduler_state.dart`
- `lib/presentation/scheduler/scheduler_screen.dart`

**Flutter — deleted (Task 6):**
- `lib/domain/models/cron_job.dart` (+ generated `.freezed.dart`/`.g.dart`)

---

### Task 1: `schedule_owners` PocketBase collection

**Files:**
- Create: `services/pocketbase/pb_migrations/1755000000_schedule_owners.go`
- Test: `services/pocketbase/pb_migrations/1755000000_schedule_owners_test.go`

**Interfaces:**
- Consumes: `ptr(s string) *string` (package-level helper, `1740000100_consolidated_schema.go:481`, same `pb_migrations` package — no import needed).
- Produces: PocketBase collection `schedule_owners` with fields `user` (relation, required), `goose_schedule_id` (text, required, unique-indexed), `display_name` (text, required). Every later task's Go code references these exact field names via `record.GetString("goose_schedule_id")` etc.

- [ ] **Step 1: Write the failing test**

```go
// services/pocketbase/pb_migrations/1755000000_schedule_owners_test.go
package pb_migrations_test

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestScheduleOwnersCollectionExists(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	col, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatalf("schedule_owners collection not found: %v", err)
	}

	for _, name := range []string{"user", "goose_schedule_id", "display_name"} {
		if col.Fields.GetByName(name) == nil {
			t.Errorf("schedule_owners missing field %q", name)
		}
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./pb_migrations/... -run TestScheduleOwnersCollectionExists -v`
Expected: FAIL — `schedule_owners collection not found`

- [ ] **Step 3: Write the migration**

```go
// services/pocketbase/pb_migrations/1755000000_schedule_owners.go
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
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// schedule_owners is the one piece of PocketBase-side state the Scheduler
// UI needs (see docs/superpowers/specs/2026-07-23-scheduler-ui-design.md's
// Component 1). Goose owns everything about a schedule's execution (cron,
// paused state, last run, the recipe itself) in its own flat, userless
// namespace, keyed by a schedule id PocketBase must generate and supply at
// creation time. This collection only tracks what Goose cannot: who a
// schedule belongs to, and a user-editable display name decoupled from
// Goose's immutable id (Goose has no rename RPC). Per the "PocketBase
// Schema Conventions" rule in root CLAUDE.md, this collection's own `id`
// is PocketBase's normal auto id — goose_schedule_id is a plain
// unique-indexed field, never the PK.
func init() {
	migrations.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("_pb_users_auth_")
		if err != nil {
			return err
		}

		collection := core.NewBaseCollection("schedule_owners")
		collection.Id = "pc_schedule_owners"
		collection.Fields.Add(
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "goose_schedule_id", Required: true},
			&core.TextField{Name: "display_name", Required: true},
		)
		collection.ListRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		collection.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		collection.Indexes = []string{
			"CREATE UNIQUE INDEX idx_schedule_owners_goose_schedule_id ON schedule_owners (goose_schedule_id)",
		}
		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("schedule_owners")
		if err != nil {
			return err
		}
		return app.Delete(collection)
	})
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./pb_migrations/... -run TestScheduleOwnersCollectionExists -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/pb_migrations/1755000000_schedule_owners.go services/pocketbase/pb_migrations/1755000000_schedule_owners_test.go
git commit -m "feat(scheduler): add schedule_owners collection"
```

---

### Task 2: `schedules.go` — list/create/rename/update-cron/pause/unpause/delete routes

**Files:**
- Create: `services/pocketbase/internal/api/schedules.go`
- Test: `services/pocketbase/internal/api/schedules_test.go`

**Interfaces:**
- Consumes: `dialAdmin(re *core.RequestEvent, coord func() *coordinator.Coordinator) (acp.Conn, error)` (already defined in `skills.go`, same `api` package — do not redefine). `acp.Conn.CallExtension(ctx, method string, params any) (json.RawMessage, error)`. `fakeAdminConn`/`fakeCoordWith` (already defined in `skills_test.go`, same package — reuse directly, do not redeclare).
- Produces: `resolveOwnedSchedule(app core.App, userID, id string) (*core.Record, error)`, `scheduledJobDto`, `recipeDto`, `scheduleResp` — Task 4's run-now handler and Task 3's importer both build on these shapes (though the importer, in package `hooks`, declares its own copies rather than importing them — this codebase's established convention for small per-package request/response structs, matching how `fakeAdminConn` itself is re-declared per package rather than exported).
- Routes registered: `POST /api/pocketcoder/schedules/{list,create,rename,update-cron,pause,unpause,delete}`. `run-now` is deliberately not registered here — it depends on `hooks.ImportSession`, added in Task 3, and `runScheduleNowAndImport`, added in Task 4. Task 2 alone must compile and pass its own tests.

- [ ] **Step 1: Write the failing tests**

```go
// services/pocketbase/internal/api/schedules_test.go
package api

import (
	"context"
	"encoding/json"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func newTestUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(col)
	u.SetEmail(email)
	u.SetPassword("password123")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func newScheduleOwner(t *testing.T, app core.App, userID, gooseScheduleID, displayName string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(col)
	rec.Set("user", userID)
	rec.Set("goose_schedule_id", gooseScheduleID)
	rec.Set("display_name", displayName)
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

func TestResolveOwnedSchedule_RejectsForeignOwner(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	owner := newTestUser(t, app, "owner@example.com")
	stranger := newTestUser(t, app, "stranger@example.com")
	rec := newScheduleOwner(t, app, owner.Id, "gsid-1", "Nightly Sync")

	if _, err := resolveOwnedSchedule(app, stranger.Id, rec.Id); err == nil {
		t.Fatal("expected resolveOwnedSchedule to reject a caller who does not own the schedule")
	}
}

func TestResolveOwnedSchedule_AllowsOwner(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	owner := newTestUser(t, app, "owner2@example.com")
	rec := newScheduleOwner(t, app, owner.Id, "gsid-2", "Nightly Sync")

	got, err := resolveOwnedSchedule(app, owner.Id, rec.Id)
	if err != nil {
		t.Fatalf("resolveOwnedSchedule: %v", err)
	}
	if got.Id != rec.Id {
		t.Fatalf("got record %q, want %q", got.Id, rec.Id)
	}
}

func TestListSchedules_MergesOwnerRowsWithGooseState(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	owner := newTestUser(t, app, "owner3@example.com")
	newScheduleOwner(t, app, owner.Id, "gsid-mine", "Mine")
	// A schedule owned by someone else must never appear.
	other := newTestUser(t, app, "other@example.com")
	newScheduleOwner(t, app, other.Id, "gsid-other", "Not mine")

	fc := &fakeAdminConn{
		response: json.RawMessage(`{"jobs":[
			{"id":"gsid-mine","source":"/x","cron":"0 * * * *","currentlyRunning":false,"paused":false},
			{"id":"gsid-other","source":"/y","cron":"0 0 * * *","currentlyRunning":false,"paused":true}
		]}`),
	}
	coord := fakeCoordWith(fc)

	got, err := listSchedulesForUser(context.Background(), app, coord, owner.Id)
	if err != nil {
		t.Fatalf("listSchedulesForUser: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("got %d schedules, want 1 (only the caller's own)", len(got))
	}
	if got[0].DisplayName != "Mine" || got[0].Cron != "0 * * * *" {
		t.Fatalf("got %+v, want merged Mine/0 * * * *", got[0])
	}
}

func TestBuildCreateScheduleParams(t *testing.T) {
	params := buildCreateScheduleParams("gsid-x", createScheduleRequest{
		DisplayName: "Nightly Sync",
		Cron:        "0 2 * * *",
		Prompt:      "do the thing",
	})
	if params.ID != "gsid-x" {
		t.Fatalf("ID = %q, want gsid-x", params.ID)
	}
	if params.Recipe.Title != "Nightly Sync" || params.Recipe.Description != "Nightly Sync" {
		t.Fatalf("Recipe = %+v, want title/description = Nightly Sync", params.Recipe)
	}
	if params.Recipe.Prompt == nil || *params.Recipe.Prompt != "do the thing" {
		t.Fatalf("Recipe.Prompt = %v, want \"do the thing\"", params.Recipe.Prompt)
	}
	if params.Cron != "0 2 * * *" {
		t.Fatalf("Cron = %q, want 0 2 * * *", params.Cron)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go build ./internal/api/... 2>&1 | head -30`
Expected: FAIL to compile — `undefined: resolveOwnedSchedule`, `undefined: listSchedulesForUser`, `undefined: buildCreateScheduleParams`, `undefined: createScheduleRequest` (none of `schedules.go`'s symbols exist yet).

- [ ] **Step 3: Write the implementation**

```go
// services/pocketbase/internal/api/schedules.go
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

// @pocketcoder-core: Scheduler API. Per-user CRUD over Goose's
// _goose/unstable/schedules/* — see
// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md. Unlike
// skills.go (household-global, admin-only), these routes are per-user:
// every caller manages only the schedules attributed to them in
// schedule_owners, resolved via resolveOwnedSchedule.
package api

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/security"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// recipeDto mirrors the subset of Goose's RecipeDto (acp-schema.json) this
// design ever sets — title/description (both required by Goose) and an
// optional prompt. Every other RecipeDto field (extensions, parameters,
// sub_recipes, etc.) is intentionally never populated — see this plan's
// Global Constraints.
type recipeDto struct {
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Prompt      *string `json:"prompt,omitempty"`
}

// scheduledJobDto mirrors Goose's ScheduledJobDto (acp-schema.json).
type scheduledJobDto struct {
	ID               string  `json:"id"`
	Source           string  `json:"source"`
	Cron             string  `json:"cron"`
	LastRun          *string `json:"lastRun"`
	CurrentlyRunning bool    `json:"currentlyRunning"`
	Paused           bool    `json:"paused"`
	CurrentSessionID *string `json:"currentSessionId"`
	JobStartTime     *string `json:"jobStartTime"`
}

type createScheduleParams struct {
	ID     string    `json:"id"`
	Recipe recipeDto `json:"recipe"`
	Cron   string    `json:"cron"`
}
type createScheduleResponse struct {
	Job scheduledJobDto `json:"job"`
}
type updateScheduleParams struct {
	ScheduleID string `json:"scheduleId"`
	Cron       string `json:"cron"`
}
type updateScheduleResponse struct {
	Job scheduledJobDto `json:"job"`
}

// scheduleIDParams mirrors every schedules/* request that takes only
// {"scheduleId": "..."} — pause, unpause, delete, run-now.
type scheduleIDParams struct {
	ScheduleID string `json:"scheduleId"`
}
type listSchedulesResponse struct {
	Jobs []scheduledJobDto `json:"jobs"`
}

// scheduleResp is what the Flutter Scheduler screen actually consumes —
// the schedule_owners row merged with its matching ScheduledJobDto.
type scheduleResp struct {
	ID               string  `json:"id"`
	DisplayName      string  `json:"displayName"`
	Cron             string  `json:"cron"`
	Paused           bool    `json:"paused"`
	CurrentlyRunning bool    `json:"currentlyRunning"`
	LastRun          *string `json:"lastRun"`
}

// createScheduleRequest is the HTTP body shape for POST
// /api/pocketcoder/schedules/create.
type createScheduleRequest struct {
	DisplayName string `json:"displayName"`
	Cron        string `json:"cron"`
	Prompt      string `json:"prompt"`
}

// buildCreateScheduleParams maps a validated createScheduleRequest plus a
// caller-generated goose_schedule_id onto createScheduleParams. Recipe
// title and description are both set to displayName — Goose requires both,
// this design only exposes one name field to the user.
func buildCreateScheduleParams(gooseScheduleID string, in createScheduleRequest) createScheduleParams {
	prompt := in.Prompt
	return createScheduleParams{
		ID: gooseScheduleID,
		Recipe: recipeDto{
			Title:       in.DisplayName,
			Description: in.DisplayName,
			Prompt:      &prompt,
		},
		Cron: in.Cron,
	}
}

// resolveOwnedSchedule looks up the schedule_owners row with the given
// PocketBase record id, scoped to userID. Returns a plain error (not an
// already-written HTTP response) for a foreign or nonexistent id — the
// caller decides how to translate that into a response (404, never 403,
// so a foreign id doesn't leak existence).
func resolveOwnedSchedule(app core.App, userID, id string) (*core.Record, error) {
	rec, err := app.FindRecordById("schedule_owners", id)
	if err != nil {
		return nil, fmt.Errorf("schedule not found: %w", err)
	}
	if rec.GetString("user") != userID {
		return nil, fmt.Errorf("schedule not found")
	}
	return rec, nil
}

// listSchedulesForUser is list's testable core: fetch the caller's own
// schedule_owners rows, call schedules/list once (Goose has no filter
// param — ListSchedulesRequest_unstable is an empty object, confirmed
// against acp-schema.json), and merge by goose_schedule_id. A
// schedule_owners row with no matching Goose job (deleted goose-side out
// of band) is silently skipped rather than failing the whole list.
func listSchedulesForUser(ctx context.Context, app core.App, coord func() *coordinator.Coordinator, userID string) ([]scheduleResp, error) {
	owners, err := app.FindRecordsByFilter("schedule_owners", "user = {:userId}", "", 0, 0, map[string]any{"userId": userID})
	if err != nil {
		return nil, fmt.Errorf("query schedule_owners: %w", err)
	}
	if len(owners) == 0 {
		return []scheduleResp{}, nil
	}

	c := coord()
	if c == nil {
		return nil, fmt.Errorf("agent profile not configured")
	}
	conn, err := c.AdminConn(ctx)
	if err != nil {
		return nil, fmt.Errorf("AdminConn: %w", err)
	}
	defer conn.Close()

	raw, err := conn.CallExtension(ctx, "_goose/unstable/schedules/list", struct{}{})
	if err != nil {
		return nil, fmt.Errorf("schedules/list: %w", err)
	}
	var resp listSchedulesResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		return nil, fmt.Errorf("parse schedules/list response: %w", err)
	}
	jobsByID := make(map[string]scheduledJobDto, len(resp.Jobs))
	for _, j := range resp.Jobs {
		jobsByID[j.ID] = j
	}

	out := make([]scheduleResp, 0, len(owners))
	for _, owner := range owners {
		job, ok := jobsByID[owner.GetString("goose_schedule_id")]
		if !ok {
			continue
		}
		out = append(out, scheduleResp{
			ID:               owner.Id,
			DisplayName:      owner.GetString("display_name"),
			Cron:             job.Cron,
			Paused:           job.Paused,
			CurrentlyRunning: job.CurrentlyRunning,
			LastRun:          job.LastRun,
		})
	}
	return out, nil
}

// RegisterSchedulesApi registers the per-user schedule CRUD endpoints.
// run-now is registered separately by Task 4, once hooks.ImportSession
// exists for it to call.
func RegisterSchedulesApi(app *pocketbase.PocketBase, e *core.ServeEvent, coord func() *coordinator.Coordinator) {
	e.Router.POST("/api/pocketcoder/schedules/list", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		schedules, err := listSchedulesForUser(re.Request.Context(), app, coord, re.Auth.Id)
		if err != nil {
			return re.JSON(502, map[string]string{"error": err.Error()})
		}
		return re.JSON(200, map[string]any{"schedules": schedules})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/create", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input createScheduleRequest
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.DisplayName == "" || input.Cron == "" || input.Prompt == "" {
			return re.JSON(400, map[string]string{"error": "displayName, cron, and prompt are required"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		var job scheduledJobDto
		var gooseScheduleID string
		const maxAttempts = 3
		for attempt := 0; ; attempt++ {
			gooseScheduleID = security.RandomString(20)
			raw, callErr := conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/create", buildCreateScheduleParams(gooseScheduleID, input))
			if callErr == nil {
				var resp createScheduleResponse
				if err := json.Unmarshal(raw, &resp); err != nil {
					return re.JSON(502, map[string]string{"error": "failed to parse goose response"})
				}
				job = resp.Job
				break
			}
			if strings.Contains(callErr.Error(), "already exists") && attempt < maxAttempts-1 {
				continue
			}
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose schedules/create failed: %v", callErr)})
		}

		ownersCol, err := app.FindCollectionByNameOrId("schedule_owners")
		if err != nil {
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}
		ownerRec := core.NewRecord(ownersCol)
		ownerRec.Set("user", re.Auth.Id)
		ownerRec.Set("goose_schedule_id", gooseScheduleID)
		ownerRec.Set("display_name", input.DisplayName)
		if err := app.Save(ownerRec); err != nil {
			// Best-effort rollback so a save failure doesn't leave an
			// orphaned Goose-side schedule with no owner.
			_, _ = conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/delete", scheduleIDParams{ScheduleID: gooseScheduleID})
			return re.JSON(500, map[string]string{"error": "Failed to save schedule ownership"})
		}

		return re.JSON(200, scheduleResp{
			ID: ownerRec.Id, DisplayName: input.DisplayName, Cron: job.Cron,
			Paused: job.Paused, CurrentlyRunning: job.CurrentlyRunning, LastRun: job.LastRun,
		})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/rename", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID          string `json:"id"`
			DisplayName string `json:"displayName"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" || input.DisplayName == "" {
			return re.JSON(400, map[string]string{"error": "id and displayName are required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}
		owner.Set("display_name", input.DisplayName)
		if err := app.Save(owner); err != nil {
			return re.JSON(500, map[string]string{"error": "Failed to rename schedule"})
		}
		return re.JSON(200, map[string]string{"id": owner.Id, "displayName": input.DisplayName})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/update-cron", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID   string `json:"id"`
			Cron string `json:"cron"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" || input.Cron == "" {
			return re.JSON(400, map[string]string{"error": "id and cron are required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		raw, callErr := conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/update", updateScheduleParams{
			ScheduleID: owner.GetString("goose_schedule_id"), Cron: input.Cron,
		})
		if callErr != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose schedules/update failed: %v", callErr)})
		}
		var resp updateScheduleResponse
		if err := json.Unmarshal(raw, &resp); err != nil {
			return re.JSON(502, map[string]string{"error": "failed to parse goose response"})
		}
		return re.JSON(200, scheduleResp{
			ID: owner.Id, DisplayName: owner.GetString("display_name"), Cron: resp.Job.Cron,
			Paused: resp.Job.Paused, CurrentlyRunning: resp.Job.CurrentlyRunning, LastRun: resp.Job.LastRun,
		})
	}).Bind(apis.RequireAuth())

	registerPauseToggleRoute(e, app, coord, "/api/pocketcoder/schedules/pause", "_goose/unstable/schedules/pause")
	registerPauseToggleRoute(e, app, coord, "/api/pocketcoder/schedules/unpause", "_goose/unstable/schedules/unpause")

	e.Router.POST("/api/pocketcoder/schedules/delete", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID string `json:"id"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" {
			return re.JSON(400, map[string]string{"error": "id is required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		if _, callErr := conn.CallExtension(re.Request.Context(), "_goose/unstable/schedules/delete", scheduleIDParams{ScheduleID: owner.GetString("goose_schedule_id")}); callErr != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose schedules/delete failed: %v", callErr)})
		}
		if err := app.Delete(owner); err != nil {
			return re.JSON(500, map[string]string{"error": "Failed to delete schedule ownership"})
		}
		return re.JSON(200, map[string]bool{"deleted": true})
	}).Bind(apis.RequireAuth())
}

// registerPauseToggleRoute registers a route sharing pause/unpause's exact
// shape — {"id": "..."} in, resolve ownership, call the given Goose method
// with {"scheduleId": "..."}.
func registerPauseToggleRoute(e *core.ServeEvent, app *pocketbase.PocketBase, coord func() *coordinator.Coordinator, path, gooseMethod string) {
	e.Router.POST(path, func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID string `json:"id"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" {
			return re.JSON(400, map[string]string{"error": "id is required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}

		conn, err := dialAdmin(re, coord)
		if err != nil {
			return err
		}
		defer conn.Close()

		if _, callErr := conn.CallExtension(re.Request.Context(), gooseMethod, scheduleIDParams{ScheduleID: owner.GetString("goose_schedule_id")}); callErr != nil {
			return re.JSON(502, map[string]string{"error": fmt.Sprintf("goose %s failed: %v", gooseMethod, callErr)})
		}
		return re.JSON(200, map[string]bool{"ok": true})
	}).Bind(apis.RequireAuth())
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd services/pocketbase && go test ./internal/api/... -run 'TestResolveOwnedSchedule|TestListSchedules_MergesOwnerRowsWithGooseState|TestBuildCreateScheduleParams' -v`
Expected: PASS (all four tests)

Then run the full package to confirm nothing else broke:

Run: `cd services/pocketbase && go build ./... && go test ./internal/api/... -v`
Expected: PASS, no compile errors (note: `schedules/run-now` is intentionally not registered yet — that's Task 4, not a bug here)

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/api/schedules.go services/pocketbase/internal/api/schedules_test.go
git commit -m "feat(scheduler): add schedule list/create/rename/update-cron/pause/unpause/delete routes"
```

---

### Task 3: Background importer (`schedule_importer.go`)

**Files:**
- Create: `services/pocketbase/internal/hooks/schedule_importer.go`
- Test: `services/pocketbase/internal/hooks/schedule_importer_test.go`

**Interfaces:**
- Consumes: `hooks.SendPushNotification(app core.App, userID, title, message, notifType, chatID string)` (`internal/hooks/notifications.go:175`, same package, no import needed). `goose_sessions` schema (`chat`, `user`, `goose_session_id` fields, unique index on `goose_session_id` — `1748000500_goose_sessions.go`). `chats` schema (`title`, `user` required — `1740000100_consolidated_schema.go`).
- Produces: `ImportSession(app core.App, owner *core.Record, sessionID string) error` — **exported**, since Task 4's `runScheduleNowAndImport` (in package `api`) calls it as `hooks.ImportSession(...)`. `RegisterScheduleImportHooks(app core.App, coord func() *coordinator.Coordinator)` — called once from `main.go` in Task 5, mirroring `hooks.RegisterCronHooks(app core.App)`'s existing signature shape.

- [ ] **Step 1: Write the failing test**

```go
// services/pocketbase/internal/hooks/schedule_importer_test.go
package hooks

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func newImporterTestUser(t *testing.T, app core.App, email string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(col)
	u.SetEmail(email)
	u.SetPassword("password123")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func newImporterScheduleOwner(t *testing.T, app core.App, userID, displayName string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(col)
	rec.Set("user", userID)
	rec.Set("goose_schedule_id", "gsid-"+displayName)
	rec.Set("display_name", displayName)
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

func TestImportSession_CreatesChatAndGooseSession(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	user := newImporterTestUser(t, app, "importer1@example.com")
	owner := newImporterScheduleOwner(t, app, user.Id, "Nightly Sync")

	if err := ImportSession(app, owner, "session-abc"); err != nil {
		t.Fatalf("ImportSession: %v", err)
	}

	session, err := app.FindFirstRecordByFilter("goose_sessions", "goose_session_id = {:sid}", map[string]any{"sid": "session-abc"})
	if err != nil {
		t.Fatalf("expected a goose_sessions row: %v", err)
	}
	chat, err := app.FindRecordById("chats", session.GetString("chat"))
	if err != nil {
		t.Fatalf("expected the linked chat to exist: %v", err)
	}
	if chat.GetString("user") != user.Id {
		t.Fatalf("chat.user = %q, want %q", chat.GetString("user"), user.Id)
	}
	if session.GetString("user") != user.Id {
		t.Fatalf("goose_sessions.user = %q, want %q", session.GetString("user"), user.Id)
	}
}

func TestImportSession_SkipsAlreadyImportedSession(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	user := newImporterTestUser(t, app, "importer2@example.com")
	owner := newImporterScheduleOwner(t, app, user.Id, "Nightly Sync")

	if err := ImportSession(app, owner, "session-dup"); err != nil {
		t.Fatalf("first ImportSession: %v", err)
	}
	if err := ImportSession(app, owner, "session-dup"); err != nil {
		t.Fatalf("second ImportSession (should be a no-op, not an error): %v", err)
	}

	chats, err := app.FindRecordsByFilter("chats", "user = {:uid}", "", 0, 0, map[string]any{"uid": user.Id})
	if err != nil {
		t.Fatal(err)
	}
	if len(chats) != 1 {
		t.Fatalf("got %d chats, want exactly 1 (second import must not create a duplicate)", len(chats))
	}
}

func TestImportFn_ImportsUnseenSessionsAcrossOwners(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	user := newImporterTestUser(t, app, "importer3@example.com")
	owner := newImporterScheduleOwner(t, app, user.Id, "Weekly Report")

	fc := &fakeImportAdminConn{
		byScheduleID: map[string]string{
			owner.GetString("goose_schedule_id"): `{"sessions":[{"sessionId":"session-xyz","cwd":"/tmp","title":null,"updatedAt":"2026-01-01T00:00:00Z"}]}`,
		},
	}
	coord := fakeImportCoordWith(fc)

	runImportPoll(app, coord)

	_, err = app.FindFirstRecordByFilter("goose_sessions", "goose_session_id = {:sid}", map[string]any{"sid": "session-xyz"})
	if err != nil {
		t.Fatalf("expected session-xyz to be imported: %v", err)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go build ./internal/hooks/... 2>&1 | head -30`
Expected: FAIL to compile — `undefined: ImportSession`, `undefined: runImportPoll`, `undefined: fakeImportAdminConn`, `undefined: fakeImportCoordWith` (none of `schedule_importer.go`'s symbols, nor this test file's own fakes, exist yet).

- [ ] **Step 3: Add the fake ACP connection this package needs**

`internal/hooks` has no existing `acp.Conn` test double (`skills_test.go`'s `fakeAdminConn` lives in package `api` — Go test doubles aren't shared across packages, this codebase's established convention). Add one, keyed by scheduleId so a single fake can answer each owner's `sessions/list` call differently:

```go
// services/pocketbase/internal/hooks/schedule_importer_fakes_test.go
package hooks

import (
	"context"
	"encoding/json"
	"fmt"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

type fakeImportAdminConn struct {
	byScheduleID map[string]string
}

func (f *fakeImportAdminConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{}, nil
}
func (f *fakeImportAdminConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{}, nil
}
func (f *fakeImportAdminConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (f *fakeImportAdminConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (f *fakeImportAdminConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (f *fakeImportAdminConn) CallExtension(_ context.Context, method string, params any) (json.RawMessage, error) {
	p, ok := params.(listScheduleSessionsParams)
	if !ok {
		return nil, fmt.Errorf("unexpected params type %T for method %s", params, method)
	}
	resp, ok := f.byScheduleID[p.ScheduleID]
	if !ok {
		return json.RawMessage(`{"sessions":[]}`), nil
	}
	return json.RawMessage(resp), nil
}
func (f *fakeImportAdminConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{}, nil
}
func (f *fakeImportAdminConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (f *fakeImportAdminConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (f *fakeImportAdminConn) Close() error { return nil }

var _ acp.Conn = (*fakeImportAdminConn)(nil)

func fakeImportCoordWith(fc *fakeImportAdminConn) func() *coordinator.Coordinator {
	coord, err := coordinator.New(coordinator.Config{
		GooseURL: "ws://unused", GooseSecret: "x", Workspace: "/tmp",
		Dial: func(ctx context.Context, client acpsdk.Client) (acp.Conn, error) {
			return fc, nil
		},
	})
	if err != nil {
		panic(err)
	}
	return func() *coordinator.Coordinator { return coord }
}
```

- [ ] **Step 4: Write the implementation**

```go
// services/pocketbase/internal/hooks/schedule_importer.go
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

// @pocketcoder-core: Schedule Importer. Turns fired Goose schedules into
// ordinary PocketCoder chats. See
// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md's Component 3.
// PocketBase has no messages table (services/pocketbase/pb_migrations/
// 1752000000_prune_legacy_runtime.go) — chat history is replayed live from
// Goose via session/load (coordinator/run.go's StreamColdReplay), so
// "importing" a session requires only a chats row + a goose_sessions row
// pointing at it. Opening that chat renders its content automatically.
package hooks

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/pocketbase/pocketbase/core"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// listScheduleSessionsParams mirrors Goose's
// ListScheduleSessionsRequest_unstable (acp-schema.json), required
// [scheduleId, limit].
type listScheduleSessionsParams struct {
	ScheduleID string `json:"scheduleId"`
	Limit      int    `json:"limit"`
}
type scheduleSessionEntry struct {
	SessionID string `json:"sessionId"`
}
type listScheduleSessionsResponse struct {
	Sessions []scheduleSessionEntry `json:"sessions"`
}

// ImportSession creates a chats row + goose_sessions row for a
// newly-observed Goose session produced by firing the schedule `owner`
// owns, then notifies the schedule's owner. Both runImportPoll (this
// file) and api.runScheduleNowAndImport (Task 4, the run-now fast path)
// call this same function — see the design spec's Component 3.
//
// Dedup relies on goose_sessions' unique index on goose_session_id
// (1748000500_goose_sessions.go) — the existence check plus both writes
// run inside one transaction so a losing race (the poller and a run-now
// fast path importing the same session concurrently) can never leave a
// dangling chat with no linked goose_sessions row.
func ImportSession(app core.App, owner *core.Record, sessionID string) error {
	var chatID, userID, displayName string
	imported := false

	err := app.RunInTransaction(func(txApp core.App) error {
		existing, _ := txApp.FindFirstRecordByFilter("goose_sessions", "goose_session_id = {:sid}", map[string]any{"sid": sessionID})
		if existing != nil {
			return nil // already imported — not an error, just nothing to do
		}

		chatsCol, err := txApp.FindCollectionByNameOrId("chats")
		if err != nil {
			return fmt.Errorf("find chats collection: %w", err)
		}
		userID = owner.GetString("user")
		displayName = owner.GetString("display_name")

		chat := core.NewRecord(chatsCol)
		chat.Set("title", fmt.Sprintf("%s — %s", displayName, time.Now().Format("Jan 2 15:04")))
		chat.Set("user", userID)
		if err := txApp.Save(chat); err != nil {
			return fmt.Errorf("create chat: %w", err)
		}
		chatID = chat.Id

		sessionsCol, err := txApp.FindCollectionByNameOrId("goose_sessions")
		if err != nil {
			return fmt.Errorf("find goose_sessions collection: %w", err)
		}
		session := core.NewRecord(sessionsCol)
		session.Set("chat", chatID)
		session.Set("user", userID)
		session.Set("goose_session_id", sessionID)
		if err := txApp.Save(session); err != nil {
			return fmt.Errorf("create goose_sessions row: %w", err)
		}

		imported = true
		return nil
	})
	if err != nil {
		return err
	}
	if imported {
		SendPushNotification(app, userID, displayName, "Scheduled task finished", "schedule", chatID)
	}
	return nil
}

// runImportPoll is the poller's testable core: for every schedule_owners
// row (across all users — this is a background job, not a per-request
// handler), dial one AdminConn for the whole pass, call
// schedules/sessions/list per row, and import every unseen session.
// Errors on one row are logged and skipped — one broken schedule must not
// block importing the rest.
func runImportPoll(app core.App, coord func() *coordinator.Coordinator) {
	owners, err := app.FindRecordsByFilter("schedule_owners", "1=1", "", 0, 0)
	if err != nil {
		log.Printf("⚠️ [Scheduler] import poll: failed to list schedule_owners: %v", err)
		return
	}
	if len(owners) == 0 {
		return
	}
	c := coord()
	if c == nil {
		return
	}
	ctx := context.Background()
	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [Scheduler] import poll: AdminConn failed: %v", err)
		return
	}
	defer conn.Close()

	for _, owner := range owners {
		gooseScheduleID := owner.GetString("goose_schedule_id")
		raw, err := conn.CallExtension(ctx, "_goose/unstable/schedules/sessions/list", listScheduleSessionsParams{ScheduleID: gooseScheduleID, Limit: 20})
		if err != nil {
			log.Printf("⚠️ [Scheduler] import poll: sessions/list failed for %s: %v", gooseScheduleID, err)
			continue
		}
		var resp listScheduleSessionsResponse
		if err := json.Unmarshal(raw, &resp); err != nil {
			log.Printf("⚠️ [Scheduler] import poll: failed to parse sessions/list response for %s: %v", gooseScheduleID, err)
			continue
		}
		for _, s := range resp.Sessions {
			if err := ImportSession(app, owner, s.SessionID); err != nil {
				log.Printf("⚠️ [Scheduler] import poll: failed to import session %s: %v", s.SessionID, err)
			}
		}
	}
}

// RegisterScheduleImportHooks registers the every-60s background poll
// that turns fired schedules' Goose sessions into ordinary PocketCoder
// chats. Reuses app.Cron() — already live, functional infrastructure
// (confirmed independent of the dead hooks/cron.go this plan retires in
// Task 6) — no new polling mechanism needed.
func RegisterScheduleImportHooks(app core.App, coord func() *coordinator.Coordinator) {
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if err := app.Cron().Add("schedule-import", "* * * * *", func() { runImportPoll(app, coord) }); err != nil {
			log.Printf("⚠️ [Scheduler] failed to register import poll: %v", err)
		}
		return e.Next()
	})
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd services/pocketbase && go test ./internal/hooks/... -run 'TestImportSession|TestImportFn' -v`
Expected: PASS (all three tests)

Then confirm the whole build is clean:

Run: `cd services/pocketbase && go build ./...`
Expected: no errors

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/hooks/schedule_importer.go services/pocketbase/internal/hooks/schedule_importer_test.go services/pocketbase/internal/hooks/schedule_importer_fakes_test.go
git commit -m "feat(scheduler): add background importer for fired schedule sessions"
```

---

### Task 4: `run-now` route

**Files:**
- Modify: `services/pocketbase/internal/api/schedules.go`
- Modify: `services/pocketbase/internal/api/schedules_test.go`

**Interfaces:**
- Consumes: `hooks.ImportSession(app core.App, owner *core.Record, sessionID string) error` (Task 3, package `hooks` → package `api`, no import cycle — confirmed neither package currently imports the other). `resolveOwnedSchedule`, `scheduleIDParams`, `dialAdmin` (all from Task 2, same file/package).
- Produces: `POST /api/pocketcoder/schedules/run-now`, and `runScheduleNowAndImport` (unexported, the goroutine body — this task's own testable core).

**`schedules/run-now` is synchronous in Goose** — it blocks until the recipe run finishes (verified against `.independent_repos/goose_reference/crates/goose/src/scheduler.rs:645-697`, which `await`s `execute_job` to completion before returning). The route must not hold the HTTP request open for that duration, so it launches the call on its own goroutine with its own context and returns `202` immediately; the goroutine imports the resulting session itself once Goose's response is in hand, rather than waiting for the next 60s poll.

- [ ] **Step 1: Write the failing test**

Append to `services/pocketbase/internal/api/schedules_test.go`:

```go
func TestRunScheduleNowAndImport_ImportsReturnedSession(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	owner := newTestUser(t, app, "runnow@example.com")
	rec := newScheduleOwner(t, app, owner.Id, "gsid-runnow", "Ad-hoc Run")

	fc := &fakeAdminConn{
		response: json.RawMessage(`{"status":"completed","sessionId":"session-runnow"}`),
	}
	coord := fakeCoordWith(fc)

	runScheduleNowAndImport(app, coord, rec.Id, "gsid-runnow")

	if fc.lastMethod != "_goose/unstable/schedules/run-now" {
		t.Fatalf("lastMethod = %q, want schedules/run-now", fc.lastMethod)
	}
	if _, err := app.FindFirstRecordByFilter("goose_sessions", "goose_session_id = {:sid}", map[string]any{"sid": "session-runnow"}); err != nil {
		t.Fatalf("expected session-runnow to be imported: %v", err)
	}
}

func TestRunScheduleNowAndImport_NoSessionIdIsNotAnError(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	owner := newTestUser(t, app, "runnow2@example.com")
	rec := newScheduleOwner(t, app, owner.Id, "gsid-runnow2", "Ad-hoc Run 2")

	fc := &fakeAdminConn{
		response: json.RawMessage(`{"status":"cancelled","sessionId":null}`),
	}
	coord := fakeCoordWith(fc)

	// Must not panic on a nil sessionId — just log and return.
	runScheduleNowAndImport(app, coord, rec.Id, "gsid-runnow2")
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go build ./internal/api/... 2>&1 | head -20`
Expected: FAIL to compile — `undefined: runScheduleNowAndImport`

- [ ] **Step 3: Write the implementation**

Add to `services/pocketbase/internal/api/schedules.go` (import `"log"` and the `hooks` package alongside the existing imports; add the `run-now` route registration inside `RegisterSchedulesApi`, after the `delete` route; add `runScheduleNowResponse` alongside the other response structs; add `runScheduleNowAndImport` as a new top-level function):

```go
// Add to the import block:
import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/security"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
)

// runScheduleNowResponse mirrors Goose's RunScheduleNowResponse_unstable.
type runScheduleNowResponse struct {
	Status    string  `json:"status"`
	SessionID *string `json:"sessionId"`
}
```

Add the route (inside `RegisterSchedulesApi`, after the `delete` route registration, before the closing `}` of the function):

```go
	e.Router.POST("/api/pocketcoder/schedules/run-now", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var input struct {
			ID string `json:"id"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ID == "" {
			return re.JSON(400, map[string]string{"error": "id is required"})
		}
		owner, err := resolveOwnedSchedule(app, re.Auth.Id, input.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}

		ownerID := owner.Id
		gooseScheduleID := owner.GetString("goose_schedule_id")
		go runScheduleNowAndImport(app, coord, ownerID, gooseScheduleID)

		return re.JSON(202, map[string]string{"status": "started"})
	}).Bind(apis.RequireAuth())
```

Add the goroutine body as a new top-level function in the same file:

```go
// runScheduleNowAndImport is run-now's background half. It runs on its
// own goroutine with its own context — independent of the HTTP request,
// which has already returned — because schedules/run-now blocks in Goose
// until the recipe finishes (scheduler.rs:645-697). On success it imports
// the resulting session immediately via hooks.ImportSession, using the
// sessionId Goose's response already contains, instead of waiting up to
// 60s for runImportPoll's next pass to notice it.
func runScheduleNowAndImport(app core.App, coord func() *coordinator.Coordinator, ownerRecordID, gooseScheduleID string) {
	c := coord()
	if c == nil {
		log.Printf("⚠️ [Scheduler] run-now: no coordinator configured")
		return
	}
	ctx := context.Background()
	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [Scheduler] run-now: AdminConn failed: %v", err)
		return
	}
	defer conn.Close()

	raw, err := conn.CallExtension(ctx, "_goose/unstable/schedules/run-now", scheduleIDParams{ScheduleID: gooseScheduleID})
	if err != nil {
		log.Printf("⚠️ [Scheduler] run-now failed for %s: %v", gooseScheduleID, err)
		return
	}
	var resp runScheduleNowResponse
	if err := json.Unmarshal(raw, &resp); err != nil {
		log.Printf("⚠️ [Scheduler] run-now: failed to parse response for %s: %v", gooseScheduleID, err)
		return
	}
	if resp.SessionID == nil || *resp.SessionID == "" {
		log.Printf("⚠️ [Scheduler] run-now for %s completed with no sessionId (status=%s)", gooseScheduleID, resp.Status)
		return
	}

	owner, err := app.FindRecordById("schedule_owners", ownerRecordID)
	if err != nil {
		log.Printf("⚠️ [Scheduler] run-now: owner record %s vanished before import: %v", ownerRecordID, err)
		return
	}
	if err := hooks.ImportSession(app, owner, *resp.SessionID); err != nil {
		log.Printf("⚠️ [Scheduler] run-now: failed to import session %s: %v", *resp.SessionID, err)
	}
}
```

Note: `core` is `*pocketbase.PocketBase` at the call site inside `RegisterSchedulesApi` but `runScheduleNowAndImport` takes `app core.App` — `*pocketbase.PocketBase` satisfies `core.App`, so passing `app` straight through type-checks with no wrapping needed (same pattern `dialAdmin`/`listSchedulesForUser` already use).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd services/pocketbase && go test ./internal/api/... -run 'TestRunScheduleNowAndImport' -v`
Expected: PASS (both tests)

Then the full build + test suite:

Run: `cd services/pocketbase && go build ./... && go test ./...`
Expected: PASS, no compile errors, no import cycle

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/api/schedules.go services/pocketbase/internal/api/schedules_test.go
git commit -m "feat(scheduler): add async run-now route"
```

---

### Task 5: Wire the Scheduler API + importer into `main.go`

**Files:**
- Modify: `services/pocketbase/main.go`

**Interfaces:**
- Consumes: `api.RegisterSchedulesApi(app *pocketbase.PocketBase, e *core.ServeEvent, coord func() *coordinator.Coordinator)` (Task 2/4), `hooks.RegisterScheduleImportHooks(app core.App, coord func() *coordinator.Coordinator)` (Task 3).

This is a pure wiring change with nothing meaningfully unit-testable in isolation — same shape as `api.RegisterSkillsApi`'s own `main.go` wiring. The test here is a clean build plus the existing full-suite run.

- [ ] **Step 1: Add the two registration calls**

In `services/pocketbase/main.go`, add `hooks.RegisterScheduleImportHooks(app, coordGetter)` next to the existing `hooks.RegisterCronHooks(app)` line (`main.go:71`), and `api.RegisterSchedulesApi(app, e, coordGetter)` next to the existing `api.RegisterSkillsApi(app, e, coordGetter)` line (`main.go:99`), both inside the existing structure:

```go
	// 3c. Register Cron Hooks (scheduled agent tasks)
	hooks.RegisterCronHooks(app)

	// 3d. Register Schedule Import Hooks (Goose-native scheduler → chat feed)
	hooks.RegisterScheduleImportHooks(app, coordGetter)
```

```go
		// D. Skills API (pure ACP passthrough, no PocketBase storage).
		api.RegisterSkillsApi(app, e, coordGetter)

		// E. Scheduler API (per-user CRUD over Goose's schedules, backed by
		// schedule_owners).
		api.RegisterSchedulesApi(app, e, coordGetter)
```

(`hooks.RegisterCronHooks(app)` and `api.RegisterCronApi(app, e)` are left in place here — removing them is Task 6, kept separate so this task's diff is purely additive and easy to review on its own.)

- [ ] **Step 2: Verify the build**

Run: `cd services/pocketbase && go build ./...`
Expected: no errors

Run: `cd services/pocketbase && go test ./...`
Expected: PASS across every package

- [ ] **Step 3: Commit**

```bash
git add services/pocketbase/main.go
git commit -m "feat(scheduler): wire scheduler API and import hooks into main.go"
```

---

### Task 6: Retirement — delete the dead `cron_jobs` feature

**Files:**
- Delete: `services/pocketbase/internal/api/cron.go`
- Delete: `services/pocketbase/internal/hooks/cron.go`
- Modify: `services/pocketbase/main.go`
- Create: `services/pocketbase/pb_migrations/1755000100_remove_dead_cron_jobs.go`
- Test: `services/pocketbase/pb_migrations/1755000100_remove_dead_cron_jobs_test.go`
- Delete: `client/packages/pocketcoder_flutter/lib/domain/models/cron_job.dart` (+ generated `.freezed.dart`/`.g.dart`)

**Interfaces:** none — this task only removes dead code and its schema. Confirmed safe by re-checking, at plan-writing time: `grep -rln "CronJob\b" client/packages/pocketcoder_flutter/lib --include="*.dart"` returns only `cron_job.dart` itself (zero external references), and a full migration-file grep shows no collection other than `cron_jobs` holds any relation field pointing at it.

`cron_jobs` is defined across three historical migration files (`1740000100_consolidated_schema.go` creates it, `1748000100_acp_schema.go` adds its `poco_config` field, `1753000000_prune_legacy_ai_config.go` drops its `agent` field). Unlike `skills` (self-contained in one file, flattened directly — see `a7bc76c999` for that precedent), this plan follows `1753000000_prune_legacy_ai_config.go`'s own precedent instead: a clean new deletion migration, leaving the three historical files untouched. Editing three past migrations to reverse-engineer "what if `cron_jobs` never existed" is far riskier than one small new migration, for an entangled collection.

- [ ] **Step 1: Write the failing test**

```go
// services/pocketbase/pb_migrations/1755000100_remove_dead_cron_jobs_test.go
package pb_migrations_test

import (
	"testing"

	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func TestCronJobsCollectionIsGone(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	if _, err := app.FindCollectionByNameOrId("cron_jobs"); err == nil {
		t.Fatal("expected cron_jobs collection to be deleted")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./pb_migrations/... -run TestCronJobsCollectionIsGone -v`
Expected: FAIL — `cron_jobs` collection still exists

- [ ] **Step 3: Write the deletion migration**

```go
// services/pocketbase/pb_migrations/1755000100_remove_dead_cron_jobs.go
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
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// Drops the "cron_jobs" collection (pc_cron_jobs). It is dead code, not
// merely unused: its firing handler (the now-deleted
// internal/hooks/cron.go) wrote to chats.agent and referenced a
// "messages" collection, both deleted by earlier migrations
// (1753000000_prune_legacy_ai_config.go, 1752000000_prune_legacy_runtime.go)
// — it errored at runtime on every fire. Replaced by
// schedule_owners + the Scheduler UI's live passthrough to Goose's own
// scheduler. See
// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md's Retirement
// section. Zero surviving relation fields point at this collection
// (confirmed by grep across all migrations at plan-writing time), so —
// like 1754000000's now-superseded skills-collection removal, but unlike
// ai_agents in 1753000000_prune_legacy_ai_config.go — no relation needs
// dropping first.
func init() {
	migrations.Register(func(app core.App) error {
		col, err := app.FindCollectionByNameOrId("cron_jobs")
		if err != nil {
			return err
		}
		return app.Delete(col)
	}, func(app core.App) error {
		// Down migration intentionally does not recreate the collection —
		// matches 1753000000_prune_legacy_ai_config.go's precedent of a
		// no-op down migration for a deliberately-dead-code removal.
		return nil
	})
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./pb_migrations/... -run TestCronJobsCollectionIsGone -v`
Expected: PASS

- [ ] **Step 5: Delete the dead Go files and their `main.go` wiring**

```bash
git rm services/pocketbase/internal/api/cron.go
git rm services/pocketbase/internal/hooks/cron.go
```

In `services/pocketbase/main.go`, remove the now-dangling lines:

```go
	// 3c. Register Cron Hooks (scheduled agent tasks)
	hooks.RegisterCronHooks(app)
```

(delete this block entirely — the comment and the call), and:

```go
		api.RegisterCronApi(app, e)
```

(delete this one line from inside the `OnServe` block).

- [ ] **Step 6: Verify the build**

Run: `cd services/pocketbase && go build ./...`
Expected: no errors — confirms nothing else referenced `api.RegisterCronApi`/`hooks.RegisterCronHooks`/`resolveHumanUser` (the latter was private to `cron.go` and dies with it)

Run: `cd services/pocketbase && go test ./...`
Expected: PASS across every package

- [ ] **Step 7: Delete the orphaned Flutter model**

Re-confirm zero references first (this plan's own check may be stale by the time this step runs):

Run: `cd client/packages/pocketcoder_flutter && grep -rln "CronJob\b" lib --include="*.dart"`
Expected: only `lib/domain/models/cron_job.dart` itself

```bash
git rm client/packages/pocketcoder_flutter/lib/domain/models/cron_job.dart
git rm client/packages/pocketcoder_flutter/lib/domain/models/cron_job.freezed.dart
git rm client/packages/pocketcoder_flutter/lib/domain/models/cron_job.g.dart
```

- [ ] **Step 8: Rerun the Model Generation Pipeline**

Per root `CLAUDE.md`:

```bash
docker compose build pocketbase opencode
docker compose up -d pocketbase opencode
scripts/export_schema.sh
cd client/packages/pocketcoder_flutter && python3 scripts/generate_models.py
dart run build_runner build --delete-conflicting-outputs
```

Confirm `lib/domain/models/collections.dart` no longer defines `cronJobs` (currently `collections.dart:15,39` — `static const String cronJobs = 'cron_jobs';` and its entry in the `all` list) and now defines `scheduleOwners` (Task 1's collection) instead — `generate_collections()` does a full rewrite of this file from the live PB schema on every run, so this is automatic, not a manual edit.

Run: `cd client/packages/pocketcoder_flutter && flutter analyze`
Expected: no errors

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore(scheduler): retire the dead cron_jobs feature"
```

---

### Task 7: Flutter `Schedule` model + `ISchedulerRepository`/`SchedulerRepository`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/domain/models/schedule.dart`
- Create: `client/packages/pocketcoder_flutter/lib/domain/scheduler/i_scheduler_repository.dart`
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/scheduler/scheduler_repository.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/scheduler/scheduler_repository_test.dart`

**Interfaces:**
- Consumes: `PocketBase.send<T>(path, {method, body})` (`pocketbase` package, `client.dart:252` — already used identically by `SkillsRepository`). `tryMethod` (`core/try_operation.dart`, same wrapper `SkillsRepository` uses).
- Produces: `Schedule` (`fromJson` only — `{id, displayName, cron, paused, currentlyRunning, lastRun}`), `SchedulerException`, `ISchedulerRepository` with `listSchedules()`, `createSchedule({displayName, cron, prompt})`, `renameSchedule({id, displayName})`, `updateCron({id, cron})`, `pauseSchedule(id)`, `unpauseSchedule(id)`, `deleteSchedule(id)`, `runNow(id)` — Task 8's `SchedulerCubit` calls every one of these by exact name.

- [ ] **Step 1: Write the failing test**

```dart
// client/packages/pocketcoder_flutter/test/infrastructure/scheduler/scheduler_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/scheduler/scheduler_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

void main() {
  late SchedulerRepository repo;
  late MockPocketBase pb;

  setUp(() {
    pb = MockPocketBase();
    repo = SchedulerRepository(pb);
  });

  group('SchedulerRepository.listSchedules', () {
    test('posts to schedules/list and maps the response', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/list',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'schedules': [
              {
                'id': 'rec1',
                'displayName': 'Nightly Sync',
                'cron': '0 2 * * *',
                'paused': false,
                'currentlyRunning': false,
                'lastRun': null,
              }
            ]
          });

      final result = await repo.listSchedules();

      expect(result, hasLength(1));
      expect(result.first.displayName, 'Nightly Sync');
      expect(result.first.paused, isFalse);
      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/list',
            method: 'POST',
            body: {},
          )).called(1);
    });

    test('wraps failures in SchedulerException', () async {
      when(() => pb.send<dynamic>(
            any(),
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenThrow(Exception('boom'));

      await expectLater(() => repo.listSchedules(), throwsA(isA<SchedulerException>()));
    });
  });

  group('SchedulerRepository.createSchedule', () {
    test('posts displayName/cron/prompt', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/create',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'id': 'rec1',
            'displayName': 'Nightly Sync',
            'cron': '0 2 * * *',
            'paused': false,
            'currentlyRunning': false,
            'lastRun': null,
          });

      await repo.createSchedule(displayName: 'Nightly Sync', cron: '0 2 * * *', prompt: 'do the thing');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/create',
            method: 'POST',
            body: {
              'displayName': 'Nightly Sync',
              'cron': '0 2 * * *',
              'prompt': 'do the thing',
            },
          )).called(1);
    });
  });

  group('SchedulerRepository.renameSchedule', () {
    test('posts id/displayName', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/rename',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'id': 'rec1', 'displayName': 'Renamed'});

      await repo.renameSchedule(id: 'rec1', displayName: 'Renamed');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/rename',
            method: 'POST',
            body: {'id': 'rec1', 'displayName': 'Renamed'},
          )).called(1);
    });
  });

  group('SchedulerRepository.updateCron', () {
    test('posts id/cron', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/update-cron',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {
            'id': 'rec1',
            'displayName': 'Nightly Sync',
            'cron': '0 3 * * *',
            'paused': false,
            'currentlyRunning': false,
            'lastRun': null,
          });

      await repo.updateCron(id: 'rec1', cron: '0 3 * * *');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/update-cron',
            method: 'POST',
            body: {'id': 'rec1', 'cron': '0 3 * * *'},
          )).called(1);
    });
  });

  group('SchedulerRepository.pauseSchedule', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/pause',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'ok': true});

      await repo.pauseSchedule('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/pause',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });
  });

  group('SchedulerRepository.unpauseSchedule', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/unpause',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'ok': true});

      await repo.unpauseSchedule('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/unpause',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });
  });

  group('SchedulerRepository.deleteSchedule', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/delete',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'deleted': true});

      await repo.deleteSchedule('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/delete',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });

    test('wraps failures in SchedulerException', () async {
      when(() => pb.send<dynamic>(
            any(),
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenThrow(Exception('boom'));

      await expectLater(() => repo.deleteSchedule('rec1'), throwsA(isA<SchedulerException>()));
    });
  });

  group('SchedulerRepository.runNow', () {
    test('posts id', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/run-now',
            method: any(named: 'method'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => {'status': 'started'});

      await repo.runNow('rec1');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/schedules/run-now',
            method: 'POST',
            body: {'id': 'rec1'},
          )).called(1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/scheduler/scheduler_repository_test.dart 2>&1 | head -30`
Expected: FAIL to compile — `Target of URI doesn't exist: 'package:pocketcoder_flutter/infrastructure/scheduler/scheduler_repository.dart'` (nothing in this task exists yet)

- [ ] **Step 3: Add `SchedulerException`**

Append to `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`:

```dart
/// Scheduler-related exceptions.
class SchedulerException extends DomainException {
  SchedulerException(super.message, [super.cause]);
}
```

- [ ] **Step 4: Add the `Schedule` model**

```dart
// client/packages/pocketcoder_flutter/lib/domain/models/schedule.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'schedule.freezed.dart';
part 'schedule.g.dart';

/// A Goose scheduled recipe run, merged with its PocketBase ownership row
/// (schedule_owners). Unlike other domain models in this app, this is NOT
/// directly PocketBase-backed the usual way: `id` is schedule_owners'
/// PocketBase record id, but `cron`/`paused`/`currentlyRunning`/`lastRun`
/// come live from Goose on every request — there is no `fromRecord`. Every
/// instance is built from JSON returned by the scheduler API routes
/// (services/pocketbase/internal/api/schedules.go). See
/// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md.
@freezed
abstract class Schedule with _$Schedule {
  const factory Schedule({
    required String id,
    required String displayName,
    required String cron,
    required bool paused,
    required bool currentlyRunning,
    String? lastRun,
  }) = _Schedule;

  factory Schedule.fromJson(Map<String, dynamic> json) =>
      _$ScheduleFromJson(json);
}
```

- [ ] **Step 5: Add `ApiEndpoints` constants**

In `client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart`, add a new section after the existing `SKILLS ENDPOINTS` block:

```dart
  // ===========================================================================
  // SCHEDULER ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/schedules/list
  /// Lists the caller's own scheduled recipe runs.
  static const String schedulesList = '/api/pocketcoder/schedules/list';

  /// POST /api/pocketcoder/schedules/create
  /// Creates a new scheduled recipe run.
  static const String schedulesCreate = '/api/pocketcoder/schedules/create';

  /// POST /api/pocketcoder/schedules/rename
  /// Renames a schedule (PocketBase-side display name only).
  static const String schedulesRename = '/api/pocketcoder/schedules/rename';

  /// POST /api/pocketcoder/schedules/update-cron
  /// Updates a schedule's cron expression.
  static const String schedulesUpdateCron =
      '/api/pocketcoder/schedules/update-cron';

  /// POST /api/pocketcoder/schedules/pause
  static const String schedulesPause = '/api/pocketcoder/schedules/pause';

  /// POST /api/pocketcoder/schedules/unpause
  static const String schedulesUnpause = '/api/pocketcoder/schedules/unpause';

  /// POST /api/pocketcoder/schedules/delete
  static const String schedulesDelete = '/api/pocketcoder/schedules/delete';

  /// POST /api/pocketcoder/schedules/run-now
  /// Fires a schedule immediately (async — the resulting session is
  /// imported into the chat feed once it finishes, not returned here).
  static const String schedulesRunNow = '/api/pocketcoder/schedules/run-now';
```

And extend the `all` list in the same file:

```dart
  static const List<String> all = [
    permission,
    sshKeys,
    health,
    observability,
    skillsList,
    skillsCreate,
    skillsUpdate,
    skillsDelete,
    schedulesList,
    schedulesCreate,
    schedulesRename,
    schedulesUpdateCron,
    schedulesPause,
    schedulesUnpause,
    schedulesDelete,
    schedulesRunNow,
  ];
```

- [ ] **Step 6: Add `ISchedulerRepository` and `SchedulerRepository`**

```dart
// client/packages/pocketcoder_flutter/lib/domain/scheduler/i_scheduler_repository.dart
import 'package:pocketcoder_flutter/domain/models/schedule.dart';

abstract class ISchedulerRepository {
  Future<List<Schedule>> listSchedules();
  Future<Schedule> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  });
  Future<void> renameSchedule({required String id, required String displayName});
  Future<Schedule> updateCron({required String id, required String cron});
  Future<void> pauseSchedule(String id);
  Future<void> unpauseSchedule(String id);
  Future<void> deleteSchedule(String id);
  Future<void> runNow(String id);
}
```

```dart
// client/packages/pocketcoder_flutter/lib/infrastructure/scheduler/scheduler_repository.dart
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';
import 'package:pocketcoder_flutter/domain/models/schedule.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

@LazySingleton(as: ISchedulerRepository)
class SchedulerRepository implements ISchedulerRepository {
  final PocketBase _pb;

  SchedulerRepository(this._pb);

  @override
  Future<List<Schedule>> listSchedules() async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.schedulesList,
          method: 'POST',
          body: {},
        );
        final schedules = (response as Map<String, dynamic>)['schedules'] as List;
        return schedules
            .map((s) => Schedule.fromJson(s as Map<String, dynamic>))
            .toList();
      },
      SchedulerException.new,
      'listSchedules',
    );
  }

  @override
  Future<Schedule> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  }) async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.schedulesCreate,
          method: 'POST',
          body: {'displayName': displayName, 'cron': cron, 'prompt': prompt},
        );
        return Schedule.fromJson(response as Map<String, dynamic>);
      },
      SchedulerException.new,
      'createSchedule',
    );
  }

  @override
  Future<void> renameSchedule({required String id, required String displayName}) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesRename,
          method: 'POST',
          body: {'id': id, 'displayName': displayName},
        );
      },
      SchedulerException.new,
      'renameSchedule',
    );
  }

  @override
  Future<Schedule> updateCron({required String id, required String cron}) async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.schedulesUpdateCron,
          method: 'POST',
          body: {'id': id, 'cron': cron},
        );
        return Schedule.fromJson(response as Map<String, dynamic>);
      },
      SchedulerException.new,
      'updateCron',
    );
  }

  @override
  Future<void> pauseSchedule(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesPause,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'pauseSchedule',
    );
  }

  @override
  Future<void> unpauseSchedule(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesUnpause,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'unpauseSchedule',
    );
  }

  @override
  Future<void> deleteSchedule(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesDelete,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'deleteSchedule',
    );
  }

  @override
  Future<void> runNow(String id) async {
    return tryMethod(
      () async {
        await _pb.send<dynamic>(
          ApiEndpoints.schedulesRunNow,
          method: 'POST',
          body: {'id': id},
        );
      },
      SchedulerException.new,
      'runNow',
    );
  }
}
```

- [ ] **Step 7: Generate freezed/json_serializable code**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: generates `schedule.freezed.dart`/`schedule.g.dart`, no errors

- [ ] **Step 8: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/scheduler/scheduler_repository_test.dart`
Expected: PASS (all 9 tests)

- [ ] **Step 9: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/models/schedule.dart \
        client/packages/pocketcoder_flutter/lib/domain/models/schedule.freezed.dart \
        client/packages/pocketcoder_flutter/lib/domain/models/schedule.g.dart \
        client/packages/pocketcoder_flutter/lib/domain/scheduler/i_scheduler_repository.dart \
        client/packages/pocketcoder_flutter/lib/infrastructure/scheduler/scheduler_repository.dart \
        client/packages/pocketcoder_flutter/lib/domain/exceptions.dart \
        client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart \
        client/packages/pocketcoder_flutter/test/infrastructure/scheduler/scheduler_repository_test.dart
git commit -m "feat(scheduler): add Schedule model, SchedulerException, SchedulerRepository"
```

---

### Task 8: `SchedulerState`/`SchedulerCubit`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/application/scheduler/scheduler_state.dart`
- Create: `client/packages/pocketcoder_flutter/lib/application/scheduler/scheduler_cubit.dart`
- Test: `client/packages/pocketcoder_flutter/test/application/scheduler/scheduler_cubit_test.dart`

**Interfaces:**
- Consumes: `ISchedulerRepository` (Task 7) — every method by exact name. `IUiFlowState`/`UiFlowStatus` (`cubit_ui_flow` package, same contract `SkillsState` implements).
- Produces: `SchedulerState` (4-variant Freezed: `initial`/`loading`/`loaded(List<Schedule>)`/`error(String)`), `SchedulerCubit` with `loadSchedules()`, `createSchedule(...)`, `renameSchedule(...)`, `updateCron(...)`, `pauseSchedule(id)`, `unpauseSchedule(id)`, `deleteSchedule(id)`, `runNow(id)` — Task 9's `SchedulerScreen` calls every one of these by exact name.

- [ ] **Step 1: Write the failing test**

```dart
// client/packages/pocketcoder_flutter/test/application/scheduler/scheduler_cubit_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_cubit.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/domain/models/schedule.dart';
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';

class MockSchedulerRepository extends Mock implements ISchedulerRepository {}

const _schedule = Schedule(
  id: 'rec1',
  displayName: 'Nightly Sync',
  cron: '0 2 * * *',
  paused: false,
  currentlyRunning: false,
);

void main() {
  late MockSchedulerRepository repo;
  SchedulerCubit? lastCubit;

  SchedulerCubit buildCubit() {
    final cubit = SchedulerCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockSchedulerRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('SchedulerCubit.loadSchedules', () {
    test('emits loading then loaded on success', () async {
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      final states = <SchedulerState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.loadSchedules();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states, [
        const SchedulerState.loading(),
        const SchedulerState.loaded([_schedule]),
      ]);
    });

    test('emits error on repository failure', () async {
      when(() => repo.listSchedules()).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.loadSchedules();

      expect(cubit.state.hasError, isTrue);
    });
  });

  group('SchedulerCubit.createSchedule', () {
    test('calls repository.createSchedule then reloads', () async {
      when(() => repo.createSchedule(
            displayName: any(named: 'displayName'),
            cron: any(named: 'cron'),
            prompt: any(named: 'prompt'),
          )).thenAnswer((_) async => _schedule);
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.createSchedule(displayName: 'Nightly Sync', cron: '0 2 * * *', prompt: 'do the thing');

      verify(() => repo.createSchedule(
            displayName: 'Nightly Sync',
            cron: '0 2 * * *',
            prompt: 'do the thing',
          )).called(1);
      verify(() => repo.listSchedules()).called(1);
    });

    test('emits error on repository failure without reloading', () async {
      when(() => repo.createSchedule(
            displayName: any(named: 'displayName'),
            cron: any(named: 'cron'),
            prompt: any(named: 'prompt'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createSchedule(displayName: 'x', cron: 'y', prompt: 'z');

      expect(cubit.state.hasError, isTrue);
      verifyNever(() => repo.listSchedules());
    });
  });

  group('SchedulerCubit.renameSchedule', () {
    test('calls repository.renameSchedule then reloads', () async {
      when(() => repo.renameSchedule(
            id: any(named: 'id'),
            displayName: any(named: 'displayName'),
          )).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.renameSchedule(id: 'rec1', displayName: 'Renamed');

      verify(() => repo.renameSchedule(id: 'rec1', displayName: 'Renamed')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.updateCron', () {
    test('calls repository.updateCron then reloads', () async {
      when(() => repo.updateCron(id: any(named: 'id'), cron: any(named: 'cron')))
          .thenAnswer((_) async => _schedule);
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.updateCron(id: 'rec1', cron: '0 3 * * *');

      verify(() => repo.updateCron(id: 'rec1', cron: '0 3 * * *')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.pauseSchedule', () {
    test('calls repository.pauseSchedule then reloads', () async {
      when(() => repo.pauseSchedule(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.pauseSchedule('rec1');

      verify(() => repo.pauseSchedule('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.unpauseSchedule', () {
    test('calls repository.unpauseSchedule then reloads', () async {
      when(() => repo.unpauseSchedule(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.unpauseSchedule('rec1');

      verify(() => repo.unpauseSchedule('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });

  group('SchedulerCubit.deleteSchedule', () {
    test('calls repository.deleteSchedule then reloads', () async {
      when(() => repo.deleteSchedule(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => []);

      final cubit = buildCubit();
      await cubit.deleteSchedule('rec1');

      verify(() => repo.deleteSchedule('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });

    test('emits error on repository failure without reloading', () async {
      when(() => repo.deleteSchedule(any())).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.deleteSchedule('rec1');

      expect(cubit.state.hasError, isTrue);
      verifyNever(() => repo.listSchedules());
    });
  });

  group('SchedulerCubit.runNow', () {
    test('calls repository.runNow then reloads', () async {
      when(() => repo.runNow(any())).thenAnswer((_) async {});
      when(() => repo.listSchedules()).thenAnswer((_) async => [_schedule]);

      final cubit = buildCubit();
      await cubit.runNow('rec1');

      verify(() => repo.runNow('rec1')).called(1);
      verify(() => repo.listSchedules()).called(1);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/scheduler/scheduler_cubit_test.dart 2>&1 | head -30`
Expected: FAIL to compile — nothing in `application/scheduler/` exists yet

- [ ] **Step 3: Write `SchedulerState`**

```dart
// client/packages/pocketcoder_flutter/lib/application/scheduler/scheduler_state.dart
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/schedule.dart';

part 'scheduler_state.freezed.dart';

@freezed
sealed class SchedulerState with _$SchedulerState implements IUiFlowState {
  const SchedulerState._();

  const factory SchedulerState.initial() = _Initial;
  const factory SchedulerState.loading() = _Loading;
  const factory SchedulerState.loaded(List<Schedule> schedules) = _Loaded;
  const factory SchedulerState.error(String message) = _Error;

  @override
  UiFlowStatus get status => when(
        initial: () => UiFlowStatus.idle,
        loading: () => UiFlowStatus.loading,
        loaded: (_) => UiFlowStatus.success,
        error: (_) => UiFlowStatus.failure,
      );

  @override
  Object? get error => maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
```

- [ ] **Step 4: Write `SchedulerCubit`**

```dart
// client/packages/pocketcoder_flutter/lib/application/scheduler/scheduler_cubit.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'package:pocketcoder_flutter/domain/scheduler/i_scheduler_repository.dart';

import 'scheduler_state.dart';

@injectable
class SchedulerCubit extends Cubit<SchedulerState> {
  final ISchedulerRepository _repository;

  SchedulerCubit(this._repository) : super(const SchedulerState.initial());

  Future<void> loadSchedules() async {
    emit(const SchedulerState.loading());
    try {
      final schedules = await _repository.listSchedules();
      emit(SchedulerState.loaded(schedules));
    } catch (e) {
      logError('Scheduler: Failed to load schedules', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> createSchedule({
    required String displayName,
    required String cron,
    required String prompt,
  }) async {
    try {
      await _repository.createSchedule(displayName: displayName, cron: cron, prompt: prompt);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to create schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> renameSchedule({required String id, required String displayName}) async {
    try {
      await _repository.renameSchedule(id: id, displayName: displayName);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to rename schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> updateCron({required String id, required String cron}) async {
    try {
      await _repository.updateCron(id: id, cron: cron);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to update schedule cron', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> pauseSchedule(String id) async {
    try {
      await _repository.pauseSchedule(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to pause schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> unpauseSchedule(String id) async {
    try {
      await _repository.unpauseSchedule(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to unpause schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> deleteSchedule(String id) async {
    try {
      await _repository.deleteSchedule(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to delete schedule', e);
      emit(SchedulerState.error(e.toString()));
    }
  }

  Future<void> runNow(String id) async {
    try {
      await _repository.runNow(id);
      await loadSchedules();
    } catch (e) {
      logError('Scheduler: Failed to run schedule now', e);
      emit(SchedulerState.error(e.toString()));
    }
  }
}
```

- [ ] **Step 5: Generate freezed code**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: generates `scheduler_state.freezed.dart`, no errors

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/scheduler/scheduler_cubit_test.dart`
Expected: PASS (all 12 tests)

- [ ] **Step 7: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/application/scheduler client/packages/pocketcoder_flutter/test/application/scheduler
git commit -m "feat(scheduler): add SchedulerState/SchedulerCubit"
```

---

### Task 9: l10n keys + `SchedulerScreen`

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`
- Create: `client/packages/pocketcoder_flutter/lib/presentation/scheduler/scheduler_screen.dart`

**Interfaces:**
- Consumes: `SchedulerCubit`/`SchedulerState` (Task 8), `Schedule` (Task 7), `PocketCoderShell`/`BiosFrame`/`BiosSection`/`TerminalButton`/`TerminalDialog`/`TerminalCard`/`TerminalTextField`/`TerminalText`/`UiFlowListener` (`presentation/core/widgets/*`, same widgets `SkillsScreen` uses — read directly for exact constructor signatures before use), `getIt<SchedulerCubit>()` (`app/bootstrap.dart`).
- Produces: `SchedulerScreen` — Task 10 registers a route pointing at it.

No project-scope picker is needed here (unlike `SkillsScreen`) — schedules are per-user with no directory-scoping concept, so this screen is a single flat list.

- [ ] **Step 1: Add ARB keys**

Checked for collisions first: `grep -n "\"scheduler" client/packages/pocketcoder_flutter/lib/l10n/app_en.arb` returns nothing at plan-writing time — no existing keys to collide with. Add after the existing `skillsNoEligibleConfig` entry in `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`:

```json
  "schedulerTitle": "SCHEDULER",
  "schedulerRegistryTitle": "SCHEDULED TASKS",
  "schedulerNoSchedules": "NO SCHEDULES CONFIGURED",
  "schedulerAddButton": "ADD SCHEDULE",
  "schedulerEditButton": "EDIT",
  "schedulerDeleteButton": "DELETE",
  "schedulerSaveButton": "SAVE",
  "schedulerPauseButton": "PAUSE",
  "schedulerResumeButton": "RESUME",
  "schedulerRunNowButton": "RUN NOW",
  "schedulerNameLabel": "NAME",
  "schedulerCronLabel": "CRON EXPRESSION",
  "schedulerPromptLabel": "PROMPT",
  "schedulerAddDialogTitle": "ADD SCHEDULE",
  "schedulerEditDialogTitle": "EDIT: {name}",
  "@schedulerEditDialogTitle": {
    "placeholders": {
      "name": {"type": "String"}
    }
  },
  "schedulerPausedBadge": "PAUSED",
  "schedulerRunningBadge": "RUNNING",
```

Run: `cd client/packages/pocketcoder_flutter && flutter gen-l10n`
Expected: regenerates `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_en.dart` with the new getters, no errors (matches the precedent in `2f061b2a9`, Tool-Permissions UI's own ARB-key commit, which committed the regenerated files alongside the ARB edit)

- [ ] **Step 2: Write `SchedulerScreen`**

```dart
// client/packages/pocketcoder_flutter/lib/presentation/scheduler/scheduler_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_cubit.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/domain/models/schedule.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class SchedulerScreen extends StatelessWidget {
  const SchedulerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<SchedulerCubit>()..loadSchedules(),
      child: UiFlowListener<SchedulerCubit, SchedulerState>(
        child: const _SchedulerView(),
      ),
    );
  }
}

class _SchedulerView extends StatelessWidget {
  const _SchedulerView();

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.schedulerTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.schedulerRegistryTitle,
        child: BlocBuilder<SchedulerCubit, SchedulerState>(
          builder: (context, state) {
            final colors = context.colorScheme;
            return state.maybeWhen(
              loaded: (schedules) => ListView(
                children: [
                  Padding(
                    padding: EdgeInsets.all(AppSizes.space),
                    child: TerminalButton(
                      label: context.l10n.schedulerAddButton,
                      onTap: () => _showAddScheduleDialog(context),
                    ),
                  ),
                  for (final schedule in schedules) _buildScheduleItem(context, schedule),
                  if (schedules.isEmpty)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSizes.space * 4),
                        child: TerminalText(
                          context.l10n.schedulerNoSchedules,
                          alpha: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (msg) => Center(
                child: Text('ERROR: $msg', style: TextStyle(color: colors.error)),
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildScheduleItem(BuildContext context, Schedule schedule) {
    final cubit = context.read<SchedulerCubit>();
    return TerminalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TerminalText(
                  schedule.displayName.toUpperCase(),
                  weight: TerminalTextWeight.heavy,
                ),
              ),
              if (schedule.currentlyRunning)
                TerminalText.mini(context.l10n.schedulerRunningBadge, alpha: 0.8)
              else if (schedule.paused)
                TerminalText.mini(context.l10n.schedulerPausedBadge, alpha: 0.5),
            ],
          ),
          VSpace.x1,
          TerminalText.mini(schedule.cron, alpha: 0.6),
          VSpace.x1,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: schedule.paused
                      ? context.l10n.schedulerResumeButton
                      : context.l10n.schedulerPauseButton,
                  isPrimary: false,
                  onTap: () => schedule.paused
                      ? cubit.unpauseSchedule(schedule.id)
                      : cubit.pauseSchedule(schedule.id),
                ),
              ),
              HSpace.x2,
              Expanded(
                child: TerminalButton(
                  label: context.l10n.schedulerRunNowButton,
                  isPrimary: false,
                  onTap: () => cubit.runNow(schedule.id),
                ),
              ),
            ],
          ),
          VSpace.x1,
          Row(
            children: [
              Expanded(
                child: TerminalButton(
                  label: context.l10n.schedulerEditButton,
                  isPrimary: false,
                  onTap: () => _showEditScheduleDialog(context, schedule),
                ),
              ),
              HSpace.x2,
              TerminalButton(
                label: context.l10n.schedulerDeleteButton,
                color: context.colorScheme.error,
                onTap: () => cubit.deleteSchedule(schedule.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, Schedule schedule) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<SchedulerCubit>();
    final nameController = TextEditingController(text: schedule.displayName);
    final cronController = TextEditingController(text: schedule.cron);

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.schedulerEditDialogTitle(schedule.displayName.toUpperCase()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
              controller: nameController,
              label: context.l10n.schedulerNameLabel,
              obscureText: false,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: cronController,
              label: context.l10n.schedulerCronLabel,
              obscureText: false,
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionCancel),
          ),
          HSpace.x2,
          OutlinedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final cron = cronController.text.trim();
              if (name.isEmpty || cron.isEmpty) {
                return;
              }
              if (name != schedule.displayName) {
                cubit.renameSchedule(id: schedule.id, displayName: name);
              }
              if (cron != schedule.cron) {
                cubit.updateCron(id: schedule.id, cron: cron);
              }
              Navigator.of(dialogContext).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.schedulerSaveButton),
          ),
        ],
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<SchedulerCubit>();
    final nameController = TextEditingController();
    final cronController = TextEditingController();
    final promptController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.schedulerAddDialogTitle,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TerminalTextField(
              controller: nameController,
              label: context.l10n.schedulerNameLabel,
              obscureText: false,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: cronController,
              label: context.l10n.schedulerCronLabel,
              obscureText: false,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: promptController,
              label: context.l10n.schedulerPromptLabel,
              obscureText: false,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.onSurface,
              side: BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionCancel),
          ),
          HSpace.x2,
          OutlinedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final cron = cronController.text.trim();
              final prompt = promptController.text.trim();
              if (name.isEmpty || cron.isEmpty || prompt.isEmpty) {
                return;
              }
              cubit.createSchedule(displayName: name, cron: cron, prompt: prompt);
              Navigator.of(dialogContext).pop();
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.primary,
              side: BorderSide(color: colors.primary),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(context.l10n.actionAdd),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify it compiles and analyzes clean**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/presentation/scheduler/scheduler_screen.dart lib/l10n/`
Expected: no errors (this screen has no dedicated widget test in this plan, matching `SkillsScreen`'s own precedent — coverage comes from the cubit/repository unit tests plus Task 10's manual verification pass)

- [ ] **Step 4: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/l10n/app_en.arb \
        client/packages/pocketcoder_flutter/lib/l10n/app_localizations.dart \
        client/packages/pocketcoder_flutter/lib/l10n/app_localizations_en.dart \
        client/packages/pocketcoder_flutter/lib/presentation/scheduler/scheduler_screen.dart
git commit -m "feat(scheduler): add localized SchedulerScreen"
```

---

### Task 10: Route registration, Settings entry, full verification

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/app_router.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`

**Interfaces:** none new — this task only wires together everything Tasks 1–9 built.

Re-read `app_router.dart` and `settings_screen.dart` at implementation time before editing — the exact surrounding lines cited below are current as of this plan's writing (confirmed via `git log`, `configureSkills`'s route landed in `fcf08a30a`), but should not be assumed to still match line-for-line if other work has landed on this branch since.

- [ ] **Step 1: Add the route**

In `client/packages/pocketcoder_flutter/lib/app_router.dart`, add a new `GoRoute` after the `configureSkills` block (around line 153, right after its closing `),`):

```dart
      GoRoute(
        path: AppRoutes.configureScheduler,
        name: RouteNames.configureScheduler,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SchedulerScreen(),
        ),
      ),
```

Add the import near the other presentation imports:

```dart
import 'package:pocketcoder_flutter/presentation/scheduler/scheduler_screen.dart';
```

Add to the `AppRoutes` class, next to `configureSkills` (line 238):

```dart
  static const String configureScheduler = '/configure/scheduler';
```

Add to the `RouteNames` class, next to `configureSkills` (line 279):

```dart
  static const String configureScheduler = 'configureScheduler';
```

- [ ] **Step 2: Add the Settings entry**

Add an ARB key for a new section title. In `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`, add near the other `settings*Section` keys:

```json
  "settingsAutomationSection": "AUTOMATION",
```

Run: `cd client/packages/pocketcoder_flutter && flutter gen-l10n`

In `client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart`, add a new section to `_sections()` (after the `settingsSecuritySection` block that already lists TOOL PERMISSIONS/MCP MANAGEMENT/SKILLS):

```dart
      (context.l10n.settingsAutomationSection, [
        ('SCHEDULER', '[MANAGE]', 'configureScheduler'),
      ]),
```

Add the matching case to `_navigateTo`:

```dart
      case 'configureScheduler':
        context.push(AppRoutes.configureScheduler);
```

- [ ] **Step 3: Full build + test verification**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: PASS, no errors, no vet warnings

Run: `cd client/packages/pocketcoder_flutter && flutter analyze`
Expected: no errors

Run: `cd client/packages/pocketcoder_flutter && flutter test`
Expected: PASS across the whole suite (this run also re-covers Tasks 7–8's own test files)

- [ ] **Step 4: Manual verification checklist**

Deploy per root `CLAUDE.md`'s VPS-first workflow (fix on VPS, test, then commit locally and pull on VPS — this repo's established deploy flow), then walk through:

1. Navigate to Settings → AUTOMATION → SCHEDULER. Empty state shows "NO SCHEDULES CONFIGURED".
2. ADD SCHEDULE with a name, a cron expression firing within the next minute (e.g. `* * * * *` for "every minute"), and a simple prompt (e.g. "say hello"). Confirm it appears in the list with the correct cron and an unpaused state.
3. Wait for it to fire (up to ~60s for `runImportPoll`'s next tick), then check the normal chat list — a new chat titled `"<name> — <timestamp>"` should appear, owned by the current user, with the prompt's actual output visible when opened. **This is the exact integration this plan exists to build** — a scheduled Goose-native run reaching the chat feed with zero bespoke message-persistence code, purely by reusing the existing cold-replay mechanism.
4. Tap RUN NOW on a schedule. Confirm the button doesn't hang the UI (the route returns `202` immediately) and a second chat appears shortly after — faster than the ~60s poll, since the run-now fast path imports the session directly off Goose's synchronous response.
5. PAUSE a schedule, confirm its badge changes and it no longer fires; RESUME it, confirm it fires again.
6. EDIT a schedule's name and cron expression together; confirm both persist (the name change via `schedule_owners`, the cron change via a live `schedules/update` call — no restart needed).
7. DELETE a schedule; confirm it disappears from the list and any chats it previously produced remain intact (deleting a schedule must never touch already-imported chat history).
8. Log in as a second user; confirm the first user's schedules are invisible to them (per-user `schedule_owners` scoping, not household-global like Skills/Tool-Permissions/MCP).

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/app_router.dart \
        client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart \
        client/packages/pocketcoder_flutter/lib/l10n/app_en.arb \
        client/packages/pocketcoder_flutter/lib/l10n/app_localizations.dart \
        client/packages/pocketcoder_flutter/lib/l10n/app_localizations_en.dart
git commit -m "feat(scheduler): register SchedulerScreen route, add Settings entry"
```
