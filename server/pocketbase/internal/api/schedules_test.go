package api

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
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

func newSchedule(t *testing.T, app core.App, user, name string, paused bool) *core.Record {
	t.Helper()
	c, err := app.FindCollectionByNameOrId("schedule_owners")
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(c)
	r.Set("user", user)
	r.Set("display_name", name)
	r.Set("prompt", "say hello")
	r.Set("cron", "* * * * *")
	r.Set("paused", paused)
	if err := app.Save(r); err != nil {
		t.Fatal(err)
	}
	return r
}

func scheduleCoordinator(t *testing.T, dial coordinator.DialFunc) *coordinator.Coordinator {
	t.Helper()
	c, err := coordinator.New(coordinator.Config{Workspace: "/workspace", Dial: dial})
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func TestScheduleRunnerRunSuccessAndClock(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "schedule-run-"+randomSuffix()+"@example.com")
	seedTestHarnessAndInstance(t, app, "goose", true, user.Id)
	s := newSchedule(t, app, user.Id, "Morning check", false)
	when := time.Date(2026, time.July, 24, 8, 9, 10, 0, time.FixedZone("X", 3600))
	c := scheduleCoordinator(t, func(_ context.Context, _ acpsdk.Client, _ coordinator.Target) (acp.Conn, error) {
		return &scheduleFakeConn{}, nil
	})
	r := &ScheduleRunner{App: app, Coord: func() *coordinator.Coordinator { return c }, Now: func() time.Time { return when }}
	if err := r.Run(context.Background(), s.Id); err != nil {
		t.Fatal(err)
	}
	chat, err := app.FindFirstRecordByFilter("chats", "user = {:u}", map[string]any{"u": user.Id})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(chat.GetString("title"), "Morning check") {
		t.Fatalf("title = %q", chat.GetString("title"))
	}
	if chat.GetString("user") != user.Id {
		t.Fatalf("chat user = %q", chat.GetString("user"))
	}
	got, err := app.FindRecordById("schedule_owners", s.Id)
	if err != nil {
		t.Fatal(err)
	}
	want := when.UTC().Format(time.RFC3339)
	if got.GetString("last_run") != want {
		t.Fatalf("last_run = %q, want %q", got.GetString("last_run"), want)
	}
}

func TestScheduleRunnerRunPausedIsNoOp(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "schedule-paused-"+randomSuffix()+"@example.com")
	s := newSchedule(t, app, user.Id, "Paused", true)
	when := time.Date(2026, 1, 2, 3, 4, 5, 0, time.UTC)
	r := &ScheduleRunner{App: app, Coord: func() *coordinator.Coordinator { return nil }, Now: func() time.Time { return when }}
	if err := r.Run(context.Background(), s.Id); err != nil {
		t.Fatal(err)
	}
	if _, err := app.FindFirstRecordByFilter("chats", "user = {:u}", map[string]any{"u": user.Id}); err == nil {
		t.Fatal("paused run created chat")
	}
	got, _ := app.FindRecordById("schedule_owners", s.Id)
	if got.GetString("last_run") != "" {
		t.Fatalf("last_run touched: %q", got.GetString("last_run"))
	}
}

func TestScheduleRunnerRunErrorsDoNotUpdateLastRun(t *testing.T) {
	app := testApp(t)
	user := testUser(t, app, "schedule-errors-"+randomSuffix()+"@example.com")
	seedTestHarnessAndInstance(t, app, "goose", true, user.Id)
	t.Run("missing owner", func(t *testing.T) {
		r := &ScheduleRunner{App: app, Coord: func() *coordinator.Coordinator { return nil }}
		if err := r.Run(context.Background(), "missing-owner"); err == nil {
			t.Fatal("expected error")
		}
	})
	t.Run("nil coordinator", func(t *testing.T) {
		s := newSchedule(t, app, user.Id, "Unavailable", false)
		r := &ScheduleRunner{App: app, Coord: func() *coordinator.Coordinator { return nil }}
		if err := r.Run(context.Background(), s.Id); err == nil {
			t.Fatal("expected error")
		}
		got, _ := app.FindRecordById("schedule_owners", s.Id)
		if got.GetString("last_run") != "" {
			t.Fatal("last_run updated")
		}
	})
	// Not tested here: a dial/connection failure. coordinator.StartPrompt is
	// fire-and-forget -- it reserves the chat and launches c.runLoop in its
	// own goroutine, returning (runID, nil) before any dial happens. A dial
	// failure surfaces later as an async RUN_ERROR event, never as a
	// synchronous error from StartPrompt (this is StartPrompt's existing
	// contract, unchanged by this refactor: the pre-refactor
	// runPocketCoderSchedule had the same fire-and-forget behavior and set
	// last_run right after a successful StartPrompt call regardless of how
	// the run later turned out).
}

// scheduleFakeConn is a transport-only ACP peer: it completes initialization,
// creates a session, and immediately finishes the prompt.
type scheduleFakeConn struct{}

func (*scheduleFakeConn) Initialize(context.Context, acpsdk.InitializeRequest) (acpsdk.InitializeResponse, error) {
	return acpsdk.InitializeResponse{AgentCapabilities: acpsdk.AgentCapabilities{LoadSession: true}}, nil
}
func (*scheduleFakeConn) NewSession(context.Context, acpsdk.NewSessionRequest) (acpsdk.NewSessionResponse, error) {
	return acpsdk.NewSessionResponse{SessionId: "schedule-session"}, nil
}
func (*scheduleFakeConn) LoadSession(context.Context, acpsdk.LoadSessionRequest) (acpsdk.LoadSessionResponse, error) {
	return acpsdk.LoadSessionResponse{}, nil
}
func (*scheduleFakeConn) SetSessionMode(context.Context, acpsdk.SetSessionModeRequest) (acpsdk.SetSessionModeResponse, error) {
	return acpsdk.SetSessionModeResponse{}, nil
}
func (*scheduleFakeConn) SetSessionConfigOption(context.Context, acpsdk.SetSessionConfigOptionRequest) (acpsdk.SetSessionConfigOptionResponse, error) {
	return acpsdk.SetSessionConfigOptionResponse{}, nil
}
func (*scheduleFakeConn) Prompt(context.Context, acpsdk.PromptRequest) (acpsdk.PromptResponse, error) {
	return acpsdk.PromptResponse{StopReason: acpsdk.StopReasonEndTurn}, nil
}
func (*scheduleFakeConn) Cancel(context.Context, acpsdk.CancelNotification) error { return nil }
func (*scheduleFakeConn) UnstableDeleteSession(context.Context, acpsdk.UnstableDeleteSessionRequest) (acpsdk.UnstableDeleteSessionResponse, error) {
	return acpsdk.UnstableDeleteSessionResponse{}, nil
}
func (*scheduleFakeConn) CallExtension(context.Context, string, any) (json.RawMessage, error) {
	return json.RawMessage(`{}`), nil
}
func (*scheduleFakeConn) Close() error { return nil }

var _ acp.Conn = (*scheduleFakeConn)(nil)
