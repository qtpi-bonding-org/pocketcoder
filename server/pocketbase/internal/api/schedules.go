package api

import (
	"fmt"
	"log"
	"net/http"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/cron"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/ollama"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/schedule"
)

func AddScheduleOperations(app core.App, registry *operation.Registry, coord func() coordinator.AgentRuntime) *schedule.Runner {
	ollamaBaseURL := ollama.ResolveBaseURL()
	runner := &schedule.Runner{App: app, Coord: coord, OllamaBaseURL: ollamaBaseURL}
	registry.Add(operation.Route{OperationID: "runScheduleNow", Method: http.MethodPost, Path: "/api/pocketcoder/v1/schedules/{scheduleId}/run", Auth: true, Action: func(re *core.RequestEvent) error {
		if err := RunScheduleNow(app, runner, re); err != nil {
			return err
		}
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
		schedule.Register(runner, ev.Record)
		return ev.Next()
	}
	app.OnRecordAfterCreateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterUpdateSuccess("schedule_owners").BindFunc(hook)
	app.OnRecordAfterDeleteSuccess("schedule_owners").BindFunc(func(ev *core.RecordEvent) error { app.Cron().Remove(schedule.JobID(ev.Record.Id)); return ev.Next() })
	rows, err := app.FindRecordsByFilter("schedule_owners", "1=1", "", 0, 0)
	if err != nil {
		log.Printf("[Scheduler] failed to load schedules at startup: %v", err)
		return runner
	}
	for _, row := range rows {
		schedule.Register(runner, row)
	}
	return runner
}

func RunScheduleNow(app core.App, runner *schedule.Runner, re *core.RequestEvent) error {
	id := re.Request.PathValue("scheduleId")
	if id == "" {
		return re.BadRequestError("scheduleId is required", nil)
	}
	row, err := requireOwnedRecord(app, re, "schedule_owners", id)
	if err != nil {
		return err
	}
	go runner.RunDetached(row.Id)
	return nil
}
