package main

import (
	"context"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

// fakeEchoScript is used as the "harness binary" under test — a tiny shell
// script that echoes each stdin line back to stdout, standing in for a real
// ACP agent's stdio behavior for framing-correctness purposes only (this
// test is about the bridge, not about ACP semantics).
func TestAdapterRoundTripsOneMessagePerFrame(t *testing.T) {
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{
		Cmd: []string{"cat"}, Secret: "s3cr3t", MaxLineBytes: 64 << 20,
	}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=s3cr3t"
	conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	conn.SetReadLimit(64 << 20)
	defer conn.Close(websocket.StatusNormalClosure, "")

	msg := `{"jsonrpc":"2.0","method":"ping","id":1}`
	if err := conn.Write(context.Background(), websocket.MessageText, []byte(msg)); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, data, err := conn.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != msg {
		t.Errorf("got %q, want %q echoed back unmodified", string(data), msg)
	}
}

func TestAdapterRejectsWrongToken(t *testing.T) {
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"cat"}, Secret: "s3cr3t", MaxLineBytes: 64 << 20}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=wrong"
	_, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err == nil {
		t.Fatal("expected the upgrade to be rejected with the wrong token")
	}
}

func TestAdapterRoundTripsMessageAboveDefaultScannerLimit(t *testing.T) {
	// 200KB message — well above bufio.Scanner's 64KB default token size,
	// well within the adapter's required raised limit. This is the
	// regression test for the "two limits, not one" finding.
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"cat"}, Secret: "s3cr3t", MaxLineBytes: 64 << 20}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=s3cr3t"
	conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	conn.SetReadLimit(64 << 20)
	defer conn.Close(websocket.StatusNormalClosure, "")

	big := `{"jsonrpc":"2.0","method":"ping","params":{"blob":"` + strings.Repeat("x", 200*1024) + `"},"id":1}`
	if err := conn.Write(context.Background(), websocket.MessageText, []byte(big)); err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	_, data, err := conn.Read(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if len(data) != len(big) {
		t.Errorf("got %d bytes back, want %d — message truncated somewhere in the bridge", len(data), len(big))
	}
}

func TestAdapterSpawnsFreshSubprocessPerConnection(t *testing.T) {
	// Two connections against the same adapter must each get their own
	// subprocess — asserted indirectly here via a script that increments a
	// counter file on each new invocation; a shared/reused process would
	// only increment once.
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"sh", "-c", "echo spawned; cat"}, Secret: "", MaxLineBytes: 64 << 20}))
	defer srv.Close()
	dialOne := func() string {
		wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp"
		conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
		if err != nil {
			t.Fatal(err)
		}
		defer conn.Close(websocket.StatusNormalClosure, "")
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_, data, err := conn.Read(ctx)
		if err != nil {
			t.Fatal(err)
		}
		return string(data)
	}
	first := dialOne()
	second := dialOne()
	if first != "spawned" || second != "spawned" {
		t.Errorf("expected both connections to see a freshly-spawned process announce itself, got %q and %q", first, second)
	}
}

func TestAdapterServesConnectionsConcurrently(t *testing.T) {
	// Keep the first subprocess alive while opening the second connection. A
	// serialized adapter would never let the second process announce "ready"
	// until the first connection closed.
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{
		Cmd: []string{"sh", "-c", "echo ready; cat"}, Secret: "", MaxLineBytes: 64 << 20,
	}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp"

	dialAndWaitReady := func() *websocket.Conn {
		conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
		if err != nil {
			t.Fatal(err)
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_, data, err := conn.Read(ctx)
		if err != nil {
			conn.Close(websocket.StatusInternalError, "")
			t.Fatal(err)
		}
		if string(data) != "ready" {
			conn.Close(websocket.StatusInternalError, "")
			t.Fatalf("startup message = %q, want ready", data)
		}
		return conn
	}

	first := dialAndWaitReady()
	defer first.Close(websocket.StatusNormalClosure, "")
	second := dialAndWaitReady()
	defer second.Close(websocket.StatusNormalClosure, "")

	for i, conn := range []*websocket.Conn{first, second} {
		message := []byte{byte('a' + i)}
		if err := conn.Write(context.Background(), websocket.MessageText, message); err != nil {
			t.Fatal(err)
		}
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		_, echoed, err := conn.Read(ctx)
		cancel()
		if err != nil {
			t.Fatal(err)
		}
		if string(echoed) != string(message) {
			t.Fatalf("connection %d echoed %q, want %q", i, echoed, message)
		}
	}
}

func TestAdapterDoesNotHangOnOversizedMessage(t *testing.T) {
	// Regression test for the teardown bug: an oversized line used to leave
	// the subprocess (and its still-open stdout pipe) running forever with
	// nothing draining it, since only the failing goroutine exited and
	// nothing killed the process or closed the connection. bridgeConnection
	// must now return promptly regardless.
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"cat"}, Secret: "", MaxLineBytes: 1024}))
	defer srv.Close()
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp"
	conn, _, err := websocket.Dial(context.Background(), wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close(websocket.StatusNormalClosure, "")

	oversized := strings.Repeat("x", 4096) // well above the 1024-byte MaxLineBytes configured above
	if err := conn.Write(context.Background(), websocket.MessageText, []byte(oversized)); err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		conn.Read(ctx) // expected to fail/close once teardown runs, not hang
		close(done)
	}()
	select {
	case <-done:
		// expected: the connection closes promptly instead of hanging
	case <-time.After(2 * time.Second):
		t.Fatal("bridge did not tear down within 2s of an oversized message — the deadlock/leak regression")
	}
}

// TestResolveSecretPrefersFlagOverEnv proves the auth-wiring fix for the
// "reference Dockerfile never wires the per-instance secret to the
// adapter" finding: main() must fall back to HARNESS_ADAPTER_SECRET (what
// a harnesses.launch_template.env_template renders into the container's
// Env) when --secret isn't passed, but --secret still wins when both are
// set.
func TestResolveSecretPrefersFlagOverEnv(t *testing.T) {
	env := map[string]string{"HARNESS_ADAPTER_SECRET": "from-env"}
	getenv := func(k string) string { return env[k] }

	if got := resolveSecret("", getenv); got != "from-env" {
		t.Errorf("resolveSecret(\"\", env-with-secret) = %q, want %q (env fallback)", got, "from-env")
	}
	if got := resolveSecret("from-flag", getenv); got != "from-flag" {
		t.Errorf("resolveSecret(\"from-flag\", env-with-secret) = %q, want %q (flag overrides env)", got, "from-flag")
	}

	emptyGetenv := func(string) string { return "" }
	if got := resolveSecret("", emptyGetenv); got != "" {
		t.Errorf("resolveSecret(\"\", no-env) = %q, want empty (auth disabled, matches today's default behavior)", got)
	}
}

// TestAdapterEnforcesAuthUsingEnvResolvedSecret proves the env-sourced
// secret is not just parsed but actually enforced end-to-end by the
// adapter's WS auth gate — the same way a container started from the
// reference Dockerfile with HARNESS_ADAPTER_SECRET set (and no --secret
// flag) would behave.
func TestAdapterEnforcesAuthUsingEnvResolvedSecret(t *testing.T) {
	getenv := func(k string) string {
		if k == "HARNESS_ADAPTER_SECRET" {
			return "env-secret"
		}
		return ""
	}
	resolved := resolveSecret("", getenv) // simulates --secret unset, env var set
	srv := httptest.NewServer(newAdapterHandler(adapterConfig{Cmd: []string{"cat"}, Secret: resolved, MaxLineBytes: 64 << 20}))
	defer srv.Close()

	// Wrong/missing token: rejected.
	wrongURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=wrong"
	if _, _, err := websocket.Dial(context.Background(), wrongURL, nil); err == nil {
		t.Fatal("expected the upgrade to be rejected when the token doesn't match the env-resolved secret")
	}

	// Correct token (the env var's value): accepted.
	rightURL := "ws" + strings.TrimPrefix(srv.URL, "http") + "/acp?token=env-secret"
	conn, _, err := websocket.Dial(context.Background(), rightURL, nil)
	if err != nil {
		t.Fatalf("expected the upgrade to succeed with the env-resolved secret as the token, got: %v", err)
	}
	conn.Close(websocket.StatusNormalClosure, "")
}
