package sessionprofile

import (
	"context"
	"net"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func testApp(t *testing.T) core.App {
	t.Helper()
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(app.Cleanup)
	return app
}

func seedRunningHarnessInstance(t *testing.T, app core.App) *core.Record {
	t.Helper()
	harnessesColl, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	suffix := uuid.NewString()[:8]
	harness := core.NewRecord(harnessesColl)
	harness.Set("name", "Test Opencode")
	harness.Set("cli_id", "opencode-race-"+suffix)
	harness.Set("acp_transport", "stdio")
	if err := app.Save(harness); err != nil {
		t.Fatal(err)
	}

	instancesColl, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	instance := core.NewRecord(instancesColl)
	instance.Set("harness", harness.Id)
	instance.Set("container_name", "pocketcoder-opencode-race-"+suffix)
	instance.Set("acp_endpoint", "")
	instance.Set("status", "running")
	if err := app.Save(instance); err != nil {
		t.Fatal(err)
	}
	return instance
}

func TestSelectCredentialSyncer(t *testing.T) {
	coll := core.NewBaseCollection("harnesses")
	for _, cli := range []string{"goose", "claude-code", "codex"} {
		h := core.NewRecord(coll)
		h.Set("cli_id", cli)
		if _, ok := selectCredentialSyncer(h).(NoopCredentialSyncer); !ok {
			t.Fatalf("%s: expected NoopCredentialSyncer", cli)
		}
	}
	h := core.NewRecord(coll)
	h.Set("cli_id", "opencode")
	if _, ok := selectCredentialSyncer(h).(OpencodeAuthFileSyncer); !ok {
		t.Fatal("expected OpencodeAuthFileSyncer")
	}
}

func TestNoopCredentialSyncer(t *testing.T) {
	if err := (NoopCredentialSyncer{}).Sync(context.Background(), nil, nil, nil, "credential"); err != nil {
		t.Fatal(err)
	}
}

func TestCredentialHash(t *testing.T) {
	if credentialHash("provider", "key") != credentialHash("provider", "key") {
		t.Fatal("same input produced different hashes")
	}
	if credentialHash("provider", "key") == credentialHash("provider", "other") {
		t.Fatal("different credentials produced same hash")
	}
}

func TestLockForInstance(t *testing.T) {
	a := lockForInstance("same-test-instance")
	b := lockForInstance("same-test-instance")
	if a != b {
		t.Fatal("same instance did not return same mutex")
	}
	if a == lockForInstance("different-test-instance") {
		t.Fatal("different instances returned same mutex")
	}
	// Ensure the returned object is the documented mutex type and usable.
	var _ *sync.Mutex = a
}

func TestWaitForPort_SucceedsOncePortOpens(t *testing.T) {
	addr := freeLocalAddr(t)
	host, portStr, _ := strings.Cut(addr, ":")
	port, err := strconv.Atoi(portStr)
	if err != nil {
		t.Fatal(err)
	}

	done := make(chan error, 1)
	go func() { done <- waitForPort(context.Background(), host, port, 2*time.Second) }()

	time.Sleep(150 * time.Millisecond)
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		t.Fatal(err)
	}
	defer ln.Close()

	select {
	case err := <-done:
		if err != nil {
			t.Fatalf("waitForPort: %v", err)
		}
	case <-time.After(2 * time.Second):
		t.Fatal("waitForPort never returned after the port opened")
	}
}

func TestWaitForPort_TimesOutIfPortNeverOpens(t *testing.T) {
	addr := freeLocalAddr(t)
	host, portStr, _ := strings.Cut(addr, ":")
	port, _ := strconv.Atoi(portStr)

	err := waitForPort(context.Background(), host, port, 300*time.Millisecond)
	if err == nil {
		t.Fatal("expected a timeout error, got nil")
	}
}

func TestMarkCredentialSynced_DoesNotClobberConcurrentAcpEndpoint(t *testing.T) {
	app := testApp(t)
	instance := seedRunningHarnessInstance(t, app)

	concurrent, err := app.FindRecordById("harness_instances", instance.Id)
	if err != nil {
		t.Fatal(err)
	}
	concurrent.Set("acp_endpoint", "ws://real-container:3000/acp")
	if err := app.Save(concurrent); err != nil {
		t.Fatal(err)
	}

	if err := markCredentialSynced(app, instance.Id, map[string]string{"openrouter": "some-hash"}); err != nil {
		t.Fatal(err)
	}

	final, err := app.FindRecordById("harness_instances", instance.Id)
	if err != nil {
		t.Fatal(err)
	}
	if got := final.GetString("acp_endpoint"); got != "ws://real-container:3000/acp" {
		t.Fatalf("acp_endpoint = %q, want the concurrently-set value preserved", got)
	}
	var synced map[string]string
	_ = final.UnmarshalJSONField("synced_credentials", &synced)
	if synced["openrouter"] != "some-hash" {
		t.Fatalf("synced_credentials = %+v, want openrouter=some-hash", synced)
	}
}

func freeLocalAddr(t *testing.T) string {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	addr := ln.Addr().String()
	ln.Close()
	return addr
}
