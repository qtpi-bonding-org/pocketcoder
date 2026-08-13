package api

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/cron"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
)

func resolveOwnedSchedule(app core.App, userID, id string) (*core.Record, error) {
	rec, err := app.FindRecordById("schedule_owners", id)
	if err != nil || rec.GetString("user") != userID {
		return nil, fmt.Errorf("schedule not found")
	}
	return rec, nil
}

func RegisterSchedulesApi(app *pocketbase.PocketBase, e *core.ServeEvent, coord func() *coordinator.Coordinator) {
	e.Router.POST("/api/pocketcoder/schedules/{scheduleId}/run", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}
		id := re.Request.PathValue("scheduleId")
		if id == "" {
			return pocketCoderError(re, 400, "scheduleId is required")
		}
		row, err := resolveOwnedSchedule(app, re.Auth.Id, id)
		if err != nil {
			return pocketCoderError(re, 404, "Schedule not found")
		}
		go runPocketCoderSchedule(app, coord, row.Id)
		return re.JSON(202, map[string]string{"status": "started"})
	}).Bind(apis.RequireAuth())

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

	hook := func(ev *core.RecordEvent) error { registerPocketCoderSchedule(app, coord, ev.Record); return ev.Next() }
	app.OnRecordAfterCreateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterUpdateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterDeleteSuccess("schedule_owners").BindFunc(func(ev *core.RecordEvent) error { app.Cron().Remove(scheduleJobID(ev.Record.Id)); return ev.Next() })
	rows, _ := app.FindRecordsByFilter("schedule_owners", "1=1", "", 0, 0)
	for _, row := range rows {
		registerPocketCoderSchedule(app, coord, row)
	}
}

func scheduleJobID(id string) string { return "pocketcoder-schedule-" + id }
func registerPocketCoderSchedule(app *pocketbase.PocketBase, coord func() *coordinator.Coordinator, row *core.Record) {
	app.Cron().Remove(scheduleJobID(row.Id))
	if row.GetBool("paused") || row.GetString("cron") == "" {
		return
	}
	if err := app.Cron().Add(scheduleJobID(row.Id), row.GetString("cron"), func() { runPocketCoderSchedule(app, coord, row.Id) }); err != nil {
		log.Printf("[Scheduler] invalid schedule %s: %v", row.Id, err)
	}
}

func runPocketCoderSchedule(app *pocketbase.PocketBase, coord func() *coordinator.Coordinator, ownerID string) {
	row, err := app.FindRecordById("schedule_owners", ownerID)
	if err != nil || row.GetBool("paused") {
		return
	}
	coll, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		log.Printf("[Scheduler] create chat: %v", err)
		return
	}
	chat := core.NewRecord(coll)
	chat.Set("title", row.GetString("display_name")+" — "+time.Now().Format("Jan 2 15:04"))
	chat.Set("user", row.GetString("user"))
	if err := app.Save(chat); err != nil {
		log.Printf("[Scheduler] create chat: %v", err)
		return
	}
	c := coord()
	if c == nil {
		log.Printf("[Scheduler] coordinator unavailable")
		return
	}
	userID, chatID := row.GetString("user"), chat.Id
	if _, err := c.StartPrompt(chatID, row.GetString("prompt"), func(context.Context) (string, error) { return agentSessionForChat(app, chatID, userID) }, func(context.Context) (coordinator.SessionProfile, error) { return buildSessionProfile(app, chatID) }, func(ctx context.Context, sessionID string) error {
		profile, err := buildSessionProfile(app, chatID)
		if err != nil {
			return err
		}
		return saveAgentSession(ctx, app, chatID, userID, sessionID, profile.ResolvedInstanceID)
	}, func(context.Context, acpsdk.StopReason) error {
		go hooks.SendPushNotification(app, userID, "PocketCoder", "Your scheduled agent replied", "schedule", chatID)
		return nil
	}); err != nil {
		log.Printf("[Scheduler] start %s: %v", ownerID, err)
		return
	}
	row.Set("last_run", time.Now().UTC().Format(time.RFC3339))
	_ = app.Save(row)
}
