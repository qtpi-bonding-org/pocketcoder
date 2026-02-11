package main

import (
	"log"
	"os"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/api"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/filesystem"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-automaton/pocketcoder/backend/pkg/relay"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func main() {
	app := pocketbase.New()

	// 1. Register Migrations
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate: true,
	})

	// 2. Register Global Sovereign Hooks
	hooks.RegisterGlobalTimestamps(app)
	hooks.RegisterPermissionHooks(app)
	hooks.RegisterAgentHooks(app)

	// 3. Main Application Boot & API Registration
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		log.Printf("🚀 Starting PocketCoder Sovereign Backend...")

		// A. Initialize & Start Relay Service
		openCodeURL := os.Getenv("OPENCODE_URL")
		if openCodeURL == "" {
			openCodeURL = "http://opencode:3000"
		}
		relaySvc := relay.NewRelayService(app, openCodeURL)
		relaySvc.Start()

		// B. Register Custom API Endpoints
		api.RegisterPermissionApi(app, e)
		api.RegisterSSHApi(app, e)
		filesystem.RegisterArtifactApi(app, e)

		return e.Next()
	})

	// 4. Launch PocketBase
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
