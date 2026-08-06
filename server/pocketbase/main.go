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
	"context"
	"log"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/qtpi-automaton/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/api"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/filesystem"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/hooks"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func main() {
	app := pocketbase.New()

	// PocketBase ships with a built-in rate limiter, but leaves it disabled in
	// its default settings. Enable conservative production defaults on fresh
	// and legacy deployments unless rate limiting is already configured. This
	// protects public auth/API endpoints without requiring a custom Caddy build.
	app.OnBootstrap().BindFunc(func(e *core.BootstrapEvent) error {
		if err := e.Next(); err != nil {
			return err
		}

		settings := app.Settings()
		if settings.RateLimits.Enabled {
			return nil
		}

		settings.RateLimits.Enabled = true
		settings.RateLimits.Rules = []core.RateLimitRule{
			{Label: "*:auth", MaxRequests: 10, Duration: 60},
			{Label: "*:create", MaxRequests: 20, Duration: 5},
			{Label: "/api/batch", MaxRequests: 3, Duration: 1},
			{Label: "/api/", MaxRequests: 300, Duration: 10},
		}
		return app.Save(settings)
	})

	// coord is nil until RegisterAgentApi runs inside OnServe below, and
	// stays nil if the agent profile isn't configured. Hooks registered
	// before OnServe (goose config, MCP) capture this getter and dereference
	// it whenever they fire. For real traffic that's always after OnServe —
	// but a from-scratch database's migration-time seed writes to
	// agent_profiles/permission_mode_tools (during app.Bootstrap(), before OnServe)
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
	hooks.RegisterNotificationHooks(app)
	hooks.RegisterChatsHarnessPinHook(app)

	// 3. Register MCP Hooks (config rendering + gateway restart)
	// The interface receives MCP status updates via PocketBase realtime subscriptions.
	hooks.RegisterMcpHooks(app)

	// 3b. Register Goose Config Hooks (config.yaml + keys.env render + goose
	// restart + live tool-permission delivery)
	hooks.RegisterGooseConfigHooks(app)
	hooks.RegisterAgentFileHooks(app)

	// 3c. Register cognee Config Hooks (cognee.env render + cognee restart)
	hooks.RegisterCogneeConfigHooks(app)

	// 3d. Register Schedule Import Hooks (Goose-native scheduler → chat feed)
	hooks.RegisterScheduleImportHooks(app, coordGetter)

	// 4. Main Application Boot & API Registration
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		app.Logger().Info("🚀 Starting PocketCoder Sovereign Backend...")

		// A. Register Custom API Endpoints
		api.RegisterSSHApi(app, e)
		api.RegisterMcpApi(app, e)
		api.RegisterMcpOAuthApi(app, e)
		api.RegisterProxyApi(app, e)
		api.RegisterLogsApi(app, e)
		api.RegisterOllamaApi(app, e)
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

		// C2. One-time cognee extension registration (idempotent, retried
		// with backoff — see RegisterCogneeExtension).
		go hooks.RegisterCogneeExtension(coordGetter)

		// D. Skills API (pure ACP passthrough, no PocketBase storage).
		api.RegisterSkillsApi(app, e, coordGetter)

		// E. Harness auth API (account/API-key mode selection + auth-helper lifecycle).
		api.RegisterHarnessAuthApi(app, e)

		// F. Scheduler API (per-user CRUD over Goose's schedules, backed by
		// schedule_owners).
		api.RegisterSchedulesApi(app, e, coordGetter)

		// F. Harness instance status watcher: subscribes to the Docker
		// event stream and reconciles harness_instances.status against
		// real container state for the lifetime of the app. Tied to a
		// cancel context released on OnTerminate, and — like
		// RegisterAgentApi's coordinator shutdown above — the OnTerminate
		// handler blocks (bounded by a timeout) until the watcher's own
		// goroutine confirms it actually stopped, so PocketBase doesn't
		// tear down the DB out from under an in-flight status Save.
		watcherCtx, cancelWatcher := context.WithCancel(context.Background())
		watcherDone := hooks.StartHarnessWatcher(watcherCtx, app, dockerapi.New())
		app.OnTerminate().BindFunc(func(_ *core.TerminateEvent) error {
			cancelWatcher()
			select {
			case <-watcherDone:
			case <-time.After(5 * time.Second):
				log.Println("[HarnessWatcher] timed out waiting for shutdown")
			}
			return nil
		})

		return e.Next()
	})

	// 5. Launch PocketBase
	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
