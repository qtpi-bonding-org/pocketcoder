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

// @pocketcoder-core: Main Orchestrator. Registers hooks, starts the relay, and boots PocketBase.
// @pocketcoder-core: Sovereign Relay. The orchestration layer that syncs the agent runtime with the Sandbox.
package main

import (
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/api"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/filesystem"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/provisioning"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func main() {
	app := pocketbase.New()

	// coord is nil until RegisterAgentApi runs inside OnServe below, and
	// stays nil if the agent profile isn't configured. Hooks registered
	// before OnServe (goose config, MCP) capture this getter and dereference
	// it whenever they fire. For real traffic that's always after OnServe —
	// but a from-scratch database's migration-time seed writes to
	// poco_configs/tool_permissions (during app.Bootstrap(), before OnServe)
	// can also fire it once with coord still nil; every getter() caller
	// nil-checks and skips, so this is a harmless no-op, not a bug.
	var coord *coordinator.Coordinator
	coordGetter := func() *coordinator.Coordinator { return coord }

	// 1. Register Migrations
	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate: true,
	})

	// 2. Register Global Sovereign Hooks
	hooks.RegisterGlobalTimestamps(app)
	hooks.RegisterSopHooks(app)
	hooks.RegisterNotificationHooks(app)

	// 3. Register MCP Hooks (config rendering + gateway restart)
	// The interface receives MCP status updates via PocketBase realtime subscriptions.
	hooks.RegisterMcpHooks(app)

	// 3b. Register Goose Config Hooks (config.yaml + keys.env render + goose
	// restart + live tool-permission delivery)
	hooks.RegisterGooseConfigHooks(app, coordGetter)

	// 3c. Register Cron Hooks (scheduled agent tasks)
	hooks.RegisterCronHooks(app)

	// 4. Main Application Boot & API Registration
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		app.Logger().Info("🚀 Starting PocketCoder Sovereign Backend...")

		// A. Provision SOPs from filesystem
		provisioning.ProvisionSops(app)

		// B. Register Custom API Endpoints
		api.RegisterSSHApi(app, e)
		api.RegisterMcpApi(app, e)
		api.RegisterProxyApi(app, e)
		api.RegisterLogsApi(app, e)
		api.RegisterCronApi(app, e)
		var err error
		coord, err = api.RegisterAgentApi(app, e)
		if err != nil {
			app.Logger().Warn("agent API not configured; agent profile disabled", "error", err)
		}
		filesystem.RegisterFilesApi(app, e)
		hooks.RegisterPushApi(app, e)

		// C. One-time MCP gateway extension registration (idempotent,
		// retried with backoff — see RegisterMcpGatewayExtension).
		go hooks.RegisterMcpGatewayExtension(coordGetter)

		// D. Skills API (pure ACP passthrough, no PocketBase storage).
		api.RegisterSkillsApi(app, e, coordGetter)

		return e.Next()
	})

	// 5. Launch PocketBase
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
