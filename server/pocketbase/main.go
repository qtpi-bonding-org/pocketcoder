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
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/migratecmd"

	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/agent/coordinator"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/harnessaccount"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/hooks"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/modelcatalog"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operationapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/releaseidentity"
	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func main() {
	app := pocketbase.New()

	// PocketBase ships with a built-in rate limiter, but leaves it disabled in
	// its default settings. Enable conservative production defaults on fresh
	// deployments unless rate limiting is already configured. This
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

	// coord is nil until operationapi.Register runs inside OnServe below, and
	// stays nil if the agent profile isn't configured. Hooks registered
	// before OnServe (goose config, MCP) capture this getter and dereference
	// it whenever they fire. For real traffic that's always after OnServe —
	// but a from-scratch database's migration-time seed writes to
	// agent_profiles/permission_mode_tools (during app.Bootstrap(), before OnServe)
	// can also fire it once with coord still nil; every getter() caller
	// nil-checks and skips, so this is a harmless no-op, not a bug.
	var coord coordinator.AgentRuntime
	coordGetter := func() coordinator.AgentRuntime { return coord }

	migratecmd.MustRegister(app, app.RootCmd, migratecmd.Config{
		Automigrate: true,
	})

	hooks.RegisterGlobalTimestamps(app)
	hooks.RegisterNotificationHooks(app)
	hooks.RegisterLiveActivityHooks(app)
	hooks.RegisterChatsHarnessPinHook(app)
	harnessaccount.RegisterHooks(app)

	// 3. Register MCP Hooks (config rendering + gateway restart)
	// The interface receives MCP status updates via PocketBase realtime subscriptions.
	hooks.RegisterMcpHooks(app)

	hooks.RegisterAgentFileHooks(app)
	hooks.RegisterGitSSHHooks(app)
	modelcatalog.RegisterCredentialHooks(app, http.DefaultClient, modelcatalog.DefaultCatalogURL)

	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		app.Logger().Info("🚀 Starting PocketCoder Sovereign Backend...")
		release := os.Getenv("POCKETCODER_RELEASE")
		if release != "" && release != "development" {
			catalogPath := os.Getenv("POCKETCODER_HARNESS_CATALOG")
			if catalogPath == "" {
				catalogPath = "/etc/pocketcoder/harnesses.json"
			}
			if err := releaseidentity.SyncHarnessImages(app, catalogPath, release); err != nil {
				return fmt.Errorf("sync release harness catalog: %w", err)
			}
		}

		var err error
		coord, err = operationapi.Register(app, e, coordGetter)
		if err != nil {
			app.Logger().Warn("agent API not configured; agent profile disabled", "error", err)
		}

		// A2. Keep the providers/models/harness_models catalog in sync with
		// models.dev (the same source Goose and OpenCode themselves build
		// their catalogs from), so API key entry and model selection reflect
		// real current data instead of a hand-seeded snapshot.
		modelcatalog.RegisterSync(app)

		// F. Harness instance status watcher: subscribes to the Docker
		// event stream and reconciles harness_instances.status against
		// real container state for the lifetime of the app. Tied to a
		// cancel context released on OnTerminate, and — like
		// the agent coordinator's shutdown hook above — the OnTerminate
		// handler blocks (bounded by a timeout) until the watcher's own
		// goroutine confirms it actually stopped, so PocketBase doesn't
		// tear down the DB out from under an in-flight status Save.
		watcherCtx, cancelWatcher := context.WithCancel(context.Background())
		watcherDone := hooks.StartHarnessWatcher(watcherCtx, app, dockerapi.New())
		hooks.RegisterHarnessLifecycle(app, dockerapi.New())
		app.OnTerminate().BindFunc(func(_ *core.TerminateEvent) error {
			cancelWatcher()
			select {
			case <-watcherDone:
			case <-time.After(5 * time.Second):
				log.Println("[HarnessWatcher] timed out waiting for shutdown")
			}
			return nil
		})

		app.Logger().Info("✅ PocketCoder backend restarted and ready")
		return e.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
