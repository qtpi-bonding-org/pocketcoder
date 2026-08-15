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

package schedule

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	acp "github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/acp"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

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
	r := &Runner{App: app, Coord: func() coordinator.AgentRuntime { return c }, Now: func() time.Time { return when }}
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
	r := &Runner{App: app, Coord: func() coordinator.AgentRuntime { return nil }, Now: func() time.Time { return when }}
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
		r := &Runner{App: app, Coord: func() coordinator.AgentRuntime { return nil }}
		if err := r.Run(context.Background(), "missing-owner"); err == nil {
			t.Fatal("expected error")
		}
	})
	t.Run("nil coordinator", func(t *testing.T) {
		s := newSchedule(t, app, user.Id, "Unavailable", false)
		r := &Runner{App: app, Coord: func() coordinator.AgentRuntime { return nil }}
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
func (*scheduleFakeConn) ResumeSession(context.Context, acpsdk.ResumeSessionRequest) (acpsdk.ResumeSessionResponse, error) {
	return acpsdk.ResumeSessionResponse{}, nil
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
func (*scheduleFakeConn) Done() <-chan struct{} { return nil }
func (*scheduleFakeConn) Close() error          { return nil }

var _ acp.Conn = (*scheduleFakeConn)(nil)

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

func testApp(t *testing.T) core.App {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	ensureTestPoco(t, app)
	return app
}

func ensureTestPoco(t *testing.T, app core.App) *core.Record {
	t.Helper()
	if poco, err := app.FindFirstRecordByFilter("agent_profiles", "name = 'Poco' && is_system = true", nil); err == nil {
		poco.Set("is_default", true)
		if err := app.Save(poco); err != nil {
			t.Fatal(err)
		}
		if !poco.GetBool("is_default") {
			t.Fatal("test Poco is_default was not persisted")
		}
		return poco
	}
	collection, err := app.FindCollectionByNameOrId("agent_profiles")
	if err != nil {
		t.Fatal(err)
	}
	poco := core.NewRecord(collection)
	poco.Set("name", "Poco")
	poco.Set("is_system", true)
	poco.Set("is_default", true)
	if err := app.Save(poco); err != nil {
		t.Fatal(err)
	}
	if !poco.GetBool("is_default") {
		t.Fatal("test Poco is_default was not persisted")
	}
	return poco
}

func testUser(t *testing.T, app core.App, email string) *core.Record {
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

func randomSuffix() string {
	return fmt.Sprintf("%d", rand.Int63())
}

func seedTestHarnessAndInstance(t *testing.T, app core.App, harnessName string, supportsLive bool, userID string) (*core.Record, *core.Record) {
	t.Helper()
	harnessesColl, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}

	// Use a unique ID suffix to allow multiple calls with the same name
	uniqueSuffix := randomSuffix()
	cliID := harnessName + "-" + uniqueSuffix

	harness := core.NewRecord(harnessesColl)
	harness.Set("name", harnessName)
	harness.Set("cli_id", cliID)
	harness.Set("acp_transport", "websocket")
	harness.Set("supports_live_config", supportsLive)
	harness.Set("supports_additional_directories", true)
	if err := app.Save(harness); err != nil {
		t.Fatal(err)
	}

	instancesColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	instance := core.NewRecord(instancesColl)
	instance.Set("harness", harness.Id)
	instance.Set("launch_key", "")
	instance.Set("container_name", "pocketcoder-"+harnessName+"-"+uniqueSuffix)
	instance.Set("acp_endpoint", "")
	instance.Set("secret", "")
	instance.Set("status", "running")
	instance.Set("managed", false)
	if userID != "" {
		instance.Set("user", userID)
		account, err := harnessaccount.EnsureDefaultPersonal(app, userID, harness.Id)
		if err != nil {
			t.Fatal(err)
		}
		instance.Set("harness_account", account.Id)
	}
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}

	return harness, instance
}
