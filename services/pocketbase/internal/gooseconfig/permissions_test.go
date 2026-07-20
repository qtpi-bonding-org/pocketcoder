package gooseconfig

import "testing"

func TestRenderPermissions_AllowMinusDeny_AndDegradations(t *testing.T) {
	rows := []PermRow{
		{Tool: "read", Action: "allow", Pattern: "*"},
		{Tool: "write", Action: "allow", Pattern: "*"},
		{Tool: "write", Action: "deny", Pattern: "*"},   // conflict: deny wins
		{Tool: "shell", Action: "ask", Pattern: "*"},    // ask: dropped
		{Tool: "read", Action: "allow", Pattern: "src/*"}, // pattern dropped
	}
	allow, dropped := RenderPermissions(rows)
	if len(allow) != 1 || allow[0] != "read" {
		t.Fatalf("allow = %v, want [read]", allow)
	}
	if len(dropped) != 3 {
		t.Fatalf("dropped = %v, want 3 entries (ask, pattern, conflict)", dropped)
	}
}

func TestRenderPermissions_NoRulesOmits(t *testing.T) {
	if allow, _ := RenderPermissions(nil); len(allow) != 0 {
		t.Fatalf("expected empty allowlist, got %v", allow)
	}
}
