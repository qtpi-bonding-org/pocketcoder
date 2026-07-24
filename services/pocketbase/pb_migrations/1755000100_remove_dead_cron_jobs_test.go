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
