package gitssh

import "testing"

func TestQueueCoalescesUserWrites(t *testing.T) {
	q := NewQueue()
	q.Enqueue("u1")
	q.Enqueue("u1")
	q.Enqueue("u2")
	if got := len(q.Drain()); got != 2 {
		t.Fatalf("drained %d users", got)
	}
	if got := q.Drain(); len(got) != 0 {
		t.Fatalf("queue not empty: %v", got)
	}
}
