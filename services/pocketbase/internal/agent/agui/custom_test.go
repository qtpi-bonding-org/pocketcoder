package agui

import (
	"encoding/json"
	"strings"
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

// rawEvent lives in custom.go (package agui) — must strip _meta so ACP's
// vendor/cost internals never leak to the Flutter UI.
func TestRawEventStripsMeta(t *testing.T) {
	e := rawEvent("session/update", map[string]any{
		"_meta":         map[string]any{"secret": 1},
		"sessionUpdate": "unknown_x",
	})
	b, err := json.Marshal(e)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	s := string(b)
	if strings.Contains(s, "_meta") {
		t.Fatalf("RAW must strip _meta: %s", s)
	}
	if strings.Contains(s, "secret") {
		t.Fatalf("RAW must strip _meta contents: %s", s)
	}
	if e.Type() != "RAW" {
		t.Fatalf("type=%s want RAW", e.Type())
	}
}

// customTool emits a CUSTOM event with name "pocketcoder:tool" carrying the
// identifier, title, kind, status, and locations. Locations come from ACP
// ToolCallLocation: Path is required, Line is *int.
func TestCustomToolEvent(t *testing.T) {
	id := "tc1"
	e := customTool(id, "Edit", "edit", "in_progress", []acpsdk.ToolCallLocation{
		{Path: "/tmp/x.go"},
	})
	if e.Type() != "CUSTOM" {
		t.Fatalf("type=%s want CUSTOM", e.Type())
	}
	b, err := json.Marshal(e)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	s := string(b)
	if !strings.Contains(s, `"pocketcoder:tool"`) {
		t.Fatalf("missing pocketcoder:tool name in payload: %s", s)
	}
	if !strings.Contains(s, `"kind":"edit"`) {
		t.Fatalf("missing kind=edit in payload: %s", s)
	}
	if !strings.Contains(s, `"toolCallId":"tc1"`) {
		t.Fatalf("missing toolCallId=tc1 in payload: %s", s)
	}
	if !strings.Contains(s, `"path":"/tmp/x.go"`) {
		t.Fatalf("missing location path in payload: %s", s)
	}
}
