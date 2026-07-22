package coordinator

import (
	"context"
	"encoding/json"
	"strings"
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
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
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
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil })
	c.waitForPendingElicitation(t, "A")
	clk.Advance(6 * time.Minute)
	c.waitRunDone(t, "A")
}

// TestElicitationURLForwardsMessageAndURL covers the fix for the ACP->AG-UI
// field-drop audit finding: a URL-mode elicitation (UnstableCreateElicitationRequest.Url)
// must forward its message and url into the AG-UI STATE_DELTA rather than
// only surfacing mode="url" with nothing else — the client otherwise has no
// way to tell the user what to do.
func TestElicitationURLForwardsMessageAndURL(t *testing.T) {
	f := newFakeConn()
	f.emitElicitationURL = true
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "need input",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
		func(context.Context, string) error { return nil })
	id := c.waitForPendingElicitation(t, "A")

	att := c.Attach("A", 0)
	found := false
	for _, se := range att.Buffered {
		b, err := json.Marshal(se.Ev)
		if err != nil {
			t.Fatal(err)
		}
		if strings.Contains(string(b), `"url":"https://example.com/auth"`) &&
			strings.Contains(string(b), `"message":"Please authorize in your browser"`) {
			found = true
			break
		}
	}
	att.Unsubscribe()
	if !found {
		t.Fatalf("expected a buffered event carrying the elicitation url+message, got %d events", len(att.Buffered))
	}

	if err := c.ResolveElicitation("A", id, acpsdk.UnstableCreateElicitationResponse{
		Accept: &acpsdk.UnstableCreateElicitationAccept{},
	}); err != nil {
		t.Fatal(err)
	}
	c.waitRunDone(t, "A")
}

func TestSetModeDispatchesToConn(t *testing.T) {
	f := newFakeConn()
	f.blockPrompt = make(chan struct{})
	c := testCoordinatorWithConn(t, f, NewFakeClock(time.Unix(0, 0)))
	c.StartPrompt("A", "hi",
		func(context.Context) (string, error) { return "s1", nil },
		func(context.Context) (SessionProfile, error) { return SessionProfile{}, nil },
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
