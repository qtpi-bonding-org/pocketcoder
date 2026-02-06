package main

import (
	"log"
	"os"

	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/pocketbase/pocketbase/tools/hook"
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
	app.OnRecordCreate("permissions").Bind(&hook.Handler[*core.RecordEvent]{
		Func: func(e *core.RecordEvent) error {
			permission := e.Record.GetString("permission")

			// Generate Authority Challenge
			e.Record.Set("challenge", uuid.NewString())

			// Whitelist Logic
			isWhitelisted := false
			if permission == "bash" {
				metadata, ok := e.Record.Get("metadata").(map[string]any)
				if ok {
					if cmd, ok := metadata["command"].(string); ok {
						cmdRec, _ := app.FindFirstRecordByFilter("commands", "command = {:cmd}", map[string]any{"cmd": cmd})
						if cmdRec != nil {
							wlRec, _ := app.FindFirstRecordByFilter("whitelists", "command = {:id} && active = true", map[string]any{"id": cmdRec.Id})
							if wlRec != nil {
								isWhitelisted = true
							}
						}
					}
				}
			}

			if permission != "bash" || isWhitelisted {
				log.Printf("🛡️ [Gatekeeper] Auto-authorizing: %s (Whitelisted: %v)", permission, isWhitelisted)
				e.Record.Set("status", "authorized")
			} else {
				log.Printf("🛡️ [Gatekeeper] Gating execution: %s. Challenge generated.", permission)
				e.Record.Set("status", "draft")
			}

			return e.Next()
		},
	})


	
	// ------------------------------------------------------------
	// 🛡️ RUNTIME SEEDING
	// ------------------------------------------------------------
	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			// A. Seed Superuser (Dashboard Admin)
			superusers, _ := app.FindCollectionByNameOrId("_superusers")
			if superusers != nil {
				suEmail := os.Getenv("POCKETBASE_SUPERUSER_EMAIL")
				if suEmail != "" {
					existing, _ := app.FindFirstRecordByFilter("_superusers", "email = {:email}", map[string]any{"email": suEmail})
					if existing == nil {
						log.Printf("🌌 [PocketCoder Core] Seeding Superuser: %s", suEmail)
						su := core.NewRecord(superusers)
						su.Set("email", suEmail)
						su.Set("password", os.Getenv("POCKETBASE_SUPERUSER_PASSWORD"))
						app.Save(su)
					}
				}
			}

			// B. Seed App Users
			users, _ := app.FindCollectionByNameOrId("users")
			if users != nil {
				// Ensure Admin
				adminEmail := os.Getenv("POCKETBASE_USER_EMAIL")
				if adminEmail != "" {
					existing, _ := app.FindFirstRecordByFilter("users", "email = {:email}", map[string]any{"email": adminEmail})
					if existing == nil {
						log.Printf("👑 [PocketCoder Core] Seeding Admin: %s", adminEmail)
						admin := core.NewRecord(users)
						admin.Set("email", adminEmail)
						admin.Set("password", os.Getenv("POCKETBASE_USER_PASSWORD"))
						admin.Set("role", "admin")
						admin.SetVerified(true)
						app.Save(admin)
					}
				}
				
				// Ensure Agent
				agentEmail := os.Getenv("AGENT_EMAIL")
				if agentEmail != "" {
					existing, _ := app.FindFirstRecordByFilter("users", "email = {:email}", map[string]any{"email": agentEmail})
					if existing == nil {
						log.Printf("🤖 [PocketCoder Core] Seeding Agent: %s", agentEmail)
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
		},
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
