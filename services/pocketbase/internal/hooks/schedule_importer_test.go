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
