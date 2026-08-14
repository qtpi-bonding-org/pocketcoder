package api

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/cron"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/sessionprofile"
)

func AddScheduleOperations(app core.App, registry *operation.Registry, coord func() AgentRuntime) {
	ollamaBaseURL := ollama.ResolveBaseURL()
	runner := &ScheduleRunner{App: app, Coord: coord, OllamaBaseURL: ollamaBaseURL}
	registry.Add(operation.Route{OperationID: "runScheduleNow", Method: http.MethodPost, Path: "/api/pocketcoder/v1/schedules/{scheduleId}/run", Auth: true, Action: func(re *core.RequestEvent) error {
		id := re.Request.PathValue("scheduleId")
		if id == "" {
			return pocketCoderError(re, 400, "scheduleId is required")
		}
		row, err := requireOwnedRecord(app, re, "schedule_owners", id)
		if err != nil {
			return err
		}
		go runner.runDetached(row.Id)
		return re.JSON(202, map[string]string{"status": "started"})
	}})

	app.OnRecordCreateRequest("schedule_owners").BindFunc(func(ev *core.RecordRequestEvent) error {
		if ev.Auth == nil || ev.Auth.Id == "" {
			return fmt.Errorf("authentication required")
		}
		ev.Record.Set("user", ev.Auth.Id)
		ev.Record.Set("last_run", "")
		return ev.Next()
	})
	app.OnRecordUpdateRequest("schedule_owners").BindFunc(func(ev *core.RecordRequestEvent) error {
		if ev.Auth == nil || ev.Auth.Id == "" || ev.Record.Original() == nil || ev.Record.Original().GetString("user") != ev.Auth.Id {
			return fmt.Errorf("schedule must belong to the authenticated user")
		}
		ev.Record.Set("user", ev.Record.Original().Get("user"))
		ev.Record.Set("last_run", ev.Record.Original().Get("last_run"))
		return ev.Next()
	})
	validate := func(ev *core.RecordEvent) error {
		ev.Record.Set("display_name", strings.TrimSpace(ev.Record.GetString("display_name")))
		ev.Record.Set("prompt", strings.TrimSpace(ev.Record.GetString("prompt")))
		ev.Record.Set("cron", strings.TrimSpace(ev.Record.GetString("cron")))
		if ev.Record.GetString("user") == "" || ev.Record.GetString("display_name") == "" || ev.Record.GetString("prompt") == "" {
			return fmt.Errorf("user, display_name, and prompt are required")
		}
		if _, err := cron.NewSchedule(ev.Record.GetString("cron")); err != nil {
			return fmt.Errorf("invalid cron expression: %w", err)
		}
		return ev.Next()
	}
	app.OnRecordCreate("schedule_owners").BindFunc(validate)
	app.OnRecordUpdate("schedule_owners").BindFunc(validate)

	hook := func(ev *core.RecordEvent) error {
		registerPocketCoderSchedule(runner, ev.Record)
		return ev.Next()
	}
	app.OnRecordAfterCreateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterUpdateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterDeleteSuccess("schedule_owners").BindFunc(func(ev *core.RecordEvent) error { app.Cron().Remove(scheduleJobID(ev.Record.Id)); return ev.Next() })
	rows, err := app.FindRecordsByFilter("schedule_owners", "1=1", "", 0, 0)
	if err != nil {
		log.Printf("[Scheduler] failed to load schedules at startup: %v", err)
		return
	}
	for _, row := range rows {
		registerPocketCoderSchedule(runner, row)
	}
}

func scheduleJobID(id string) string { return "pocketcoder-schedule-" + id }

type ScheduleRunner struct {
	App           core.App
	Coord         func() AgentRuntime
	OllamaBaseURL string
	Now           func() time.Time
}

func (r *ScheduleRunner) now() time.Time {
	if r.Now != nil {
		return r.Now()
	}
	return time.Now()
}

func registerPocketCoderSchedule(runner *ScheduleRunner, row *core.Record) {
	runner.App.Cron().Remove(scheduleJobID(row.Id))
	if row.GetBool("paused") || row.GetString("cron") == "" {
		return
	}
	if err := runner.App.Cron().Add(scheduleJobID(row.Id), row.GetString("cron"), func() {
		go runner.runDetached(row.Id)
	}); err != nil {
		log.Printf("[Scheduler] invalid schedule %s: %v", row.Id, err)
	}
}

// runDetached runs a schedule in a background goroutine launched by a
// fire-and-forget caller (an HTTP handler that already responded, or a
// cron callback). It must never let a panic escape and crash the process
// -- a background job failing is an operational event to log, not a
// reason to take down the whole server.
func (r *ScheduleRunner) runDetached(ownerID string) {
	defer func() {
		if rec := recover(); rec != nil {
			log.Printf("[Scheduler] run %s panicked: %v", ownerID, rec)
		}
	}()
	if err := r.Run(context.Background(), ownerID); err != nil {
		log.Printf("[Scheduler] run %s: %v", ownerID, err)
	}
}

// Run executes a schedule synchronously. A paused schedule is a legitimate no-op.
func (r *ScheduleRunner) Run(ctx context.Context, ownerID string) error {
	row, err := r.App.FindRecordById("schedule_owners", ownerID)
	if err != nil {
		return fmt.Errorf("find schedule %s: %w", ownerID, err)
	}
	if row.GetBool("paused") {
		return nil
	}
	if err := ctx.Err(); err != nil {
		return err
	}
	coll, err := r.App.FindCollectionByNameOrId("chats")
	if err != nil {
		return fmt.Errorf("find chats collection: %w", err)
	}
	chat := core.NewRecord(coll)
	chat.Set("title", row.GetString("display_name")+" — "+r.now().Format("Jan 2 15:04"))
	chat.Set("user", row.GetString("user"))
	if err := r.App.Save(chat); err != nil {
		return fmt.Errorf("create chat: %w", err)
	}
	c := r.Coord()
	if c == nil {
		return fmt.Errorf("coordinator unavailable")
	}
	userID, chatID := row.GetString("user"), chat.Id
	if _, err := c.StartPrompt(chatID, row.GetString("prompt"), func(context.Context) (string, error) { return sessionprofile.SessionForChat(r.App, chatID, userID) }, func(ctx context.Context) (coordinator.SessionProfile, error) {
		return sessionprofile.Build(r.App, chatID, ctx, r.OllamaBaseURL)
	}, func(ctx context.Context, sessionID string) error {
		profile, err := sessionprofile.Build(r.App, chatID, ctx, r.OllamaBaseURL)
		if err != nil {
			return err
		}
		return sessionprofile.SaveSession(ctx, r.App, chatID, userID, sessionID, profile.ResolvedInstanceID)
	}, func(context.Context, acpsdk.StopReason) error {
		go func() {
			if err := hooks.SendPushNotification(r.App, userID, "PocketCoder", "Your scheduled agent replied", "schedule", chatID); err != nil {
				log.Printf("[Push] schedule: %v", err)
			}
		}()
		return nil
	}); err != nil {
		return fmt.Errorf("start prompt: %w", err)
	}
	row.Set("last_run", r.now().UTC().Format(time.RFC3339))
	if err := r.App.Save(row); err != nil {
		return fmt.Errorf("update last_run: %w", err)
	}
	return nil
}
