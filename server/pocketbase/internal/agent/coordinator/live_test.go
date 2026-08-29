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
	"strconv"
	"testing"
	"time"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
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
	return Config{Workspace: ws, PermissionTimeout: time.Minute}
}

// liveProfile optionally applies a model through the same per-session ACP
// config-option path production uses for a chat's selected harness model.
// Keeping it opt-in preserves the generic live test while allowing the Docker
// Ollama integration test to be self-contained on a fresh Goose volume.
//
// GOOSE_LIVE_CREDENTIAL_FIELD_NAME/VALUE are a second, independent opt-in on
// top of provider/model: when both are set, the profile also carries
// SupportsLiveCredentialRegistration and a real credential, driving
// ProviderBootstrap's LiveConfigBootstrap path exactly as production does.
// This is what TestLiveNewSessionBootstrapsProviderCredentialOnFreshContainer
// (below) needs to reproduce the "Provider not set" bug's exact conditions
// against a real, freshly-started goose process with no baked-in provider.
func liveProfile() SessionProfile {
	provider, model := os.Getenv("GOOSE_LIVE_PROVIDER"), os.Getenv("GOOSE_LIVE_MODEL")
	fieldName, fieldValue := os.Getenv("GOOSE_LIVE_CREDENTIAL_FIELD_NAME"), os.Getenv("GOOSE_LIVE_CREDENTIAL_FIELD_VALUE")
	return SessionProfile{
		Target:                             Target{URL: os.Getenv("GOOSE_ACP_URL"), Secret: os.Getenv("GOOSE_SERVER__SECRET_KEY")},
		Provider:                           provider,
		Model:                              model,
		SupportsLiveConfig:                 provider != "" || model != "",
		SupportsLiveCredentialRegistration: fieldName != "" && fieldValue != "",
		CredentialFieldName:                fieldName,
		CredentialFieldValue:               fieldValue,
	}
}

func liveTimeout() time.Duration {
	seconds, err := strconv.Atoi(os.Getenv("GOOSE_LIVE_TIMEOUT_SECONDS"))
	if err == nil && seconds > 0 {
		return time.Duration(seconds) * time.Second
	}
	return 2 * time.Minute
}

func livePrompt() string {
	if prompt := os.Getenv("GOOSE_LIVE_PROMPT"); prompt != "" {
		return prompt
	}
	return "Reply with exactly: ws token ok"
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

// drainEventsWithText is drainEventTypes plus the concatenated text of any
// TextMessageContentEvent deltas seen along the way, so a test can log (or
// assert on) what the assistant actually said, not just which event types
// arrived.
func drainEventsWithText(t *testing.T, att Attachment, timeout time.Duration) (types []events.EventType, text string) {
	t.Helper()
	collect := func(e seqEvent) {
		types = append(types, e.Ev.Type())
		if content, ok := e.Ev.(*events.TextMessageContentEvent); ok {
			text += content.Delta
		}
	}
	for _, e := range att.Buffered {
		collect(e)
		if terminal(e.Ev.Type()) {
			return types, text
		}
	}
	deadline := time.After(timeout)
	for {
		select {
		case e, ok := <-att.Live:
			if !ok {
				return types, text
			}
			collect(e)
			if terminal(e.Ev.Type()) {
				return types, text
			}
		case <-deadline:
			t.Fatalf("timed out waiting for a terminal event; got %v", types)
			return types, text
		}
	}
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
	profileFn := func(context.Context) (SessionProfile, error) { return liveProfile(), nil }
	created := func(_ context.Context, sid string) error { savedSession = sid; return nil }
	finished := func(context.Context, acpsdk.StopReason) error { return nil }

	if _, err := c.StartPrompt(chatID, livePrompt(), resolve, profileFn, created, finished); err != nil {
		t.Fatalf("StartPrompt failed: %v", err)
	}

	att := c.Attach(chatID, 0)
	got := drainEventTypes(t, att, liveTimeout())
	att.Unsubscribe()

	if savedSession == "" {
		t.Fatal("expected a persisted Goose session id")
	}
	sawStarted := false
	for _, eventType := range got {
		if eventType == events.EventTypeRunStarted {
			sawStarted = true
			break
		}
	}
	if !sawStarted || len(got) == 0 || got[len(got)-1] != events.EventTypeRunFinished {
		t.Fatalf("expected an ordered run ending in RUN_FINISHED, got %v", got)
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

// TestLiveNewSessionBootstrapsProviderCredentialOnFreshContainer is the
// checked-in, local version of the manual spike (2026-08-29) that
// root-caused and validated the fix for "Provider not set" on a fresh
// goose container. It requires GOOSE_LIVE_PROVIDER, GOOSE_LIVE_MODEL,
// GOOSE_LIVE_CREDENTIAL_FIELD_NAME, and GOOSE_LIVE_CREDENTIAL_FIELD_VALUE
// in addition to the base live-test env vars, and is meaningful only
// against a genuinely fresh goose process that never had any provider
// credential configured -- e.g. docker-compose.agent-test.yml's `goose`
// service brought up with no ANTHROPIC_API_KEY/OPENROUTER_API_KEY set,
// but GOOSE_PROVIDER/GOOSE_MODEL set to the SAME provider/model as
// GOOSE_LIVE_PROVIDER/GOOSE_LIVE_MODEL below (matching how a real
// production launch always resolves GOOSE_PROVIDER to the user's actually
// -chosen provider before the container boots -- session/new itself
// requires GOOSE_PROVIDER to resolve to something, and pointing it at a
// different, uncredentialed provider races with goose's own session-
// activation code and produces flaky, unrelated "Provider not set"
// failures that have nothing to do with this fix):
//
//	GOOSE_PROVIDER=openrouter GOOSE_MODEL=openrouter/auto \
//	docker compose --profile agent-test up -d --force-recreate -V goose
//	GOOSE_ACP_URL=ws://127.0.0.1:3000/acp \
//	GOOSE_SERVER__SECRET_KEY=<the GOOSE_SERVER__SECRET_KEY you set> \
//	GOOSE_LIVE_PROVIDER=openrouter GOOSE_LIVE_MODEL=openrouter/auto \
//	GOOSE_LIVE_CREDENTIAL_FIELD_NAME=OPENROUTER_API_KEY \
//	GOOSE_LIVE_CREDENTIAL_FIELD_VALUE=<a real key> \
//	go test -tags live_acp ./internal/agent/coordinator/ -run TestLiveNewSessionBootstrapsProviderCredentialOnFreshContainer -v
//
// (tooling/scripts/local_goose_provider_bootstrap_check.sh automates this
// exact setup, including the --env-file /dev/null isolation from this
// repo's own dev-convenience .env keys.)
//
// Before the fix (ProviderBootstrap running before session/new), this
// reliably reproduced RUN_ERROR with the harness returning
// {"code":-32603,"data":"Failed to get provider: Provider not set"} on
// the very first prompt against such a container. This test proves it no
// longer does: it does not require the model call itself to succeed
// (a placeholder key still exercises the RPC layer fully and typically
// fails downstream at the provider, not at "Provider not set"), it only
// asserts the run does not fail with that specific error.
func TestLiveNewSessionBootstrapsProviderCredentialOnFreshContainer(t *testing.T) {
	profile := liveProfile()
	if !profile.SupportsLiveCredentialRegistration {
		t.Skip("set GOOSE_LIVE_CREDENTIAL_FIELD_NAME and GOOSE_LIVE_CREDENTIAL_FIELD_VALUE (plus GOOSE_LIVE_PROVIDER) to run this test")
	}

	c, err := New(liveConfig(t))
	if err != nil {
		t.Fatal(err)
	}

	chatID := "live-chat-fresh-provider"
	resolve := func(context.Context) (string, error) { return "", nil }
	profileFn := func(context.Context) (SessionProfile, error) { return profile, nil }
	created := func(context.Context, string) error { return nil }
	finished := func(context.Context, acpsdk.StopReason) error { return nil }

	if _, err := c.StartPrompt(chatID, livePrompt(), resolve, profileFn, created, finished); err != nil {
		t.Fatalf("StartPrompt failed: %v", err)
	}

	att := c.Attach(chatID, 0)
	defer att.Unsubscribe()
	got, reply := drainEventsWithText(t, att, liveTimeout())

	if len(got) == 0 {
		t.Fatal("expected at least one event")
	}
	if last := got[len(got)-1]; last == events.EventTypeRunError {
		t.Fatalf("run ended in RUN_ERROR -- if this mentions \"Provider not set\", the fix has regressed; events: %v", got)
	}
	t.Logf("provider bootstrap on fresh container ok: events=%d, last=%v, assistant reply=%q", len(got), got[len(got)-1], reply)
}

// TestLiveWrongSecretRejected proves the WS endpoint enforces auth: a bad
// token must fail the handshake, so the detached run publishes RUN_ERROR
// instead of driving goose.
func TestLiveWrongSecretRejected(t *testing.T) {
	cfg := liveConfig(t)
	c, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}

	chatID := "live-chat-bad"
	resolve := func(context.Context) (string, error) { return "", nil }
	profileFn := func(context.Context) (SessionProfile, error) {
		profile := liveProfile()
		profile.Target.Secret = "definitely-not-the-secret"
		return profile, nil
	}
	created := func(context.Context, string) error { return nil }
	finished := func(context.Context, acpsdk.StopReason) error { return nil }
	if _, err := c.StartPrompt(chatID, "should never run", resolve, profileFn, created, finished); err != nil {
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
