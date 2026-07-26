package gooseconfig

import "testing"

func TestRenderToolPermissions_AllowDenyAsk(t *testing.T) {
	rows := []PermRow{
		{Tool: "read", Action: "allow", Pattern: "*"},
		{Tool: "shell", Action: "ask", Pattern: "*"},
		{Tool: "danger", Action: "deny", Pattern: "*"},
	}
	entries, dropped := RenderToolPermissions(rows)
	want := map[string]string{
		"read":   PermissionAlwaysAllow,
		"shell":  PermissionAskBefore,
		"danger": PermissionNeverAllow,
	}
	if len(entries) != len(want) {
		t.Fatalf("entries = %v, want %d entries", entries, len(want))
	}
	for _, e := range entries {
		if want[e.ToolName] != e.Permission {
			t.Errorf("tool %s: got %s, want %s", e.ToolName, e.Permission, want[e.ToolName])
		}
	}
	if len(dropped) != 0 {
		t.Fatalf("dropped = %v, want none (ask is no longer lossy)", dropped)
	}
}

func TestRenderToolPermissions_ConflictDenyWins(t *testing.T) {
	rows := []PermRow{
		{Tool: "write", Action: "allow", Pattern: "*"},
		{Tool: "write", Action: "deny", Pattern: "*"},
	}
	entries, dropped := RenderToolPermissions(rows)
	if len(entries) != 1 || entries[0].Permission != PermissionNeverAllow {
		t.Fatalf("entries = %v, want single never_allow entry", entries)
	}
	if len(dropped) != 1 {
		t.Fatalf("dropped = %v, want 1 (allow/deny conflict note)", dropped)
	}
}

func TestRenderToolPermissions_PatternDropped(t *testing.T) {
	rows := []PermRow{{Tool: "read", Action: "allow", Pattern: "src/*"}}
	entries, dropped := RenderToolPermissions(rows)
	if len(entries) != 1 || entries[0].Permission != PermissionAlwaysAllow {
		t.Fatalf("entries = %v, want single always_allow entry (pattern dropped, action kept)", entries)
	}
	if len(dropped) != 1 {
		t.Fatalf("dropped = %v, want 1 (pattern note)", dropped)
	}
}

func TestRenderToolPermissions_NoRulesOmits(t *testing.T) {
	if entries, _ := RenderToolPermissions(nil); len(entries) != 0 {
		t.Fatalf("expected no entries, got %v", entries)
	}
}
