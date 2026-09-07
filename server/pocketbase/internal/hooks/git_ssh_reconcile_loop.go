package hooks

import (
	"context"
	"log"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/gitssh"
)

type gitSSHReconciler interface {
	ReconcileUser(ctx context.Context, app core.App, userID string) error
}

// A user's reconcile error never blocks another user or the next tick --
// their next enqueue simply retries.
func StartGitSSHReconcileLoop(ctx context.Context, app core.App, queue *gitssh.Queue, reconciler gitSSHReconciler, interval time.Duration) <-chan struct{} {
	done := make(chan struct{})
	go func() {
		defer close(done)
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				for _, userID := range queue.Drain() {
					if err := reconciler.ReconcileUser(ctx, app, userID); err != nil {
						log.Printf("[GitSSH] reconcile user %s: %v", userID, err)
					}
				}
			}
		}
	}()
	return done
}
