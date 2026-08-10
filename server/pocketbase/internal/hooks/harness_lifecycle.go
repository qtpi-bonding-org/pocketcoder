package hooks

import (
	"context"
	"log"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/dockerapi"
)

type harnessRemover interface {
	Remove(context.Context, string) error
}

// RegisterHarnessLifecycle installs the owner for managed harness cleanup.
// Stopped and failed containers are retained briefly for diagnostics, then
// their Docker container and harness_instances row are reclaimed. A running
// instance is never removed by this job; last_used is refreshed by profile
// resolution and is the future extension point for idle-running reaping.
func RegisterHarnessLifecycle(app core.App, client harnessRemover) {
	cleanup := func() {
		rows, err := app.FindRecordsByFilter("harness_instances", "managed = true", "", 0, 0)
		if err != nil {
			log.Printf("[HarnessLifecycle] list failed: %v", err)
			return
		}
		cutoff := time.Now().Add(-30 * time.Minute)
		for _, row := range rows {
			if row.GetString("status") != "stopped" && row.GetString("status") != "error" {
				continue
			}
			last := row.GetString("last_used")
			if last != "" {
				when, err := time.Parse(time.RFC3339, last)
				if err == nil && when.After(cutoff) {
					continue
				}
			}
			ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
			err := client.Remove(ctx, row.GetString("container_name"))
			cancel()
			if err != nil && err != dockerapi.ErrContainerNotFound {
				log.Printf("[HarnessLifecycle] remove %s failed: %v", row.GetString("container_name"), err)
				continue
			}
			if err := app.Delete(row); err != nil {
				log.Printf("[HarnessLifecycle] delete instance %s failed: %v", row.Id, err)
			}
		}
	}
	if err := app.Cron().Add("harness-lifecycle", "*/10 * * * *", cleanup); err != nil {
		log.Printf("[HarnessLifecycle] register failed: %v", err)
	}
}
