package main

import (
	"encoding/json"
	"log"
	"os"

	"regexp"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"
	"github.com/pocketbase/pocketbase/tools/subscriptions"
	"golang.org/x/sync/errgroup"

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

	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate: true, // auto-run migrations on serve? No, this enables command.
	})



	// ------------------------------------------------------------
	// 📡 SOVEREIGN AUTHORITY (Permission Firewall)
	// PocketBase decides what is allowed.
	// ------------------------------------------------------------
	app.OnRecordCreate("permissions").Bind(&hook.Handler[*core.RecordEvent]{
		Func: func(e *core.RecordEvent) error {
			permission := e.Record.GetString("permission")

			// AUTHORITY LOGIC:
			// Read/Write (edit) are authorized automatically.
			// Bash execution is gated (Draft) unless it exists in 'whitelists'.
			isWhitelisted := false
			if permission == "bash" {
				// We need to check if the command being requested exists in the whitelist.
				// OpenCode metadata often contains the command being run.
				metadata, ok := e.Record.Get("metadata").(map[string]any)
				if ok {

				if cmd, ok := metadata["command"].(string); ok {
					// Check whitelists. Whitelists are connected to commands.
					// 1. Find the command record by string (or hash match)
					cmdRec, _ := app.FindFirstRecordByFilter("commands", "command = {:cmd}", map[string]any{"cmd": cmd})
					if cmdRec != nil {
						// 2. Check if an active whitelist entry exists for this command
						wlRec, _ := app.FindFirstRecordByFilter("whitelists", "command = {:id} && active = true", map[string]any{"id": cmdRec.Id})
						if wlRec != nil {
							isWhitelisted = true
						}
					}
				}
				}
			}

			if permission != "bash" || isWhitelisted {
				log.Printf("🛡️ [PocketCoder Authority] Auto-authorizing: %s (Whitelisted: %v)", permission, isWhitelisted)
				e.Record.Set("status", "authorized")
			} else {
				log.Printf("🛡️ [PocketCoder Authority] Gating execution: %s", permission)
				e.Record.Set("status", "draft")
			}

			return e.Next()
		},
	})


	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(e *core.ServeEvent) error {
			// Serve static files
			e.Router.GET("/{path...}", apis.Static(os.DirFS("./pb_public"), false))

			// ------------------------------------------------------------
			// ⚡ EPHEMERAL STREAM (Ghost Stream)
			// ------------------------------------------------------------
			// This endpoint allows the Agent to pipe high-volume logs directly
			// to connected clients (Flutter) without saving to the DB.
			e.Router.POST("/api/pocketcoder/stream", func(c *core.RequestEvent) error {
				// 1. Security Check: Only Agent or Admin can broadcast
				authRec := c.Auth
				if authRec == nil || (authRec.GetString("role") != "agent" && authRec.GetString("role") != "admin") {
					return apis.NewForbiddenError("Only agents can broadcast streams", nil)
				}

				// 2. Parse Payload
				var payload struct {
					Topic string `json:"topic"`
					Data  any    `json:"data"`
				}
				if err := c.BindBody(&payload); err != nil {
					return apis.NewBadRequestError("Invalid payload", err)
				}

				// 3. Broadcast to Subscribers
				dataBytes, err := json.Marshal(payload.Data)
				if err != nil {
					return err
				}

				message := subscriptions.Message{
					Name: payload.Topic,
					Data: dataBytes,
				}

				// app.SubscriptionsBroker().ChunkedClients(300) returns chunks of clients
				// We iterate and send to those who subscribed to this topic.
				chunks := c.App.SubscriptionsBroker().ChunkedClients(300)
				group := new(errgroup.Group)

				for _, chunk := range chunks {
					group.Go(func() error {
						for _, client := range chunk {
							if !client.HasSubscription(payload.Topic) {
								continue
							}
							client.Send(message)
						}
						return nil
					})
				}

				if err := group.Wait(); err != nil {
					return err
				}

				return c.JSON(200, map[string]string{"status": "ok"})
			})

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
