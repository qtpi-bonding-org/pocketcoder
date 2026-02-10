package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/google/uuid"
	"github.com/qtpi-automaton/pocketcoder/backend/pkg/relay"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
	"gopkg.in/yaml.v3"
)

// matchWildcard implements a simple glob-like pattern matching (e.g. /workspace/**).
// It converts internal wildcards (*, ?) into regex patterns.
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
		log.Printf("🚀 Registering custom endpoints...")

		// Initialize Relay Service (Optional toggle during migration)
		if os.Getenv("ENABLE_GO_RELAY") == "true" {
			openCodeURL := os.Getenv("OPENCODE_URL")
			if openCodeURL == "" {
				openCodeURL = "http://opencode:3000"
			}
			relaySvc := relay.NewRelayService(app, openCodeURL)
			relaySvc.Start()
		} else {
			log.Println("🌉 [Relay] Go-based Relay is DISABLED (ENABLE_GO_RELAY != true)")
		}

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

		// 📂 ARTIFACT SERVING
		e.Router.GET("/api/pocketcoder/artifact/{path...}", func(re *core.RequestEvent) error {
			if re.Auth == nil {
				return re.ForbiddenError("Auth required", nil)
			}
			
			// PocketBase v0.23+ uses Go 1.22 routing
			pathParam := re.Request.PathValue("path")
			if pathParam == "" {
				return re.BadRequestError("Path required", nil)
			}

			cleanPath := filepath.Join("/workspace", pathParam)
			finalPath := filepath.Clean(cleanPath)

			if !strings.HasPrefix(finalPath, "/workspace") {
				return re.ForbiddenError("Invalid path", nil)
			}

			if _, err := os.Stat(finalPath); os.IsNotExist(err) {
				return re.NotFoundError("File not found", nil)
			}

			http.ServeFile(re.Response, re.Request, cleanPath)
			return nil
		})

		// 🔑 SSH PUBLIC KEYS SYNC ENDPOINT
		// Returns all authorized public keys as a newline-separated list
		e.Router.GET("/api/pocketcoder/ssh_keys", func(re *core.RequestEvent) error {
			// Fetch all active SSH keys from the ssh_keys collection
			// Note: Empty string for sort means no sorting
			sshKeys, err := app.FindRecordsByFilter("ssh_keys", "is_active = TRUE", "", 1000, 0, nil)
			if err != nil {
				log.Printf("❌ Failed to fetch SSH keys: %v", err)
				return re.String(500, fmt.Sprintf("Failed to fetch SSH keys: %v", err))
			}
			
			var keys []string
			for _, record := range sshKeys {
				key := record.GetString("public_key")
				if key != "" {
					keys = append(keys, key)
				}
			}

			return re.String(200, strings.Join(keys, "\n"))
		})

		return e.Next()
	})

	// 🤖 AI AGENT ASSEMBLY LOGIC
	getAgentBundle := func(agent *core.Record) (string, error) {
		// 1. Expand dependencies (if not already expanded)
		app.ExpandRecord(agent, []string{"prompt", "model"}, nil)

		// 2. Fetch Permission Rules
		rules, _ := app.FindRecordsByFilter(
			"ai_permission_rules",
			"agent = {:id}",
			"pattern", 100, 0,
			map[string]any{"id": agent.Id},
		)

		// 3. Build Frontmatter
		frontmatter := make(map[string]any)
		if desc := agent.GetString("description"); desc != "" {
			frontmatter["description"] = desc
		}
		if mode := agent.GetString("mode"); mode != "" {
			frontmatter["mode"] = mode
		}
		if model := agent.ExpandedOne("model"); model != nil {
			frontmatter["model"] = model.GetString("identifier")
		}
		if steps := agent.GetInt("steps"); steps > 0 {
			frontmatter["steps"] = steps
		}

		if len(rules) > 0 {
			perms := make(map[string]string)
			for _, r := range rules {
				perms[r.GetString("pattern")] = r.GetString("action")
			}
			frontmatter["permission"] = perms
		}

		yamlBytes, err := yaml.Marshal(frontmatter)
		if err != nil {
			return "", err
		}

		// 4. Combine with Prompt Body
		body := ""
		if prompt := agent.ExpandedOne("prompt"); prompt != nil {
			body = prompt.GetString("body")
		}

		return "---\n" + string(yamlBytes) + "---\n\n" + body, nil
	}

	updateAgentConfig := func(agent *core.Record) error {
		bundle, err := getAgentBundle(agent)
		if err != nil {
			return err
		}
		if agent.GetString("config") == bundle {
			return nil
		}
		agent.Set("config", bundle)
		return app.Save(agent)
	}

	// ------------------------------------------------------------
	// ⚓ HOOKS
	// ------------------------------------------------------------

	// Trigger assembly on Agents change (Modify record BEFORE save to avoid extra writes/recursion)
	app.OnRecordCreateRequest("ai_agents").BindFunc(func(e *core.RecordRequestEvent) error {
		bundle, err := getAgentBundle(e.Record)
		if err == nil {
			e.Record.Set("config", bundle)
		}
		return e.Next()
	})

	app.OnRecordUpdateRequest("ai_agents").BindFunc(func(e *core.RecordRequestEvent) error {
		bundle, err := getAgentBundle(e.Record)
		if err == nil {
			e.Record.Set("config", bundle)
		}
		return e.Next()
	})

	// For rules, prompts, and models, we find the affected agents and re-assemble them (REQUIRES Save)
	app.OnRecordAfterUpdateSuccess("ai_permission_rules", "ai_prompts", "ai_models").BindFunc(func(e *core.RecordEvent) error {
		collection := e.Record.Collection().Name
		
		if collection == "ai_permission_rules" {
			agentId := e.Record.GetString("agent")
			if agentId != "" {
				agent, _ := app.FindRecordById("ai_agents", agentId)
				if agent != nil { updateAgentConfig(agent) }
			}
		}
		
		if collection == "ai_prompts" {
			agents, _ := app.FindRecordsByFilter("ai_agents", "prompt = {:id}", "created", 100, 0, map[string]any{"id": e.Record.Id})
			for _, a := range agents { updateAgentConfig(a) }
		}

		if collection == "ai_models" {
			agents, _ := app.FindRecordsByFilter("ai_agents", "model = {:id}", "created", 100, 0, map[string]any{"id": e.Record.Id})
			for _, a := range agents { updateAgentConfig(a) }
		}

		return e.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
