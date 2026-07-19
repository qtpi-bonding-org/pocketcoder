//go:build live_acp

// Live acceptance test for the c1→c2 WebSocket path against a real goose serve.
// It is excluded from normal builds; run it explicitly:
//
//	GOOSE_ACP_URL=ws://127.0.0.1:3000/acp \
//	GOOSE_SERVER__SECRET_KEY=<secret> \
//	GOOSE_WORKSPACE=/workspace \
//	go test -tags live_acp ./internal/agent/coordinator/ -run TestLive -v
//
// It drives the production Coordinator (real acp.Dial + wsURLWithToken)
// through the detached StartPrompt+Attach path (the synchronous Run/Replay
// path was removed at the transport cutover), so it proves: WS auth is
// enforced, ?token= satisfies it, the full ACP turn sequence still works on
// the bumped goose image, and a reconnect mid-history replays without a
// gap while the run's log is still lingering in the hub.
package coordinator

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
)

func liveConfig(t *testing.T) Config {
	t.Helper()
	url := os.Getenv("GOOSE_ACP_URL")
	secret := os.Getenv("GOOSE_SERVER__SECRET_KEY")
	if url == "" || secret == "" {
		t.Skip("set GOOSE_ACP_URL and GOOSE_SERVER__SECRET_KEY to run the live test")
	}
	ws := os.Getenv("GOOSE_WORKSPACE")
	if ws == "" {
		ws = "/workspace"
	}
	return Config{GooseURL: url, GooseSecret: secret, Workspace: ws, PermissionTimeout: time.Minute}
}

// drainEventTypes collects Buffered event types, then reads Live until it
// observes a terminal RUN_FINISHED/RUN_ERROR, the channel closes, or the
// deadline passes (which fails the test — a live run must terminate).
func drainEventTypes(t *testing.T, att Attachment, timeout time.Duration) []events.EventType {
	t.Helper()
	var got []events.EventType
	for _, e := range att.Buffered {
		got = append(got, e.Ev.Type())
		if terminal(e.Ev.Type()) {
			return got
		}
	}
	deadline := time.After(timeout)
	for {
		select {
		case e, ok := <-att.Live:
			if !ok {
				return got
			}
			got = append(got, e.Ev.Type())
			if terminal(e.Ev.Type()) {
				return got
			}
		case <-deadline:
			t.Fatalf("timed out waiting for a terminal event; got %v", got)
			return got
		}
	}
}
func terminal(t events.EventType) bool {
	return t == events.EventTypeRunFinished || t == events.EventTypeRunError
}

// TestLiveRunNewSession proves an authenticated new-session turn completes and
// persists a Goose session id, and that a subsequent Attach at cursor 0 (the
// run is still lingering) replays the same history without a cold-replay
// fallback (no gap between what the first subscriber saw and what a fresh
// attach observes).
func TestLiveRunNewSession(t *testing.T) {
	c, err := New(liveConfig(t))
	if err != nil {
		t.Fatal(err)
	}

	chatID := "live-chat"
	var savedSession string
	resolve := func(context.Context) (string, error) { return "", nil }
	created := func(_ context.Context, sid string) error { savedSession = sid; return nil }

	if _, err := c.StartPrompt(chatID, "Reply with exactly: ws token ok", resolve, created); err != nil {
		t.Fatalf("StartPrompt failed: %v", err)
	}

	att := c.Attach(chatID, 0)
	got := drainEventTypes(t, att, 2*time.Minute)
	att.Unsubscribe()

	if savedSession == "" {
		t.Fatal("expected a persisted Goose session id")
	}
	if len(got) < 2 || got[0] != events.EventTypeRunStarted || got[len(got)-1] != events.EventTypeRunFinished {
		t.Fatalf("expected RUN_STARTED…RUN_FINISHED, got %v", got)
	}
	t.Logf("live turn ok: session=%s events=%d", savedSession, len(got))

	// The run just finished and should still be lingering (default 30s
	// window): a reattach at cursor 0 must resume from the in-memory log,
	// not fall back to a Goose cold replay.
	att2 := c.Attach(chatID, 0)
	defer att2.Unsubscribe()
	if att2.ColdReplayNeeded {
		t.Fatal("run just finished and should still be lingering in the hub")
	}
	if len(att2.Buffered) != len(got) {
		t.Fatalf("reattach saw %d buffered events, want %d (no gap/dup)", len(att2.Buffered), len(got))
	}
}

// TestLiveWrongSecretRejected proves the WS endpoint enforces auth: a bad
// token must fail the handshake, so the detached run publishes RUN_ERROR
// instead of driving goose.
func TestLiveWrongSecretRejected(t *testing.T) {
	cfg := liveConfig(t)
	cfg.GooseSecret = "definitely-not-the-secret"
	c, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}

	chatID := "live-chat-bad"
	resolve := func(context.Context) (string, error) { return "", nil }
	created := func(context.Context, string) error { return nil }
	if _, err := c.StartPrompt(chatID, "should never run", resolve, created); err != nil {
		t.Fatalf("StartPrompt failed: %v", err)
	}

	att := c.Attach(chatID, 0)
	defer att.Unsubscribe()
	got := drainEventTypes(t, att, 30*time.Second)
	if len(got) == 0 || got[len(got)-1] != events.EventTypeRunError {
		t.Fatalf("expected RUN_ERROR on unauthenticated dial, got %v", got)
	}
	t.Logf("unauthenticated dial rejected as expected: %v", got)
}
