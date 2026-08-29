package sessionprofile

import (
	"context"
	"sync"
	"testing"

	"github.com/pocketbase/pocketbase/core"
)

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
