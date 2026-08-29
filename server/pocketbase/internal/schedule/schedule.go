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

// Package schedule executes scheduled agent prompts on a cron trigger or
// an on-demand request.
package schedule

import (
	"context"
	"fmt"
	"log"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/sessionprofile"
)

var notifyRunStarted = hooks.NotifyRunStarted
var notifyRunFinished = hooks.NotifyRunFinished

func JobID(id string) string { return "pocketcoder-schedule-" + id }

type Runner struct {
	App           core.App
	Coord         func() coordinator.AgentRuntime
	OllamaBaseURL string
	Now           func() time.Time
}

func (r *Runner) now() time.Time {
	if r.Now != nil {
		return r.Now()
	}
	return time.Now()
}

func Register(runner *Runner, row *core.Record) {
	runner.App.Cron().Remove(JobID(row.Id))
	if row.GetBool("paused") || row.GetString("cron") == "" {
		return
	}
	if err := runner.App.Cron().Add(JobID(row.Id), row.GetString("cron"), func() {
		go runner.RunDetached(row.Id)
	}); err != nil {
		log.Printf("[Scheduler] invalid schedule %s: %v", row.Id, err)
	}
}

// RunDetached runs a schedule in a background goroutine launched by a
// fire-and-forget caller (an HTTP handler that already responded, or a
// cron callback). It must never let a panic escape and crash the process
// -- a background job failing is an operational event to log, not a
// reason to take down the whole server.
func (r *Runner) RunDetached(ownerID string) {
	defer func() {
		if rec := recover(); rec != nil {
			log.Printf("[Scheduler] run %s panicked: %v", ownerID, rec)
		}
	}()
	if err := r.Run(context.Background(), ownerID); err != nil {
		log.Printf("[Scheduler] run %s: %v", ownerID, err)
	}
}

func (r *Runner) Run(ctx context.Context, ownerID string) error {
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
	}, coordinator.WithOnRunEnded(func(_ context.Context, chatID string, outcome coordinator.RunOutcome) {
		go func() {
			if err := notifyRunFinished(r.App, chatID, string(outcome)); err != nil {
				log.Printf("[Push] schedule notify-finished: %v", err)
			}
		}()
	})); err != nil {
		return fmt.Errorf("start prompt: %w", err)
	}
	go func() {
		if err := notifyRunStarted(r.App, chatID); err != nil {
			log.Printf("[Push] schedule notify-started: %v", err)
		}
	}()
	row.Set("last_run", r.now().UTC().Format(time.RFC3339))
	if err := r.App.Save(row); err != nil {
		return fmt.Errorf("update last_run: %w", err)
	}
	return nil
}
