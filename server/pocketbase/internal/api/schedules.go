package api

import (
	"context"
	"fmt"
	"log"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
)

type scheduleResp struct {
	ID               string  `json:"id"`
	DisplayName      string  `json:"displayName"`
	Cron             string  `json:"cron"`
	Paused           bool    `json:"paused"`
	CurrentlyRunning bool    `json:"currentlyRunning"`
	LastRun          *string `json:"lastRun"`
}
type createScheduleRequest struct {
	DisplayName string `json:"displayName"`
	Cron        string `json:"cron"`
	Prompt      string `json:"prompt"`
}

func resolveOwnedSchedule(app core.App, userID, id string) (*core.Record, error) {
	rec, err := app.FindRecordById("schedule_owners", id)
	if err != nil || rec.GetString("user") != userID {
		return nil, fmt.Errorf("schedule not found")
	}
	return rec, nil
}

func RegisterSchedulesApi(app *pocketbase.PocketBase, e *core.ServeEvent, coord func() *coordinator.Coordinator) {
	e.Router.POST("/api/pocketcoder/schedules/list", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		rows, err := app.FindRecordsByFilter("schedule_owners", "user = {:user}", "display_name", 0, 0, map[string]any{"user": re.Auth.Id})
		if err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		out := make([]scheduleResp, 0, len(rows))
		for _, row := range rows {
			out = append(out, scheduleResponse(row))
		}
		return re.JSON(200, map[string]any{"schedules": out})
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/create", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var in createScheduleRequest
		if err := re.BindBody(&in); err != nil || in.DisplayName == "" || in.Cron == "" || in.Prompt == "" {
			return re.JSON(400, map[string]string{"error": "displayName, cron, and prompt are required"})
		}
		coll, err := app.FindCollectionByNameOrId("schedule_owners")
		if err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		row := core.NewRecord(coll)
		row.Set("user", re.Auth.Id)
		row.Set("display_name", in.DisplayName)
		row.Set("cron", in.Cron)
		row.Set("prompt", in.Prompt)
		row.Set("paused", false)
		if err := app.Save(row); err != nil {
			return re.JSON(400, map[string]string{"error": err.Error()})
		}
		registerPocketCoderSchedule(app, coord, row)
		return re.JSON(200, scheduleResponse(row))
	}).Bind(apis.RequireAuth())

	e.Router.POST("/api/pocketcoder/schedules/rename", func(re *core.RequestEvent) error {
		return updateScheduleField(app, re, "display_name", "displayName", coord)
	}).Bind(apis.RequireAuth())
	e.Router.POST("/api/pocketcoder/schedules/update-cron", func(re *core.RequestEvent) error {
		return updateScheduleField(app, re, "cron", "cron", coord)
	}).Bind(apis.RequireAuth())
	for endpoint, paused := range map[string]bool{"pause": true, "unpause": false} {
		e.Router.POST("/api/pocketcoder/schedules/"+endpoint, func(re *core.RequestEvent) error {
			if re.Auth == nil {
				return re.JSON(401, map[string]string{"error": "Authentication required"})
			}
			var in struct {
				ID string `json:"id"`
			}
			if err := re.BindBody(&in); err != nil || in.ID == "" {
				return re.JSON(400, map[string]string{"error": "id is required"})
			}
			row, err := resolveOwnedSchedule(app, re.Auth.Id, in.ID)
			if err != nil {
				return re.JSON(404, map[string]string{"error": "Schedule not found"})
			}
			row.Set("paused", paused)
			if err := app.Save(row); err != nil {
				return re.JSON(400, map[string]string{"error": err.Error()})
			}
			registerPocketCoderSchedule(app, coord, row)
			return re.JSON(200, map[string]bool{"ok": true})
		}).Bind(apis.RequireAuth())
	}
	e.Router.POST("/api/pocketcoder/schedules/delete", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var in struct {
			ID string `json:"id"`
		}
		if err := re.BindBody(&in); err != nil || in.ID == "" {
			return re.JSON(400, map[string]string{"error": "id is required"})
		}
		row, err := resolveOwnedSchedule(app, re.Auth.Id, in.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}
		app.Cron().Remove(scheduleJobID(row.Id))
		if err := app.Delete(row); err != nil {
			return re.JSON(500, map[string]string{"error": err.Error()})
		}
		return re.JSON(200, map[string]bool{"deleted": true})
	}).Bind(apis.RequireAuth())
	e.Router.POST("/api/pocketcoder/schedules/run-now", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}
		var in struct {
			ID string `json:"id"`
		}
		if err := re.BindBody(&in); err != nil || in.ID == "" {
			return re.JSON(400, map[string]string{"error": "id is required"})
		}
		row, err := resolveOwnedSchedule(app, re.Auth.Id, in.ID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Schedule not found"})
		}
		go runPocketCoderSchedule(app, coord, row.Id)
		return re.JSON(202, map[string]string{"status": "started"})
	}).Bind(apis.RequireAuth())

	hook := func(ev *core.RecordEvent) error { registerPocketCoderSchedule(app, coord, ev.Record); return ev.Next() }
	app.OnRecordAfterCreateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterUpdateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterDeleteSuccess("schedule_owners").BindFunc(func(ev *core.RecordEvent) error { app.Cron().Remove(scheduleJobID(ev.Record.Id)); return ev.Next() })
	rows, _ := app.FindRecordsByFilter("schedule_owners", "1=1", "", 0, 0)
	for _, row := range rows {
		registerPocketCoderSchedule(app, coord, row)
	}
}

func updateScheduleField(app *pocketbase.PocketBase, re *core.RequestEvent, field, jsonField string, coord func() *coordinator.Coordinator) error {
	if re.Auth == nil {
		return re.JSON(401, map[string]string{"error": "Authentication required"})
	}
	var in map[string]any
	if err := re.BindBody(&in); err != nil {
		return re.JSON(400, map[string]string{"error": "Invalid request body"})
	}
	id, _ := in["id"].(string)
	value, _ := in[jsonField].(string)
	if id == "" || value == "" {
		return re.JSON(400, map[string]string{"error": "id and value are required"})
	}
	row, err := resolveOwnedSchedule(app, re.Auth.Id, id)
	if err != nil {
		return re.JSON(404, map[string]string{"error": "Schedule not found"})
	}
	row.Set(field, value)
	if err := app.Save(row); err != nil {
		return re.JSON(400, map[string]string{"error": err.Error()})
	}
	registerPocketCoderSchedule(app, coord, row)
	return re.JSON(200, scheduleResponse(row))
}

func scheduleJobID(id string) string { return "pocketcoder-schedule-" + id }
func scheduleResponse(row *core.Record) scheduleResp {
	var last *string
	if value := row.GetString("last_run"); value != "" {
		last = &value
	}
	return scheduleResp{ID: row.Id, DisplayName: row.GetString("display_name"), Cron: row.GetString("cron"), Paused: row.GetBool("paused"), LastRun: last}
}
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
