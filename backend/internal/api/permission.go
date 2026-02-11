package api

import (
	"log"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/permission"
)

// RegisterPermissionApi registers the Sovereign Authority evaluation endpoint.
func RegisterPermissionApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.POST("/api/pocketcoder/permission", func(re *core.RequestEvent) error {
		var input struct {
			Permission string         `json:"permission"`
			Patterns   []string       `json:"patterns"`
			ChatID     string         `json:"chat_id"`
			SessionID  string         `json:"session_id"`
			OpencodeID string         `json:"opencode_id"`
			Metadata   map[string]any `json:"metadata"`
			Message    string         `json:"message"`
			MessageID  string         `json:"message_id"`
			CallID     string         `json:"call_id"`
		}

		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}

		// 1. Evaluate using the shared permission service
		isPermitted, status := permission.Evaluate(app, permission.EvaluationInput{
			Permission: input.Permission,
			Patterns:   input.Patterns,
			Metadata:   input.Metadata,
		})

		// 2. Create Audit Record
		permColl, _ := app.FindCollectionByNameOrId("permissions")
		record := core.NewRecord(permColl)

		record.Set("opencode_id", input.OpencodeID)
		record.Set("session_id", input.SessionID)
		record.Set("chat", input.ChatID)
		record.Set("permission", input.Permission)
		record.Set("patterns", input.Patterns)
		record.Set("metadata", input.Metadata)
		record.Set("message_id", input.MessageID)
		record.Set("call_id", input.CallID)
		record.Set("status", status)
		record.Set("source", "relay-api") // Clarify source
		record.Set("message", input.Message)
		record.Set("challenge", uuid.NewString())

		if err := app.Save(record); err != nil {
			log.Printf("❌ Failed to save audit: %v", err)
			return re.JSON(500, map[string]string{"error": "Persistence error"})
		}

		return re.JSON(200, map[string]any{
			"permitted": isPermitted,
			"id":        record.Id,
			"status":    status,
		})
	})
}
