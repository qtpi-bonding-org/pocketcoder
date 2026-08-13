package gitssh

import (
	"context"
	"sync"
)

// Materializer is intentionally narrow: the reconciler owns desired-state
// decisions while the Docker-backed implementation owns secret-volume writes.
type Materializer interface {
	Materialize(context.Context, string, Manifest) error
}

type Manifest struct {
	Generation string
	Config     []byte
	KnownHosts []byte
	Keys       map[string][]byte
}

// Queue coalesces rapid CRUD notifications by full PocketBase user id.
type Queue struct {
	mu      sync.Mutex
	pending map[string]struct{}
}

func NewQueue() *Queue { return &Queue{pending: map[string]struct{}{}} }

func (q *Queue) Enqueue(userID string) {
	if userID == "" {
		return
	}
	q.mu.Lock()
	q.pending[userID] = struct{}{}
	q.mu.Unlock()
}

func (q *Queue) Drain() []string {
	q.mu.Lock()
	defer q.mu.Unlock()
	ids := make([]string, 0, len(q.pending))
	for id := range q.pending {
		ids = append(ids, id)
		delete(q.pending, id)
	}
	return ids
}
