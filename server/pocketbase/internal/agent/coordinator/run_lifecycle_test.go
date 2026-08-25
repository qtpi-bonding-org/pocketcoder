package coordinator

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

// These tests are the direct regression coverage for the bug two
// independent reviews caught: the pre-existing `finished OnRunFinished`
// callback is NOT a reliable "run ended" signal (its guard skips
// cancellation and every early-failure return in runLoop). WithOnRunEnded
// must fire exactly once on every path out of runLoop, unlike `finished`.

func TestOnRunEndedFiresCompletedOnNormalFinish(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var mu sync.Mutex
	var calls int
	var last RunOutcome
	onEnded := func(_ context.Context, chatID string, outcome RunOutcome) {
		mu.Lock()
		defer mu.Unlock()
		calls++
		last = outcome
		if chatID != "A" {
			t.Errorf("onRunEnded chatID=%q, want %q", chatID, "A")
		}
	}
	if _, err := c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil,
		WithOnRunEnded(onEnded)); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	mu.Lock()
	defer mu.Unlock()
	if calls != 1 {
		t.Fatalf("onRunEnded calls=%d, want 1", calls)
	}
	if last != RunCompleted {
		t.Fatalf("onRunEnded outcome=%q, want %q", last, RunCompleted)
	}
}

func TestOnRunEndedFiresCancelledOnCancel(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{})
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var mu sync.Mutex
	var calls int
	var last RunOutcome
	onEnded := func(_ context.Context, _ string, outcome RunOutcome) {
		mu.Lock()
		defer mu.Unlock()
		calls++
		last = outcome
	}
	// finished (the pre-existing callback) is asserted separately
	// (TestOnRunFinishedNotInvokedOnCancel) as NOT firing here -- the whole
	// point of onRunEnded is that it fires anyway.
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil,
		WithOnRunEnded(onEnded))
	f.waitForPrompt(t)
	if err := c.Cancel(context.Background(), "A"); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	mu.Lock()
	defer mu.Unlock()
	if calls != 1 {
		t.Fatalf("onRunEnded calls=%d on cancel, want 1", calls)
	}
	if last != RunCancelled {
		t.Fatalf("onRunEnded outcome=%q on cancel, want %q", last, RunCancelled)
	}
}

// TestOnRunEndedFiresFailedOnEarlyFailure covers the early-return paths
// inside runLoop (session resolution, profile build, establishSession,
// applier.Apply) that the pre-existing `finished` callback always skips.
// resolve() failing is the earliest such path.
func TestOnRunEndedFiresFailedOnEarlyFailure(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	var mu sync.Mutex
	var calls int
	var last RunOutcome
	onEnded := func(_ context.Context, _ string, outcome RunOutcome) {
		mu.Lock()
		defer mu.Unlock()
		calls++
		last = outcome
	}
	if _, err := c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "", errors.New("resolve failed") },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil,
		WithOnRunEnded(onEnded)); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	mu.Lock()
	defer mu.Unlock()
	if calls != 1 {
		t.Fatalf("onRunEnded calls=%d on early failure, want 1", calls)
	}
	if last != RunFailed {
		t.Fatalf("onRunEnded outcome=%q on early failure, want %q", last, RunFailed)
	}
}

func TestWithOnRunEndedIsOptional(t *testing.T) {
	f := newFakeConn()
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	// No WithOnRunEnded passed at all -- must not panic (nil onRunEnded is
	// the default for every existing StartPrompt call site).
	if _, err := c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil },
		nil); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
}
