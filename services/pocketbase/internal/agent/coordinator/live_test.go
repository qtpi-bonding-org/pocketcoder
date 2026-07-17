//go:build live_acp

// Live acceptance test for the c1→c2 WebSocket path against a real goose serve.
// It is excluded from normal builds; run it explicitly:
//
//	GOOSE_ACP_URL=ws://127.0.0.1:3000/acp \
//	GOOSE_SERVER__SECRET_KEY=<secret> \
//	GOOSE_WORKSPACE=/workspace \
//	go test -tags live_acp ./internal/agent/coordinator/ -run TestLive -v
//
// It drives the production Coordinator (real acp.Dial + wsURLWithToken), so it
// proves: WS auth is enforced, ?token= satisfies it, and the full ACP turn
// sequence still works on the bumped goose image.
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

func collect(emit *[]events.EventType) Emit {
	return func(e events.Event) error { *emit = append(*emit, e.Type()); return nil }
}

// TestLiveRunNewSession proves an authenticated new-session turn completes and
// persists a Goose session id.
func TestLiveRunNewSession(t *testing.T) {
	c, err := New(liveConfig(t))
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	var got []events.EventType
	var savedSession string
	resolve := func(context.Context) (string, error) { return "", nil }
	created := func(_ context.Context, sid string) error { savedSession = sid; return nil }

	err = c.Run(ctx, RunRequest{ChatID: "live-chat", Prompt: "Reply with exactly: ws token ok"}, collect(&got), resolve, created)
	if err != nil {
		t.Fatalf("live run failed: %v", err)
	}
	if savedSession == "" {
		t.Fatal("expected a persisted Goose session id")
	}
	if len(got) < 2 || got[0] != events.EventTypeRunStarted || got[len(got)-1] != events.EventTypeRunFinished {
		t.Fatalf("expected RUN_STARTED…RUN_FINISHED, got %v", got)
	}
	t.Logf("live turn ok: session=%s events=%d", savedSession, len(got))
}

// TestLiveWrongSecretRejected proves the WS endpoint enforces auth: a bad token
// must fail the handshake, so the run errors instead of driving goose.
func TestLiveWrongSecretRejected(t *testing.T) {
	cfg := liveConfig(t)
	cfg.GooseSecret = "definitely-not-the-secret"
	c, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	var got []events.EventType
	resolve := func(context.Context) (string, error) { return "", nil }
	created := func(context.Context, string) error { return nil }

	err = c.Run(ctx, RunRequest{ChatID: "live-chat-bad", Prompt: "should never run"}, collect(&got), resolve, created)
	if err == nil {
		t.Fatal("expected the run to fail with an unauthenticated WS handshake")
	}
	t.Logf("unauthenticated dial rejected as expected: %v", err)
}
