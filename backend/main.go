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
