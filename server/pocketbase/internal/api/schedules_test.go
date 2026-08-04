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
	if _, err := app.FindFirstRecordByFilter("agent_sessions", "acp_session_id = {:sid}", map[string]any{"sid": "session-runnow"}); err != nil {
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
