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

// @pocketcoder-core: Cron Hooks. Manages scheduled agent tasks via PocketBase's built-in cron scheduler.
package hooks

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
)

const cronJobPrefix = "pc_cron_"

// RegisterCronHooks registers hooks for scheduled agent task management.
// When a user creates, updates, or deletes a cron job record, this hook
// syncs the PocketBase cron scheduler accordingly. When a job fires, it
// creates a message (in an existing or new chat) that the Interface event
// pump picks up and forwards to OpenCode.
func RegisterCronHooks(app core.App) {
	log.Println("⏰ [Cron] Registering cron hooks...")

	// On startup: load all enabled cron jobs and register with app.Cron()
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		log.Println("⏰ [Cron] Loading enabled cron jobs...")
		syncAllCronJobs(app)
		return e.Next()
	})

	// On create/update: re-sync the affected job
	app.OnRecordAfterCreateSuccess("cron_jobs").BindFunc(func(e *core.RecordEvent) error {
		syncCronJob(app, e.Record)
		return e.Next()
	})
	app.OnRecordAfterUpdateSuccess("cron_jobs").BindFunc(func(e *core.RecordEvent) error {
		syncCronJob(app, e.Record)
		return e.Next()
	})

	// On delete: remove from scheduler
	app.OnRecordAfterDeleteSuccess("cron_jobs").BindFunc(func(e *core.RecordEvent) error {
		jobID := cronJobPrefix + e.Record.Id
		app.Cron().Remove(jobID)
		log.Printf("⏰ [Cron] Removed job '%s' from scheduler", e.Record.GetString("name"))
		return e.Next()
	})
}

// syncAllCronJobs queries all enabled cron jobs and registers them with app.Cron().
func syncAllCronJobs(app core.App) {
	records, err := app.FindRecordsByFilter(
		"cron_jobs",
		"enabled = true",
		"",
		0, 0,
	)
	if err != nil {
		log.Printf("⚠️ [Cron] Failed to query cron jobs: %v", err)
		return
	}

	for _, record := range records {
		syncCronJob(app, record)
	}

	log.Printf("✅ [Cron] Loaded %d enabled cron job(s)", len(records))
}

// syncCronJob registers or removes a single cron job from the scheduler.
// If the job is enabled, it registers (or re-registers) the cron entry.
// If disabled, it removes any existing entry.
func syncCronJob(app core.App, record *core.Record) {
	jobID := cronJobPrefix + record.Id
	jobName := record.GetString("name")

	// Always remove existing entry first (idempotent re-registration)
	app.Cron().Remove(jobID)

	if !record.GetBool("enabled") {
		log.Printf("⏰ [Cron] Job '%s' is disabled, removed from scheduler", jobName)
		return
	}

	cronExpr := record.GetString("cron_expression")
	if cronExpr == "" {
		log.Printf("⚠️ [Cron] Job '%s' has empty cron expression, skipping", jobName)
		return
	}

	recordID := record.Id
	if err := app.Cron().Add(jobID, cronExpr, func() {
		executeCronJob(app, recordID)
	}); err != nil {
		log.Printf("❌ [Cron] Failed to register job '%s': %v", jobName, err)
		return
	}

	log.Printf("⏰ [Cron] Registered job '%s' with schedule '%s'", jobName, cronExpr)
}

// executeCronJob is the handler called when a cron job fires.
// It creates a message in an existing chat or creates a new chat + message,
// depending on the job's session_mode.
func executeCronJob(app core.App, jobRecordID string) {
	// Re-fetch the record to get the latest state
	jobRecord, err := app.FindRecordById("cron_jobs", jobRecordID)
	if err != nil {
		log.Printf("❌ [Cron] Failed to fetch job record %s: %v", jobRecordID, err)
		return
	}

	if !jobRecord.GetBool("enabled") {
		log.Printf("⏰ [Cron] Job '%s' is disabled, skipping execution", jobRecord.GetString("name"))
		return
	}

	jobName := jobRecord.GetString("name")
	prompt := jobRecord.GetString("prompt")
	sessionMode := jobRecord.GetString("session_mode")
	userID := jobRecord.GetString("user")

	log.Printf("⏰ [Cron] Executing job '%s' (mode: %s)", jobName, sessionMode)

	var chatID string
	var execErr error

	switch sessionMode {
	case "existing":
		chatID = jobRecord.GetString("chat")
		if chatID == "" {
			execErr = fmt.Errorf("session_mode is 'existing' but no chat is linked")
		}
	case "new":
		chatID, execErr = createCronChat(app, jobRecord, userID)
	default:
		execErr = fmt.Errorf("unknown session_mode: %s", sessionMode)
	}

	if execErr != nil {
		updateCronJobStatus(app, jobRecord, "error", execErr.Error())
		log.Printf("❌ [Cron] Job '%s' failed: %v", jobName, execErr)
		return
	}

	// Create the message in the target chat
	if err := createCronMessage(app, chatID, prompt); err != nil {
		updateCronJobStatus(app, jobRecord, "error", err.Error())
		log.Printf("❌ [Cron] Job '%s' failed to create message: %v", jobName, err)
		return
	}

	updateCronJobStatus(app, jobRecord, "ok", "")
	log.Printf("✅ [Cron] Job '%s' executed successfully (chat: %s)", jobName, chatID)
}

// createCronChat creates a new chat for a cron job execution.
func createCronChat(app core.App, jobRecord *core.Record, userID string) (string, error) {
	chatsCollection, err := app.FindCollectionByNameOrId("chats")
	if err != nil {
		return "", fmt.Errorf("failed to find chats collection: %w", err)
	}

	chatRecord := core.NewRecord(chatsCollection)
	chatRecord.Set("title", fmt.Sprintf("%s — %s", jobRecord.GetString("name"), time.Now().Format("Jan 2 15:04")))
	chatRecord.Set("user", userID)
	chatRecord.Set("turn", "user")

	agentID := jobRecord.GetString("agent")
	if agentID != "" {
		chatRecord.Set("agent", agentID)
	}

	if err := app.Save(chatRecord); err != nil {
		return "", fmt.Errorf("failed to create chat: %w", err)
	}

	return chatRecord.Id, nil
}

// createCronMessage creates a user message in the target chat.
func createCronMessage(app core.App, chatID string, prompt string) error {
	messagesCollection, err := app.FindCollectionByNameOrId("messages")
	if err != nil {
		return fmt.Errorf("failed to find messages collection: %w", err)
	}

	parts := []map[string]string{
		{
			"type": "text",
			"text": prompt,
		},
	}
	partsJSON, err := json.Marshal(parts)
	if err != nil {
		return fmt.Errorf("failed to marshal message parts: %w", err)
	}

	msgRecord := core.NewRecord(messagesCollection)
	msgRecord.Set("chat", chatID)
	msgRecord.Set("role", "user")
	msgRecord.Set("user_message_status", "pending")
	msgRecord.Set("parts", string(partsJSON))

	if err := app.Save(msgRecord); err != nil {
		return fmt.Errorf("failed to create message: %w", err)
	}

	return nil
}

// updateCronJobStatus updates the last_executed, last_status, and last_error fields.
func updateCronJobStatus(app core.App, record *core.Record, status string, lastError string) {
	record.Set("last_executed", types.NowDateTime())
	record.Set("last_status", status)
	record.Set("last_error", lastError)

	if err := app.Save(record); err != nil {
		log.Printf("⚠️ [Cron] Failed to update job status for '%s': %v", record.GetString("name"), err)
	}
}
