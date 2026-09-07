package hooks

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/gitssh"
)

type recordingReconciler struct {
	mu   sync.Mutex
	seen []string
}

func (r *recordingReconciler) ReconcileUser(_ context.Context, _ core.App, userID string) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.seen = append(r.seen, userID)
	return nil
}

func (r *recordingReconciler) snapshot() []string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return append([]string(nil), r.seen...)
}

func TestGitSSHReconcileLoopDrainsEnqueuedUsers(t *testing.T) {
	app := testApp(t)
	queue := gitssh.NewQueue()
	rec := &recordingReconciler{}

	ctx, cancel := context.WithCancel(context.Background())
	done := StartGitSSHReconcileLoop(ctx, app, queue, rec, 20*time.Millisecond)
	defer func() {
		cancel()
		<-done
	}()

	queue.Enqueue("user-a")
	queue.Enqueue("user-b")

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		seen := rec.snapshot()
		if containsBoth(seen, "user-a", "user-b") {
			return
		}
		time.Sleep(10 * time.Millisecond)
	}
	t.Fatalf("reconciler never saw both enqueued users, saw %v", rec.snapshot())
}

func containsBoth(xs []string, a, b string) bool {
	var gotA, gotB bool
	for _, x := range xs {
		if x == a {
			gotA = true
		}
		if x == b {
			gotB = true
		}
	}
	return gotA && gotB
}

func TestGitSSHReconcileLoopStopsWhenContextCancelled(t *testing.T) {
	app := testApp(t)
	queue := gitssh.NewQueue()
	rec := &recordingReconciler{}

	ctx, cancel := context.WithCancel(context.Background())
	done := StartGitSSHReconcileLoop(ctx, app, queue, rec, 10*time.Millisecond)
	cancel()

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("reconcile loop did not stop after context cancellation")
	}
}
