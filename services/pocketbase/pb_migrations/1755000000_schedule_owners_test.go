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
