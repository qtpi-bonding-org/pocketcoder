package api

import (
	"net/http"
	"testing"

	"github.com/pocketbase/pocketbase/core"
)

func TestRunScheduleNowHTTP(t *testing.T) {
	app := testApp(t)
	owner := testUser(t, app, "schedule-http-"+randomSuffix()+"@example.com")
	token, err := owner.NewAuthToken()
	if err != nil {
		t.Fatal(err)
	}

	// A literal empty {scheduleId} path segment ("//run") never reaches the
	// handler: the router 301-redirects the doubled slash before matching,
	// so the id == "" branch in runScheduleNow is unreachable via routing
	// and isn't exercised here.
	coll, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatal(err)
	}
	s := core.NewRecord(coll)
	s.Set("user", owner.Id)
	s.Set("display_name", "HTTP schedule")
	s.Set("prompt", "hello")
	s.Set("cron", "* * * * *")
	if err := app.Save(s); err != nil {
		t.Fatal(err)
	}
	if got := mountedRequest(t, app, http.MethodPost, "/api/pocketcoder/v1/schedules/"+s.Id+"/run", "", token); got != http.StatusAccepted {
		t.Fatalf("owner status = %d, want 202", got)
	}
}
