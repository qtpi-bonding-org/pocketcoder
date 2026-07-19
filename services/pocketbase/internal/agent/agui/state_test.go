package agui

import (
	"encoding/json"
	"strings"
	"testing"
)

// TestProjectionSetSnapshotRemove exercises the /pocketcoder/* state
// projection: set persists a value (returning STATE_DELTA), snapshot returns
// a single STATE_SNAPSHOT covering the whole /pocketcoder subtree, and remove
// drops the namespace so subsequent snapshots are empty.
func TestProjectionSetSnapshotRemove(t *testing.T) {
	p := &projection{}

	d := p.set("plan", map[string]any{"entries": []any{}})
	if d.Type() != "STATE_DELTA" {
		t.Fatalf("set type=%s want STATE_DELTA", d.Type())
	}

	snap := p.snapshot()
	if len(snap) != 1 || snap[0].Type() != "STATE_SNAPSHOT" {
		t.Fatalf("snapshot=%v", snap)
	}

	b, err := json.Marshal(snap[0])
	if err != nil {
		t.Fatalf("marshal snapshot: %v", err)
	}
	payload := string(b)
	if !strings.Contains(payload, `"pocketcoder"`) {
		t.Fatalf("snapshot payload missing pocketcoder key: %s", payload)
	}
	if !strings.Contains(payload, `"plan"`) {
		t.Fatalf("snapshot payload missing plan namespace: %s", payload)
	}

	p.remove("plan")
	if s := p.snapshot(); s != nil {
		t.Fatalf("expected empty snapshot after remove, got %v", s)
	}
}
