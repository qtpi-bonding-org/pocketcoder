package main

import (
	"log"
	"os"

	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func matchWildcard(str string, pattern string) bool {
	// 1. Escape special regex characters except for our wildcards
	escaped := regexp.QuoteMeta(pattern)
	// 2. Convert glob-style '*' and '?' to regex
	escaped = strings.ReplaceAll(escaped, "\\*", ".*")
	escaped = strings.ReplaceAll(escaped, "\\?", ".")

	// 3. Handle trailing space + wildcard special case (match base command too)
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

	// ------------------------------------------------------------
	// 📡 INTENT LOGGING & AUTO-AUTHORIZATION
	// ------------------------------------------------------------
	app.OnRecordCreate("intents").Bind(&hook.Handler[*core.RecordEvent]{
		Func: func(e *core.RecordEvent) error {
			intentType := e.Record.GetString("type")
			message := e.Record.GetString("message")

			log.Printf("📡 [Gatekeeper] New Intent: %s (Type: %s)", e.Record.Id, intentType)

			// 1. Fetch all active whitelists for this tool type
			whitelists, err := app.FindRecordsByFilter(
				"whitelists",
				"active = true && type = {:type}",
				"-created",
				100,
				0,
				map[string]any{"type": intentType},
			)

			if err == nil {
				for _, w := range whitelists {
					pattern := w.GetString("pattern")
					if matchWildcard(message, pattern) {
						log.Printf("✅ [Gatekeeper] Auto-Authorizing Intent %s (Matched: %s)", e.Record.Id, pattern)
						e.Record.Set("status", "authorized")
						e.Record.Set("reasoning", "Auto-authorized by whitelist: " + pattern)
						break
					}
				}
			}

			return e.Next()
		},
	})

	app.OnRecordUpdate("intents").Bind(&hook.Handler[*core.RecordEvent]{
		Func: func(e *core.RecordEvent) error {
			status := e.Record.GetString("status")
			log.Printf("🔄 [Gatekeeper] Intent Updated: %s -> %s", e.Record.Id, status)
			return e.Next()
		},
	})

	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			// Serve static files
			e.Router.GET("/{path...}", apis.Static(os.DirFS("./pb_public"), false))

			// ------------------------------------------------------------
			// 🛡️ RUNTIME SEEDING (User Account Setup)
			// ------------------------------------------------------------
			users, _ := app.FindCollectionByNameOrId("users")
			if users == nil {
				return nil
			}

			// Ensure Admin exists
			adminEmail := os.Getenv("ADMIN_EMAIL")
			if adminEmail != "" {
				existing, _ := app.FindFirstRecordByFilter("users", "email = {:email}", map[string]any{"email": adminEmail})
				if existing == nil {
					log.Printf("👑 [PocketCoder Core] Seeding Admin: %s", adminEmail)
					admin := core.NewRecord(users)
					admin.Set("email", adminEmail)
					admin.Set("password", os.Getenv("ADMIN_PASSWORD"))
					admin.Set("role", "admin")
					admin.SetVerified(true)
					if err := app.Save(admin); err != nil {
						log.Printf("❌ Failed to seed admin: %v", err)
					}

					// Also ensure a Superuser exists for dashboard access
					// This is separate from the 'users' collection record.
					superusers, _ := app.FindCollectionByNameOrId("_superusers")
					if superusers != nil {
						super, _ := app.FindFirstRecordByFilter("_superusers", "email = {:email}", map[string]any{"email": adminEmail})
						if super == nil {
							newSuper := core.NewRecord(superusers)
							newSuper.Set("email", adminEmail)
							newSuper.Set("password", os.Getenv("ADMIN_PASSWORD"))
							if err := app.Save(newSuper); err != nil {
								log.Printf("❌ Failed to seed superuser: %v", err)
							}
						}
					}
				}
			}

			// Ensure Agent exists
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
					if err := app.Save(agent); err != nil {
						log.Printf("❌ Failed to seed agent: %v", err)
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
