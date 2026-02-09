package main

import (
	"log"
	"os"

	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/google/uuid"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func matchWildcard(str string, pattern string) bool {
	escaped := regexp.QuoteMeta(pattern)
	escaped = strings.ReplaceAll(escaped, "\\*", ".*")
	escaped = strings.ReplaceAll(escaped, "\\?", ".")

	if strings.HasSuffix(escaped, " .*") {
		escaped = escaped[:len(escaped)-3] + "( .*|$|\\n)?"
	}

	re, err := regexp.Compile("(?s)^" + escaped + "$")
	if err != nil {
		return false
	}
	return re.MatchString(str)
}

func main() {
	app := pocketbase.New()

	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate: true,
	})

	// ------------------------------------------------------------
	// 📡 SOVEREIGN AUTHORITY (Permission Firewall)
	// ------------------------------------------------------------
	
	// 1. CREATION: Generate Challenge, Default to Draft
	app.OnRecordCreate("permissions").BindFunc(func(e *core.RecordEvent) error {
		permission := e.Record.GetString("permission")

		// Generate Authority Challenge (for cryptographic verification if needed later)
		e.Record.Set("challenge", uuid.NewString())

		// Ensure initial status is draft if not already set by Authority
		if e.Record.GetString("status") == "" {
			e.Record.Set("status", "draft")
		}

		log.Printf("🛡️ [Permission Firewall] Gating: %s. Status: %s", permission, e.Record.GetString("status"))

		return e.Next()
	})
	
	// ------------------------------------------------------------
	// 🛡️ RUNTIME SEEDING & ENDPOINTS
	// ------------------------------------------------------------
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		
		// 📡 PERMISSION EVALUATION ENDPOINT
		// This endpoint evaluates an Intent and creates the permission record.
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
						if matchWildcard(cmdStr, value) {
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
					if p == "" { continue }
					for _, target := range targets {
						if matchWildcard(p, target.GetString("pattern")) {
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
			record.Set("source", "opencode-plugin")
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

		// Seeding (Existing)
		superusers, _ := app.FindCollectionByNameOrId("_superusers")
		if superusers != nil {
			suEmail := os.Getenv("POCKETBASE_SUPERUSER_EMAIL")
			if suEmail != "" {
				existing, _ := app.FindFirstRecordByFilter("_superusers", "email = {:email}", map[string]any{"email": suEmail})
				if existing == nil {
					su := core.NewRecord(superusers)
					su.Set("email", suEmail)
					su.Set("password", os.Getenv("POCKETBASE_SUPERUSER_PASSWORD"))
					app.Save(su)
				}
			}
		}

		users, _ := app.FindCollectionByNameOrId("users")
		if users != nil {
			adminEmail := os.Getenv("POCKETBASE_USER_EMAIL")
			if adminEmail != "" {
				existing, _ := app.FindFirstRecordByFilter("users", "email = {:email}", map[string]any{"email": adminEmail})
				if existing == nil {
					admin := core.NewRecord(users)
					admin.Set("email", adminEmail)
					admin.Set("password", os.Getenv("POCKETBASE_USER_PASSWORD"))
					admin.Set("role", "admin")
					admin.SetVerified(true)
					app.Save(admin)
				}
			}
			
			agentEmail := os.Getenv("AGENT_EMAIL")
			if agentEmail != "" {
				existing, _ := app.FindFirstRecordByFilter("users", "email = {:email}", map[string]any{"email": agentEmail})
				if existing == nil {
					agent := core.NewRecord(users)
					agent.Set("email", agentEmail)
					agent.Set("password", os.Getenv("AGENT_PASSWORD"))
					agent.Set("role", "agent")
					agent.SetVerified(true)
					app.Save(agent)
				}
			}
		}
		return e.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
