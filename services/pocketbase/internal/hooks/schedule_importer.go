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

// @pocketcoder-core: Schedule Importer. Turns fired Goose schedules into
// ordinary PocketCoder chats. See
// docs/superpowers/specs/2026-07-23-scheduler-ui-design.md's Component 3.
// PocketBase has no messages table (services/pocketbase/pb_migrations/
// 1752000000_prune_legacy_runtime.go) — chat history is replayed live from
// Goose via session/load (coordinator/run.go's StreamColdReplay), so
// "importing" a session requires only a chats row + a goose_sessions row
// pointing at it. Opening that chat renders its content automatically.
package hooks

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/pocketbase/pocketbase/core"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
)

// listScheduleSessionsParams mirrors Goose's
// ListScheduleSessionsRequest_unstable (acp-schema.json), required
// [scheduleId, limit].
type listScheduleSessionsParams struct {
	ScheduleID string `json:"scheduleId"`
	Limit      int    `json:"limit"`
}
type scheduleSessionEntry struct {
	SessionID string `json:"sessionId"`
}
type listScheduleSessionsResponse struct {
	Sessions []scheduleSessionEntry `json:"sessions"`
}

// ImportSession creates a chats row + goose_sessions row for a
// newly-observed Goose session produced by firing the schedule `owner`
// owns, then notifies the schedule's owner. Both runImportPoll (this
// file) and api.runScheduleNowAndImport (Task 4, the run-now fast path)
// call this same function — see the design spec's Component 3.
//
// Dedup relies on goose_sessions' unique index on goose_session_id
// (1748000500_goose_sessions.go) — the existence check plus both writes
// run inside one transaction so a losing race (the poller and a run-now
// fast path importing the same session concurrently) can never leave a
// dangling chat with no linked goose_sessions row.
func ImportSession(app core.App, owner *core.Record, sessionID string) error {
	var chatID, userID, displayName string
	imported := false

	err := app.RunInTransaction(func(txApp core.App) error {
		existing, _ := txApp.FindFirstRecordByFilter("goose_sessions", "goose_session_id = {:sid}", map[string]any{"sid": sessionID})
		if existing != nil {
			return nil // already imported — not an error, just nothing to do
		}

		chatsCol, err := txApp.FindCollectionByNameOrId("chats")
		if err != nil {
			return fmt.Errorf("find chats collection: %w", err)
		}
		userID = owner.GetString("user")
		displayName = owner.GetString("display_name")

		chat := core.NewRecord(chatsCol)
		chat.Set("title", fmt.Sprintf("%s — %s", displayName, time.Now().Format("Jan 2 15:04")))
		chat.Set("user", userID)
		if err := txApp.Save(chat); err != nil {
			return fmt.Errorf("create chat: %w", err)
		}
		chatID = chat.Id

		sessionsCol, err := txApp.FindCollectionByNameOrId("goose_sessions")
		if err != nil {
			return fmt.Errorf("find goose_sessions collection: %w", err)
		}
		session := core.NewRecord(sessionsCol)
		session.Set("chat", chatID)
		session.Set("user", userID)
		session.Set("goose_session_id", sessionID)
		if err := txApp.Save(session); err != nil {
			return fmt.Errorf("create goose_sessions row: %w", err)
		}

		imported = true
		return nil
	})
	if err != nil {
		return err
	}
	if imported {
		SendPushNotification(app, userID, displayName, "Scheduled task finished", "schedule", chatID)
	}
	return nil
}

// runImportPoll is the poller's testable core: for every schedule_owners
// row (across all users — this is a background job, not a per-request
// handler), dial one AdminConn for the whole pass, call
// schedules/sessions/list per row, and import every unseen session.
// Errors on one row are logged and skipped — one broken schedule must not
// block importing the rest.
func runImportPoll(app core.App, coord func() *coordinator.Coordinator) {
	owners, err := app.FindRecordsByFilter("schedule_owners", "1=1", "", 0, 0)
	if err != nil {
		log.Printf("⚠️ [Scheduler] import poll: failed to list schedule_owners: %v", err)
		return
	}
	if len(owners) == 0 {
		return
	}
	c := coord()
	if c == nil {
		return
	}
	ctx := context.Background()
	conn, err := c.AdminConn(ctx)
	if err != nil {
		log.Printf("⚠️ [Scheduler] import poll: AdminConn failed: %v", err)
		return
	}
	defer conn.Close()

	for _, owner := range owners {
		gooseScheduleID := owner.GetString("goose_schedule_id")
		raw, err := conn.CallExtension(ctx, "_goose/unstable/schedules/sessions/list", listScheduleSessionsParams{ScheduleID: gooseScheduleID, Limit: 20})
		if err != nil {
			log.Printf("⚠️ [Scheduler] import poll: sessions/list failed for %s: %v", gooseScheduleID, err)
			continue
		}
		var resp listScheduleSessionsResponse
		if err := json.Unmarshal(raw, &resp); err != nil {
			log.Printf("⚠️ [Scheduler] import poll: failed to parse sessions/list response for %s: %v", gooseScheduleID, err)
			continue
		}
		for _, s := range resp.Sessions {
			if err := ImportSession(app, owner, s.SessionID); err != nil {
				log.Printf("⚠️ [Scheduler] import poll: failed to import session %s: %v", s.SessionID, err)
			}
		}
	}
}

// RegisterScheduleImportHooks registers the every-60s background poll
// that turns fired schedules' Goose sessions into ordinary PocketCoder
// chats. Reuses app.Cron() — already live, functional infrastructure
// (confirmed independent of the dead hooks/cron.go this plan retires in
// Task 6) — no new polling mechanism needed.
func RegisterScheduleImportHooks(app core.App, coord func() *coordinator.Coordinator) {
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		if err := app.Cron().Add("schedule-import", "* * * * *", func() { runImportPoll(app, coord) }); err != nil {
			log.Printf("⚠️ [Scheduler] failed to register import poll: %v", err)
		}
		return e.Next()
	})
}
