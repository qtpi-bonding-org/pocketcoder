package coordinator

import (
	"context"
	"testing"
	"time"

	acpsdk "github.com/coder/acp-go-sdk"
)

// waitForPendingElicitation returns the id of the first pending elicitation
// that matches chatID.
func (c *Coordinator) waitForPendingElicitation(t *testing.T, chatID string) string {
	t.Helper()
	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		var id string
		c.mu.Lock()
		for k, v := range c.elicits {
			if v.chatID == chatID {
				id = k
				break
			}
		}
		c.mu.Unlock()
		if id != "" {
			return id
		}
		time.Sleep(5 * time.Millisecond)
	}
	t.Fatalf("no pending elicitation for %q", chatID)
	return ""
}

func TestElicitationResolveResumes(t *testing.T) {
	f := newFakeConn()
	f.emitElicitation = true
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "need input",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context, string) error { return nil })
	id := c.waitForPendingElicitation(t, "A")
	if err := c.ResolveElicitation("A", id, acpsdk.UnstableCreateElicitationResponse{
		Accept: &acpsdk.UnstableCreateElicitationAccept{},
	}); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
	f.mu.Lock()
	resolved := f.elicitationResolved
	f.mu.Unlock()
	if !resolved {
		t.Fatal("elicitation handler must return after ResolveElicitation")
	}
}

func TestElicitationTimeoutResolvesCancel(t *testing.T) {
	f := newFakeConn()
	f.emitElicitation = true
	clk := NewFakeClock(time.Unix(0, 0))
	c := testCoordinatorWithConn(t, f, clk)
	c.StartPrompt("A", "need input",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context, string) error { return nil })
	c.waitForPendingElicitation(t, "A")
	clk.Advance(6 * time.Minute)
	c.waitRunDone(t, "A")
}

func TestSetModeDispatchesToConn(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{})
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context, string) error { return nil })
	f.waitForPrompt(t)
	if err := c.SetMode(context.Background(), "A", "plan"); err != nil {
		t.Fatal(err)
	}
	f.mu.Lock()
	got := f.lastMode
	f.mu.Unlock()
	if got != "plan" {
		t.Fatalf("SetMode dispatched %q, want plan", got)
	}
	close(f.blockPrompt)
	c.waitRunDone(t, "A")
}
