package api

import (
	"log"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/utils"
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

		log.Printf("🛡️ [Sovereign Authority] Evaluating Verb: %s, Nouns: %v", input.Permission, input.Patterns)

		isWhitelisted := false

		// --- A. EVALUATE VERB (whitelist_actions) ---
		actions, _ := app.FindRecordsByFilter(
			"whitelist_actions",
			"active = true && permission = {:perm}",
			"-created", 100, 0,
			map[string]any{"perm": input.Permission},
		)

		for _, rule := range actions {
			kind := rule.GetString("kind")
			value := rule.GetString("value")
			commandId := rule.GetString("command")

			if input.Permission == "bash" {
				cmdStr, _ := input.Metadata["command"].(string)
				if kind == "strict" && commandId != "" {
					cmdRec, _ := app.FindFirstRecordByFilter("commands", "id = {:id} && command = {:cmd}", map[string]any{"id": commandId, "cmd": cmdStr})
					if cmdRec != nil {
						isWhitelisted = true
						break
					}
				} else if kind == "pattern" && value != "" {
					if utils.MatchWildcard(cmdStr, value) {
						isWhitelisted = true
						break
					}
				}
			} else {
				if kind == "pattern" {
					if value == "*" || value == "" {
						isWhitelisted = true
						break
					}
				}
			}
		}

		// --- B. EVALUATE NOUN (whitelist_targets) ---
		if isWhitelisted && len(input.Patterns) > 0 {
			targets, _ := app.FindRecordsByFilter("whitelist_targets", "active = true", "-created", 300, 0, nil)

			for _, p := range input.Patterns {
				patternMatch := false
				if p == "" {
					continue
				}
				for _, target := range targets {
					if utils.MatchWildcard(p, target.GetString("pattern")) {
						patternMatch = true
						break
					}
				}
				if !patternMatch {
					isWhitelisted = false
					log.Printf("🛑 [Noun Rejected] %s", p)
					break
				}
			}
		}

		// --- C. CREATE AUDIT RECORD ---
		permColl, _ := app.FindCollectionByNameOrId("permissions")
		record := core.NewRecord(permColl)

		status := "draft"
		if isWhitelisted {
			status = "authorized"
		}

		record.Set("opencode_id", input.OpencodeID)
		record.Set("session_id", input.SessionID)
		record.Set("chat", input.ChatID)
		record.Set("permission", input.Permission)
		record.Set("patterns", input.Patterns)
		record.Set("metadata", input.Metadata)
		record.Set("message_id", input.MessageID)
		record.Set("call_id", input.CallID)
		record.Set("status", status)
		record.Set("source", "relay")
		record.Set("message", input.Message)
		record.Set("challenge", uuid.NewString())

		if err := app.Save(record); err != nil {
			log.Printf("❌ Failed to save audit: %v", err)
			return re.JSON(500, map[string]string{"error": "Persistence error"})
		}

		return re.JSON(200, map[string]any{
			"permitted": isWhitelisted,
			"id":        record.Id,
			"status":    status,
		})
	})
}
