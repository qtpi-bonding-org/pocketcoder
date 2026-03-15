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

// @pocketcoder-core: Cron API. Endpoints for Poco to schedule, list, and cancel cron jobs.
package api

import (
	"fmt"
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// requireAgentOrAdmin checks that the request is authenticated with an agent or admin role.
// Returns a JSON error response if the check fails, or nil if authorized.
func requireAgentOrAdmin(re *core.RequestEvent) error {
	if re.Auth == nil {
		return re.JSON(401, map[string]string{"error": "Authentication required"})
	}
	role := re.Auth.GetString("role")
	if role != "agent" && role != "admin" {
		return re.JSON(403, map[string]string{"error": "Insufficient permissions"})
	}
	return nil
}

// RegisterCronApi registers the cron task management endpoints.
func RegisterCronApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	// POST /api/pocketcoder/schedule_task
	e.Router.POST("/api/pocketcoder/schedule_task", func(re *core.RequestEvent) error {
		if err := requireAgentOrAdmin(re); err != nil {
			return err
		}

		var input struct {
			Name           string `json:"name"`
			CronExpression string `json:"cron_expression"`
			Prompt         string `json:"prompt"`
			SessionMode    string `json:"session_mode"`
			Description    string `json:"description"`
			SessionID      string `json:"session_id"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.Name == "" || input.CronExpression == "" || input.Prompt == "" {
			return re.JSON(400, map[string]string{"error": "name, cron_expression, and prompt are required"})
		}
		if input.SessionMode == "" {
			input.SessionMode = "new"
		}
		if input.SessionMode != "new" && input.SessionMode != "existing" {
			return re.JSON(400, map[string]string{"error": "session_mode must be 'new' or 'existing'"})
		}
		if input.SessionID == "" {
			return re.JSON(400, map[string]string{"error": "session_id is required"})
		}

		// Resolve the human user from the session_id via the chats collection
		humanUserID, chatID, err := resolveHumanUser(app, input.SessionID)
		if err != nil {
			log.Printf("❌ [CronAPI] Failed to resolve human user: %v", err)
			return re.JSON(400, map[string]string{"error": "Could not resolve user from session"})
		}

		// Create the cron_jobs record
		collection, err := app.FindCollectionByNameOrId("cron_jobs")
		if err != nil {
			log.Printf("❌ [CronAPI] Failed to find cron_jobs collection: %v", err)
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}

		record := core.NewRecord(collection)
		record.Set("name", input.Name)
		record.Set("cron_expression", input.CronExpression)
		record.Set("prompt", input.Prompt)
		record.Set("session_mode", input.SessionMode)
		record.Set("description", input.Description)
		record.Set("user", humanUserID)
		record.Set("enabled", true)

		// If session_mode=existing, link to the chat from the current session
		if input.SessionMode == "existing" && chatID != "" {
			record.Set("chat", chatID)
		}

		if err := app.Save(record); err != nil {
			log.Printf("❌ [CronAPI] Failed to create cron job: %v", err)
			return re.JSON(500, map[string]string{"error": "Failed to create scheduled task"})
		}

		log.Printf("⏰ [CronAPI] Created cron job '%s' for user %s", input.Name, humanUserID)
		return re.JSON(200, map[string]any{
			"id":              record.Id,
			"name":            input.Name,
			"cron_expression": input.CronExpression,
			"status":          "scheduled",
		})
	}).Bind(apis.RequireAuth())

	// GET /api/pocketcoder/scheduled_tasks
	e.Router.GET("/api/pocketcoder/scheduled_tasks", func(re *core.RequestEvent) error {
		if err := requireAgentOrAdmin(re); err != nil {
			return err
		}

		sessionID := re.Request.URL.Query().Get("session_id")
		if sessionID == "" {
			return re.JSON(400, map[string]string{"error": "session_id query parameter is required"})
		}

		humanUserID, _, err := resolveHumanUser(app, sessionID)
		if err != nil {
			log.Printf("❌ [CronAPI] Failed to resolve human user: %v", err)
			return re.JSON(400, map[string]string{"error": "Could not resolve user from session"})
		}

		records, err := app.FindRecordsByFilter(
			"cron_jobs",
			"user = {:userId}",
			"-created",
			0, 0,
			map[string]any{"userId": humanUserID},
		)
		if err != nil {
			log.Printf("❌ [CronAPI] Failed to query cron jobs: %v", err)
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}

		tasks := make([]map[string]any, 0, len(records))
		for _, r := range records {
			tasks = append(tasks, map[string]any{
				"id":              r.Id,
				"name":            r.GetString("name"),
				"cron_expression": r.GetString("cron_expression"),
				"prompt":          r.GetString("prompt"),
				"session_mode":    r.GetString("session_mode"),
				"enabled":         r.GetBool("enabled"),
				"last_executed":   r.GetString("last_executed"),
				"last_status":     r.GetString("last_status"),
			})
		}

		return re.JSON(200, tasks)
	}).Bind(apis.RequireAuth())

	// POST /api/pocketcoder/cancel_scheduled_task
	e.Router.POST("/api/pocketcoder/cancel_scheduled_task", func(re *core.RequestEvent) error {
		if err := requireAgentOrAdmin(re); err != nil {
			return err
		}

		var input struct {
			TaskID string `json:"task_id"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.TaskID == "" {
			return re.JSON(400, map[string]string{"error": "task_id is required"})
		}

		record, err := app.FindRecordById("cron_jobs", input.TaskID)
		if err != nil {
			return re.JSON(404, map[string]string{"error": "Scheduled task not found"})
		}

		taskName := record.GetString("name")
		record.Set("enabled", false)
		if err := app.Save(record); err != nil {
			log.Printf("❌ [CronAPI] Failed to disable cron job: %v", err)
			return re.JSON(500, map[string]string{"error": "Failed to cancel scheduled task"})
		}

		log.Printf("⏰ [CronAPI] Disabled cron job '%s' (%s)", taskName, input.TaskID)
		return re.JSON(200, map[string]any{
			"id":     input.TaskID,
			"name":   taskName,
			"status": "cancelled",
		})
	}).Bind(apis.RequireAuth())
}

// resolveHumanUser finds the human user ID and chat ID from an OpenCode session ID.
func resolveHumanUser(app *pocketbase.PocketBase, sessionID string) (string, string, error) {
	records, err := app.FindRecordsByFilter(
		"chats",
		"ai_engine_session_id = {:sessionId}",
		"-created",
		1, 0,
		map[string]any{"sessionId": sessionID},
	)
	if err != nil || len(records) == 0 {
		return "", "", fmt.Errorf("no chat found for session_id: %s", sessionID)
	}

	userID := records[0].GetString("user")
	chatID := records[0].Id
	return userID, chatID, nil
}
