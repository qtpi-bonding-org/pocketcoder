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

package hooks

import (
	"context"
	"log"
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
)

// eventSource is the subset of *dockerapi.Client the watcher depends on,
// narrowed so tests can substitute a fake.
type eventSource interface {
	Events(ctx context.Context) (<-chan dockerapi.Event, error)
	ListAll(ctx context.Context) ([]dockerapi.ContainerSummary, error)
}

// StartHarnessWatcher subscribes to the Docker event stream BEFORE running
// the startup reconciliation sweep — deliberately, so a container that
// changes state in the gap between the sweep's snapshot and the
// subscription taking effect isn't missed (§5.3). It keeps
// harness_instances.status in sync with real container state for the
// lifetime of ctx and never touches a managed = false row (the
// compose-managed default Goose instance).
//
// It returns a "done" channel that is closed once the watcher's loop has
// fully exited (after observing ctx.Done() or the events channel closing),
// so a caller tearing down the app on shutdown can wait for any in-flight
// applyStatus/reconcile Save call to finish before the DB is torn down —
// mirroring how internal/api/agent.go's OnTerminate handler blocks
// (bounded by a timeout) until its own goroutine confirms shutdown.
func StartHarnessWatcher(ctx context.Context, app core.App, client eventSource) <-chan struct{} {
	done := make(chan struct{})
	go func() {
		defer close(done)

		events, err := client.Events(ctx)
		if err != nil {
			log.Printf("[HarnessWatcher] failed to subscribe to docker events: %v", err)
			return
		}

		reconcile(ctx, app, client)

		for {
			select {
			case ev, ok := <-events:
				if !ok {
					return
				}
				if ev.Type != "" && ev.Type != "container" {
					continue
				}
				applyStatus(app, ev.ContainerName, dockerEventToStatus(ev.Action))
			case <-ctx.Done():
				return
			}
		}
	}()
	return done
}

func dockerEventToStatus(action string) string {
	switch action {
	case "start":
		return "running"
	case "die", "stop", "kill", "destroy":
		return "stopped"
	default:
		return ""
	}
}

func applyStatus(app core.App, containerName, status string) {
	if status == "" {
		return
	}
	rec, err := app.FindFirstRecordByFilter("harness_instances", "container_name = {:n}", map[string]any{"n": containerName})
	if err != nil || rec == nil {
		return
	}
	if !rec.GetBool("managed") {
		return // never touch the compose-managed default Goose row
	}
	rec.Set("status", status)
	if err := app.Save(rec); err != nil {
		log.Printf("[HarnessWatcher] failed to save status for %s: %v", containerName, err)
	}
}

func reconcile(ctx context.Context, app core.App, client eventSource) {
	all, err := client.ListAll(ctx)
	if err != nil {
		log.Printf("[HarnessWatcher] reconciliation sweep failed: %v", err)
		return
	}
	running := map[string]bool{}
	for _, c := range all {
		for _, n := range c.Names {
			running[strings.TrimPrefix(n, "/")] = c.State == "running"
		}
	}
	instances, err := app.FindRecordsByFilter("harness_instances", "managed = true", "", 0, 0)
	if err != nil {
		return
	}
	for _, inst := range instances {
		name := inst.GetString("container_name")
		wantRunning := running[name]
		status := "stopped"
		if wantRunning {
			status = "running"
		}
		if inst.GetString("status") != status {
			inst.Set("status", status)
			if err := app.Save(inst); err != nil {
				log.Printf("[HarnessWatcher] failed to save status for %s: %v", name, err)
			}
		}
	}
}
