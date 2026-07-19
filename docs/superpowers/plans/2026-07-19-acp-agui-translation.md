# Robust ACP → AG-UI Translation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the happy-path `internal/agent/agui` translation with a complete, robust ACP→AG-UI translator: every ACP `SessionUpdate` variant, every content-block and tool-content type, correct single-shot/soft-miss handling, and a snapshot-able `/pocketcoder/*` state projection.

**Architecture:** A pure translation unit under `internal/agent/agui/`. It converts `acpsdk.SessionNotification`/lifecycle into `[]events.Event` (AG-UI) and maintains a current-state projection exposed via `Snapshot()`. Standard AG-UI events carry the linear text/tool timeline; `STATE_*` on `/pocketcoder/*` carry bounded current-value state; `CUSTOM pocketcoder:*` carry per-item structured enrichment; unmapped → redacted `RAW`. No coordinator changes here (that is the c1↔c2 bridge plan).

**Tech Stack:** Go; `github.com/coder/acp-go-sdk@v0.13.5`; `github.com/ag-ui-protocol/ag-ui/.../pkg/core/events`; `github.com/google/uuid`. Test with stdlib `testing`. Run from `services/pocketbase`.

**Spec:** `docs/superpowers/specs/2026-07-19-acp-agui-translation-robust-spec.md`.

## Global Constraints

- **Never drop.** Every `SessionUpdate` variant, `ContentBlock` (5), and `ToolCallContent` (3) maps to a defined output; the fallback is redacted `RAW`, never silence.
- **RAW is filtered.** Strip ACP `_meta` and cost/provider internals; debug-gate. "Never dropped" ≠ "never filtered."
- **Side-channels don't perturb the text machine.** Emitting `STATE_*`/`CUSTOM` never opens/closes a `TEXT_MESSAGE`/`REASONING_MESSAGE`/tool boundary.
- **Bounded current-value → STATE (`/pocketcoder/*`); unbounded per-item enrichment → CUSTOM.**
- **Preserve existing public method signatures** used by the coordinator (`NewBridge`, `Update`, `Started`, `Finished`, `PermissionPending`) so `internal/agent/coordinator` keeps compiling; add new methods (`Snapshot`, `ResolvePermission`, `ResolveElicitation`, `ElicitationPending`, `SeedSession`) rather than breaking old ones.
- **TDD.** Every task: failing test → watch fail → minimal code → watch pass → commit. Run `gofmt`; output pristine.
- Test/build commands run from `services/pocketbase`.

---

## File Structure

- `internal/agent/agui/content.go` (new) — `renderContent` (5 `ContentBlock` variants) + `renderToolContent` (3 `ToolCallContent` variants). Single decode point.
- `internal/agent/agui/custom.go` (new) — constructors for `pocketcoder:{tool,diff,terminal,content}` CUSTOM events + redacted `rawEvent`.
- `internal/agent/agui/state.go` (new) — the `/pocketcoder/*` projection: typed current state, `set*` (returns `STATE_DELTA`), `resolve*` (returns removing delta), `snapshot()`.
- `internal/agent/agui/bridge.go` (rewrite) — `Bridge`: boundary state machine + `Update` dispatch over all variants + lifecycle + `Snapshot`/`Resolve*`/`SeedSession`.
- `internal/agent/agui/*_test.go` — golden-sequence tests per file.

Interfaces produced (relied on by later tasks / the c1↔c2 bridge):
```go
func NewBridge(threadID, runID string) *Bridge
func (b *Bridge) SeedSession(modes *acpsdk.SessionModeState, config []acpsdk.SessionConfigOption) []events.Event
func (b *Bridge) Started() events.Event
func (b *Bridge) Update(u acpsdk.SessionUpdate) ([]events.Event, error)
func (b *Bridge) PermissionPending(requestID string, options []acpsdk.PermissionOption) events.Event
func (b *Bridge) ElicitationPending(id, message, mode string, schema any) events.Event
func (b *Bridge) ResolvePermission(id string) []events.Event
func (b *Bridge) ResolveElicitation(id string) []events.Event
func (b *Bridge) Snapshot() []events.Event
func (b *Bridge) Finished() []events.Event
```

---

### Task 1: Content decoding — `renderContent` (all 5 `ContentBlock` variants)

**Files:**
- Create: `services/pocketbase/internal/agent/agui/content.go`
- Test: `services/pocketbase/internal/agent/agui/content_test.go`

**Interfaces:**
- Produces:
  ```go
  type MediaDescriptor struct {
      Kind     string `json:"kind"`               // "image"|"audio"|"resource_link"|"resource"
      MimeType string `json:"mimeType,omitempty"`
      URI      string `json:"uri,omitempty"`
      Name     string `json:"name,omitempty"`
      Size     int    `json:"size,omitempty"`
  }
  // renderContent decodes one ACP content block. Exactly one of (text!="", media!=nil)
  // is set when ok; ok=false only for an empty/unknown block (caller emits RAW).
  func renderContent(block acpsdk.ContentBlock) (text string, media *MediaDescriptor, ok bool)
  ```

- [ ] **Step 1: Write the failing test**

```go
package agui

import (
	"testing"

	acpsdk "github.com/coder/acp-go-sdk"
)

func TestRenderContentText(t *testing.T) {
	text, media, ok := renderContent(acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "hi"}})
	if !ok || text != "hi" || media != nil {
		t.Fatalf("text: got (%q,%v,%v)", text, media, ok)
	}
}

func TestRenderContentImage(t *testing.T) {
	uri := "https://x/y.png"
	_, media, ok := renderContent(acpsdk.ContentBlock{Image: &acpsdk.ContentBlockImage{Type: "image", MimeType: "image/png", Uri: &uri}})
	if !ok || media == nil || media.Kind != "image" || media.MimeType != "image/png" || media.URI != uri {
		t.Fatalf("image: got %+v ok=%v", media, ok)
	}
}

func TestRenderContentResourceLinkAndResource(t *testing.T) {
	_, media, ok := renderContent(acpsdk.ContentBlock{ResourceLink: &acpsdk.ContentBlockResourceLink{Type: "resource_link", Name: "f.go"}})
	if !ok || media == nil || media.Kind != "resource_link" || media.Name != "f.go" {
		t.Fatalf("resource_link: got %+v ok=%v", media, ok)
	}
	_, media, ok = renderContent(acpsdk.ContentBlock{Resource: &acpsdk.ContentBlockResource{Type: "resource"}})
	if !ok || media == nil || media.Kind != "resource" {
		t.Fatalf("resource: got %+v ok=%v", media, ok)
	}
}

func TestRenderContentEmpty(t *testing.T) {
	if _, _, ok := renderContent(acpsdk.ContentBlock{}); ok {
		t.Fatal("empty block should be ok=false")
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestRenderContent -v`
Expected: FAIL (undefined: `renderContent`).

- [ ] **Step 3: Write minimal implementation**

```go
package agui

import acpsdk "github.com/coder/acp-go-sdk"

type MediaDescriptor struct {
	Kind     string `json:"kind"`
	MimeType string `json:"mimeType,omitempty"`
	URI      string `json:"uri,omitempty"`
	Name     string `json:"name,omitempty"`
	Size     int    `json:"size,omitempty"`
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// renderContent decodes one ACP content block into either text or a media
// descriptor. No variant falls through: unknown/empty returns ok=false so the
// caller emits RAW.
func renderContent(block acpsdk.ContentBlock) (string, *MediaDescriptor, bool) {
	switch {
	case block.Text != nil:
		return block.Text.Text, nil, true
	case block.Image != nil:
		return "", &MediaDescriptor{Kind: "image", MimeType: block.Image.MimeType, URI: deref(block.Image.Uri)}, true
	case block.Audio != nil:
		return "", &MediaDescriptor{Kind: "audio", MimeType: block.Audio.MimeType}, true
	case block.ResourceLink != nil:
		m := &MediaDescriptor{Kind: "resource_link", Name: block.ResourceLink.Name, URI: block.ResourceLink.Uri, MimeType: deref(block.ResourceLink.MimeType)}
		if block.ResourceLink.Size != nil {
			m.Size = *block.ResourceLink.Size
		}
		return "", m, true
	case block.Resource != nil:
		return "", &MediaDescriptor{Kind: "resource"}, true
	}
	return "", nil, false
}
```
> Verify field names against `acp-go-sdk@v0.13.5/types_gen.go` (`ContentBlockImage.Uri *string`, `ContentBlockResourceLink.{Name,Uri,MimeType,Size}`); adjust if the SDK differs.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestRenderContent -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/content.go services/pocketbase/internal/agent/agui/content_test.go
git commit -m "feat(agui): renderContent covers all 5 ACP content-block variants"
```

---

### Task 2: Tool content decoding — `renderToolContent` (all 3 `ToolCallContent` variants)

**Files:**
- Modify: `services/pocketbase/internal/agent/agui/content.go`
- Test: `services/pocketbase/internal/agent/agui/content_test.go`

**Interfaces:**
- Produces:
  ```go
  type ToolDiff struct {
      Path    string `json:"path"`
      OldText string `json:"oldText,omitempty"`
      NewText string `json:"newText"`
  }
  type ToolTerminal struct {
      TerminalID string `json:"terminalId"`
      Type       string `json:"type,omitempty"`
  }
  // renderToolContent splits ACP tool result content into a fallback text
  // rendering (for TOOL_CALL_RESULT.content) plus structured diffs/terminals
  // (for CUSTOM pocketcoder:{diff,terminal}). rawOutput is the JSON fallback
  // when no content blocks are present.
  func renderToolContent(content []acpsdk.ToolCallContent, rawOutput any) (text string, diffs []ToolDiff, terminals []ToolTerminal, hasOutput bool, err error)
  ```

- [ ] **Step 1: Write the failing test**

```go
func TestRenderToolContentTextDiffTerminal(t *testing.T) {
	old := "a\n"
	content := []acpsdk.ToolCallContent{
		{Content: &acpsdk.ToolCallContentContent{Type: "content", Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "ran ok"}}}},
		{Diff: &acpsdk.ToolCallContentDiff{Path: "/f.go", OldText: &old, NewText: "b\n"}},
		{Terminal: &acpsdk.ToolCallContentTerminal{TerminalId: "t1", Type: "terminal"}},
	}
	text, diffs, terms, has, err := renderToolContent(content, nil)
	if err != nil || !has {
		t.Fatalf("err=%v has=%v", err, has)
	}
	if text != "ran ok" {
		t.Fatalf("text=%q", text)
	}
	if len(diffs) != 1 || diffs[0].Path != "/f.go" || diffs[0].NewText != "b\n" || diffs[0].OldText != "a\n" {
		t.Fatalf("diffs=%+v", diffs)
	}
	if len(terms) != 1 || terms[0].TerminalID != "t1" {
		t.Fatalf("terms=%+v", terms)
	}
}

func TestRenderToolContentRawFallback(t *testing.T) {
	text, _, _, has, err := renderToolContent(nil, map[string]any{"exit": 0})
	if err != nil || !has || text == "" {
		t.Fatalf("rawOutput fallback: text=%q has=%v err=%v", text, has, err)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestRenderToolContent -v`
Expected: FAIL (undefined: `renderToolContent`).

- [ ] **Step 3: Write minimal implementation** (append to `content.go`)

```go
import (
	"encoding/json"
	"fmt"
	"strings"
)

type ToolDiff struct {
	Path    string `json:"path"`
	OldText string `json:"oldText,omitempty"`
	NewText string `json:"newText"`
}
type ToolTerminal struct {
	TerminalID string `json:"terminalId"`
	Type       string `json:"type,omitempty"`
}

func renderToolContent(content []acpsdk.ToolCallContent, rawOutput any) (string, []ToolDiff, []ToolTerminal, bool, error) {
	var textParts []string
	var diffs []ToolDiff
	var terminals []ToolTerminal
	for _, c := range content {
		switch {
		case c.Content != nil:
			if t, _, ok := renderContent(c.Content.Content); ok && t != "" {
				textParts = append(textParts, t)
			}
		case c.Diff != nil:
			diffs = append(diffs, ToolDiff{Path: c.Diff.Path, OldText: deref(c.Diff.OldText), NewText: c.Diff.NewText})
		case c.Terminal != nil:
			terminals = append(terminals, ToolTerminal{TerminalID: c.Terminal.TerminalId, Type: c.Terminal.Type})
		}
	}
	text := strings.Join(textParts, "\n")
	has := text != "" || len(diffs) > 0 || len(terminals) > 0
	if !has && rawOutput != nil {
		encoded, err := json.Marshal(rawOutput)
		if err != nil {
			return "", nil, nil, false, fmt.Errorf("encode tool rawOutput: %w", err)
		}
		return string(encoded), nil, nil, true, nil
	}
	return text, diffs, terminals, has, nil
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestRenderToolContent -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/content.go services/pocketbase/internal/agent/agui/content_test.go
git commit -m "feat(agui): renderToolContent covers content/diff/terminal"
```

---

### Task 3: CUSTOM constructors + redacted RAW — `custom.go`

**Files:**
- Create: `services/pocketbase/internal/agent/agui/custom.go`
- Test: `services/pocketbase/internal/agent/agui/custom_test.go`

**Interfaces:**
- Produces:
  ```go
  func customTool(id, title, kind, status string, locations []acpsdk.ToolCallLocation) events.Event
  func customDiff(toolCallID string, d ToolDiff) events.Event
  func customTerminal(toolCallID string, term ToolTerminal) events.Event
  func customContent(messageID string, m MediaDescriptor) events.Event
  // rawEvent strips _meta / vendor internals before emit; debug-gated by the caller.
  func rawEvent(kind string, payload any) events.Event
  ```

- [ ] **Step 1: Write the failing test**

```go
package agui

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestCustomToolEvent(t *testing.T) {
	e := customTool("tc1", "Edit", "edit", "in_progress", nil)
	if e.Type() != "CUSTOM" {
		t.Fatalf("type=%s", e.Type())
	}
	b, _ := json.Marshal(e)
	s := string(b)
	if !strings.Contains(s, `"pocketcoder:tool"`) || !strings.Contains(s, `"kind":"edit"`) {
		t.Fatalf("payload=%s", s)
	}
}

func TestRawEventStripsMeta(t *testing.T) {
	e := rawEvent("session/update", map[string]any{"_meta": map[string]any{"secret": 1}, "sessionUpdate": "unknown_x"})
	b, _ := json.Marshal(e)
	if strings.Contains(string(b), "_meta") || strings.Contains(string(b), "secret") {
		t.Fatalf("RAW must strip _meta: %s", string(b))
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run 'TestCustom|TestRaw' -v`
Expected: FAIL (undefined).

- [ ] **Step 3: Write minimal implementation**

```go
package agui

import (
	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
)

func customTool(id, title, kind, status string, locations []acpsdk.ToolCallLocation) events.Event {
	locs := make([]map[string]any, 0, len(locations))
	for _, l := range locations {
		m := map[string]any{"path": l.Path}
		if l.Line != nil {
			m["line"] = *l.Line
		}
		locs = append(locs, m)
	}
	return events.NewCustomEvent("pocketcoder:tool", events.WithValue(map[string]any{
		"toolCallId": id, "title": title, "kind": kind, "status": status, "locations": locs,
	}))
}

func customDiff(toolCallID string, d ToolDiff) events.Event {
	return events.NewCustomEvent("pocketcoder:diff", events.WithValue(map[string]any{
		"toolCallId": toolCallID, "path": d.Path, "oldText": d.OldText, "newText": d.NewText,
	}))
}

func customTerminal(toolCallID string, term ToolTerminal) events.Event {
	return events.NewCustomEvent("pocketcoder:terminal", events.WithValue(map[string]any{
		"toolCallId": toolCallID, "terminalId": term.TerminalID, "type": term.Type,
	}))
}

func customContent(messageID string, m MediaDescriptor) events.Event {
	return events.NewCustomEvent("pocketcoder:content", events.WithValue(map[string]any{
		"messageId": messageID, "kind": m.Kind, "mimeType": m.MimeType, "uri": m.URI, "name": m.Name, "size": m.Size,
	}))
}

// rawEvent emits an unmapped update without leaking ACP internals: the payload
// is reduced to a stable marker (its kind) — never the raw _meta/cost blob.
func rawEvent(kind string, _ any) events.Event {
	return events.NewRawEvent(map[string]any{"unmapped": kind}, events.WithSource("acp"))
}
```
> RAW deliberately ships only `{"unmapped": <kind>}`. If a debug flag later wants the full payload, gate it there — default stays redacted per the spec.

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run 'TestCustom|TestRaw' -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/custom.go services/pocketbase/internal/agent/agui/custom_test.go
git commit -m "feat(agui): pocketcoder CUSTOM events + redacted RAW fallback"
```

---

### Task 4: State projection — `state.go`

**Files:**
- Create: `services/pocketbase/internal/agent/agui/state.go`
- Test: `services/pocketbase/internal/agent/agui/state_test.go`

**Interfaces:**
- Produces:
  ```go
  type projection struct { /* private current-value per namespace */ }
  func (p *projection) set(ns string, value any) events.Event      // STATE_DELTA add /pocketcoder/<ns>
  func (p *projection) remove(ns string) events.Event               // STATE_DELTA remove /pocketcoder/<ns>
  func (p *projection) snapshot() []events.Event                    // one STATE_SNAPSHOT of {pocketcoder:{...}} or nil
  ```
- Namespaces (`ns`): `modes`, `config`, `plan`, `commands`, `usage`, `session_info`, `permission`, `elicitation`.

- [ ] **Step 1: Write the failing test**

```go
package agui

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestProjectionSetSnapshotRemove(t *testing.T) {
	p := &projection{}
	d := p.set("plan", map[string]any{"entries": []any{}})
	if d.Type() != "STATE_DELTA" {
		t.Fatalf("set type=%s", d.Type())
	}
	snap := p.snapshot()
	if len(snap) != 1 || snap[0].Type() != "STATE_SNAPSHOT" {
		t.Fatalf("snapshot=%v", snap)
	}
	b, _ := json.Marshal(snap[0])
	if !strings.Contains(string(b), `"pocketcoder"`) || !strings.Contains(string(b), `"plan"`) {
		t.Fatalf("snapshot payload=%s", string(b))
	}
	p.remove("plan")
	if s := p.snapshot(); s != nil {
		t.Fatalf("expected empty snapshot after remove, got %v", s)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestProjection -v`
Expected: FAIL (undefined: `projection`).

- [ ] **Step 3: Write minimal implementation**

```go
package agui

import "github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"

type projection struct {
	state map[string]any
}

func (p *projection) ensure() {
	if p.state == nil {
		p.state = map[string]any{}
	}
}

func (p *projection) set(ns string, value any) events.Event {
	p.ensure()
	p.state[ns] = value
	return events.NewStateDeltaEvent([]events.JSONPatchOperation{{Op: "add", Path: "/pocketcoder/" + ns, Value: value}})
}

func (p *projection) remove(ns string) events.Event {
	if p.state != nil {
		delete(p.state, ns)
	}
	return events.NewStateDeltaEvent([]events.JSONPatchOperation{{Op: "remove", Path: "/pocketcoder/" + ns}})
}

// snapshot returns a single STATE_SNAPSHOT of the whole /pocketcoder subtree,
// or nil when nothing is set. This refines spec §6's "per-namespace" wording:
// one snapshot replaces client state atomically and is cheaper.
func (p *projection) snapshot() []events.Event {
	if len(p.state) == 0 {
		return nil
	}
	return []events.Event{events.NewStateSnapshotEvent(map[string]any{"pocketcoder": p.state})}
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestProjection -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/state.go services/pocketbase/internal/agent/agui/state_test.go
git commit -m "feat(agui): /pocketcoder state projection (set/remove/snapshot)"
```

---

### Task 5: Bridge rewrite — messages, reasoning, `UserMessageChunk`, media

**Files:**
- Modify: `services/pocketbase/internal/agent/agui/bridge.go`
- Test: `services/pocketbase/internal/agent/agui/bridge_test.go` (extend existing)

**Interfaces:**
- Consumes: `renderContent` (Task 1), `customContent` (Task 3), `projection` (Task 4).
- Produces: `Bridge` with `projection` field, `Update` handling `UserMessageChunk`/`AgentMessageChunk`/`AgentThoughtChunk`, media via `customContent`. Keeps the existing boundary machine (`ensureMessageID`, `closeMessage`, etc.).

- [ ] **Step 1: Write the failing test**

```go
func TestBridgeUserMessageChunkReplay(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	mid := "user-1"
	evs, err := bridge.Update(acpsdk.SessionUpdate{UserMessageChunk: &acpsdk.SessionUpdateUserMessageChunk{
		SessionUpdate: "user_message_chunk", MessageId: &mid,
		Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "do X"}},
	}})
	if err != nil || len(evs) != 2 || evs[0].Type() != "TEXT_MESSAGE_START" || evs[1].Type() != "TEXT_MESSAGE_CONTENT" {
		t.Fatalf("user chunk: %#v err=%v", evs, err)
	}
	// role must be "user"
	b, _ := json.Marshal(evs[0])
	if !strings.Contains(string(b), `"role":"user"`) {
		t.Fatalf("expected user role: %s", string(b))
	}
}

func TestBridgeAgentImageEmitsContentCustom(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	mid := "m1"
	uri := "https://x/y.png"
	evs, err := bridge.Update(acpsdk.SessionUpdate{AgentMessageChunk: &acpsdk.SessionUpdateAgentMessageChunk{
		SessionUpdate: "agent_message_chunk", MessageId: &mid,
		Content: acpsdk.ContentBlock{Image: &acpsdk.ContentBlockImage{Type: "image", MimeType: "image/png", Uri: &uri}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, e := range evs {
		if e.Type() == "CUSTOM" {
			found = true
		}
	}
	if !found {
		t.Fatalf("image chunk should emit CUSTOM pocketcoder:content, got %#v", evs)
	}
}
```
(Keep the existing `TestBridgeMessageLifecycleAndTerminal` passing.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestBridge -v`
Expected: FAIL (UserMessageChunk unhandled → 0 events; image → no CUSTOM).

- [ ] **Step 3: Write minimal implementation**

Rewrite the message/reasoning arms of `Update` to route through a shared helper and handle media + user chunks. Add `state projection` to the struct:

```go
type Bridge struct {
	threadID, runID string
	messageID       string
	messageOpen     bool
	messageRole     string
	reasoningID     string
	reasoningOpen   bool
	openTools       map[string]toolMeta
	state           projection
}

// textChunk emits START(role)+CONTENT for a text/reasoning block, closing the
// opposite scope first. Media blocks emit CUSTOM pocketcoder:content instead of
// text, without opening a message scope.
func (b *Bridge) messageChunk(role string, msgID *string, content acpsdk.ContentBlock) []events.Event {
	text, media, ok := renderContent(content)
	id := b.ensureMessageID(msgID)
	if media != nil {
		return []events.Event{customContent(id, *media)}
	}
	if !ok || text == "" {
		return nil
	}
	var result []events.Event
	result = append(result, b.closeReasoning()...)
	if b.messageOpen && msgID != nil && *msgID != b.messageID {
		result = append(result, b.closeMessage()...)
	}
	id = b.ensureMessageID(msgID)
	if !b.messageOpen {
		result = append(result, events.NewTextMessageStartEvent(id, events.WithRole(role)))
		b.messageOpen = true
		b.messageRole = role
	}
	return append(result, events.NewTextMessageContentEvent(id, text))
}
```

In `Update`, replace the `AgentMessageChunk` arm with `return b.messageChunk("assistant", u.AgentMessageChunk.MessageId, u.AgentMessageChunk.Content), nil`, add a `UserMessageChunk` arm `return b.messageChunk("user", u.UserMessageChunk.MessageId, u.UserMessageChunk.Content), nil`, and keep `AgentThoughtChunk` routed through the existing reasoning path (also via `renderContent` for media). Initialize `openTools: map[string]toolMeta{}` in `NewBridge`.

> Declare `type toolMeta struct{ title, kind, status string }` in **this** task (bridge.go) — `openTools` uses it now; Task 6 populates it. `NewBridge` initializes `openTools: map[string]toolMeta{}` and the `state projection`. This keeps the type owned by the task that first uses it (no forward reference).

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestBridge -v`
Expected: PASS (including the retained lifecycle test).

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/bridge.go services/pocketbase/internal/agent/agui/bridge_test.go
git commit -m "feat(agui): bridge handles user chunks + media, shared content path"
```

---

### Task 6: Bridge tool calls — single-shot fix, kind/locations/status, diff/terminal

**Files:**
- Modify: `services/pocketbase/internal/agent/agui/bridge.go`
- Test: `services/pocketbase/internal/agent/agui/bridge_test.go`

**Interfaces:**
- Consumes: `renderToolContent`, `customTool`, `customDiff`, `customTerminal`.
- Produces: `ToolCall`/`ToolCallUpdate` handling that (a) reads initial `Status`/`Content` (single-shot), (b) emits `pocketcoder:tool` with kind/locations/status, (c) emits `pocketcoder:{diff,terminal}` for structured results.

- [ ] **Step 1: Write the failing test**

```go
func TestBridgeSingleShotCompletedToolCall(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	status := acpsdk.ToolCallStatusCompleted
	evs, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call",
		ToolCallId:    "tc1", Title: "Read", Kind: acpsdk.ToolKindRead, Status: status,
		Content: []acpsdk.ToolCallContent{{Content: &acpsdk.ToolCallContentContent{Type: "content", Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "file body"}}}}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	types := eventTypes(evs)
	// must include START, ARGS(optional), RESULT, END — output not lost
	if !contains(types, "TOOL_CALL_START") || !contains(types, "TOOL_CALL_RESULT") || !contains(types, "TOOL_CALL_END") {
		t.Fatalf("single-shot must emit START+RESULT+END: %v", types)
	}
}

func TestBridgeToolUpdateDiffEmitsCustom(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	_, _ = bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call", ToolCallId: "tc2", Title: "Edit", Kind: acpsdk.ToolKindEdit,
	}})
	old := "a\n"
	done := acpsdk.ToolCallStatusCompleted
	evs, _ := bridge.Update(acpsdk.SessionUpdate{ToolCallUpdate: &acpsdk.SessionToolCallUpdate{
		SessionUpdate: "tool_call_update", ToolCallId: "tc2", Status: &done,
		Content: []acpsdk.ToolCallContent{{Diff: &acpsdk.ToolCallContentDiff{Path: "/f.go", OldText: &old, NewText: "b\n"}}},
	}})
	if !contains(eventTypes(evs), "CUSTOM") || !contains(eventTypes(evs), "TOOL_CALL_END") {
		t.Fatalf("diff update should emit CUSTOM + END: %v", eventTypes(evs))
	}
}

func TestBridgeToolCallMissingIDRaw(t *testing.T) {
	evs, err := (NewBridge("c", "r")).Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call", Title: "x", // no ToolCallId (flat struct — no nested acpsdk.ToolCall)
	}})
	if err != nil || len(evs) != 1 || evs[0].Type() != "RAW" {
		t.Fatalf("missing toolCallId → RAW to client, not error: %#v err=%v", evs, err)
	}
}

// helpers
func eventTypes(evs []events.Event) []string {
	var out []string
	for _, e := range evs {
		out = append(out, string(e.Type()))
	}
	return out
}
func contains(s []string, v string) bool {
	for _, x := range s {
		if x == v {
			return true
		}
	}
	return false
}
```
(Add `import "github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"` to the test file if not present.)

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run 'TestBridgeSingleShot|TestBridgeToolUpdateDiff' -v`
Expected: FAIL (single-shot leaks open tool, no RESULT; diff dropped).

- [ ] **Step 3: Write minimal implementation**

Replace the `ToolCall`/`ToolCallUpdate` arms. Sketch:

```go
// startTool handles an initial tool_call. `tc` is the FLAT SessionUpdate variant
// — fields (`ToolCallId`, `Title`, `Kind` non-ptr, `Status` non-ptr, `Content`,
// `RawInput`, `RawOutput`, `Locations`) live directly on it; there is NO nested
// acpsdk.ToolCall. (`toolMeta` is declared in Task 5.)
func (b *Bridge) startTool(tc *acpsdk.SessionUpdateToolCall) []events.Event {
	id := string(tc.ToolCallId)
	if id == "" { // soft miss: never abort the turn; surface as redacted RAW
		return []events.Event{rawEvent("tool_call", nil)}
	}
	var result []events.Event
	result = append(result, b.closeReasoning()...)
	result = append(result, b.closeMessage()...)
	result = append(result, events.NewToolCallStartEvent(id, tc.Title))
	if tc.RawInput != nil {
		if in, err := json.Marshal(tc.RawInput); err == nil {
			result = append(result, events.NewToolCallArgsEvent(id, string(in)))
		}
	}
	kind := string(tc.Kind)
	status := string(tc.Status)
	b.openTools[id] = toolMeta{title: tc.Title, kind: kind, status: status}
	result = append(result, customTool(id, tc.Title, kind, status, tc.Locations))
	// single-shot: initial content + terminal status → emit result + end now
	if len(tc.Content) > 0 {
		result = append(result, b.toolResult(id, tc.Content, tc.RawOutput)...)
	}
	if isTerminalToolStatus(status) {
		result = append(result, b.endTool(id)...)
	}
	return result
}

// updateTool handles tool_call_update. Its fields are POINTERS (partial update),
// unlike startTool's flat non-pointer struct — read-modify-write the retained meta.
func (b *Bridge) updateTool(u *acpsdk.SessionToolCallUpdate) []events.Event {
	id := string(u.ToolCallId)
	if id == "" {
		return []events.Event{rawEvent("tool_call_update", nil)}
	}
	var result []events.Event
	if u.RawInput != nil {
		if in, err := json.Marshal(u.RawInput); err == nil {
			result = append(result, events.NewToolCallArgsEvent(id, string(in)))
		}
	}
	if len(u.Content) > 0 {
		result = append(result, b.toolResult(id, u.Content, u.RawOutput)...)
	}
	meta := b.openTools[id] // zero value if the tool is unknown; still emit an update
	if u.Title != nil {
		meta.title = *u.Title
	}
	if u.Kind != nil {
		meta.kind = string(*u.Kind)
	}
	if u.Status != nil {
		meta.status = string(*u.Status)
	}
	b.openTools[id] = meta
	result = append(result, customTool(id, meta.title, meta.kind, meta.status, u.Locations))
	if u.Status != nil && isTerminalToolStatus(string(*u.Status)) {
		result = append(result, b.endTool(id)...)
	}
	return result
}

func (b *Bridge) toolResult(id string, content []acpsdk.ToolCallContent, rawOutput any) []events.Event {
	text, diffs, terms, has, err := renderToolContent(content, rawOutput)
	if err != nil {
		return []events.Event{rawEvent("tool_call_content", nil)}
	}
	var out []events.Event
	if has {
		out = append(out, events.NewToolCallResultEvent("tool-result-"+id, id, text))
	}
	for _, d := range diffs {
		out = append(out, customDiff(id, d))
	}
	for _, tm := range terms {
		out = append(out, customTerminal(id, tm))
	}
	return out
}

func (b *Bridge) endTool(id string) []events.Event {
	if _, open := b.openTools[id]; !open {
		return nil
	}
	delete(b.openTools, id)
	return []events.Event{events.NewToolCallEndEvent(id)}
}
```

Wire the dispatch arms in `Update`: `case u.ToolCall != nil: return b.startTool(u.ToolCall), nil` and `case u.ToolCallUpdate != nil: return b.updateTool(u.ToolCallUpdate), nil` (both fields are `*SessionUpdateToolCall`/`*SessionToolCallUpdate`). Update `Finished()` to iterate `openTools` (`map[string]toolMeta`) emitting `NewToolCallEndEvent(id)`. **Delete the now-dead `textContent`/`toolResultText` helpers** (`bridge.go:186-214`) — superseded by `renderContent`/`renderToolContent`.

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestBridge -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/bridge.go services/pocketbase/internal/agent/agui/bridge_test.go
git commit -m "feat(agui): robust tool calls (single-shot, kind/locations, diff/terminal)"
```

---

### Task 7: Bridge state-bearing variants + never-drop

**Files:**
- Modify: `services/pocketbase/internal/agent/agui/bridge.go`
- Test: `services/pocketbase/internal/agent/agui/bridge_test.go`

**Interfaces:**
- Consumes: `projection` (Task 4), `rawEvent` (Task 3).
- Produces: `Update` arms for `Plan`/`PlanUpdate`/`PlanRemoved`, `CurrentModeUpdate`, `ConfigOptionUpdate`, `AvailableCommandsUpdate`, `UsageUpdate`, `SessionInfoUpdate`, and unknown → `RAW`. Plus `PermissionPending`/`ElicitationPending` record projection state.

- [ ] **Step 1: Write the failing test**

```go
func TestBridgePlanAndModeAndUsageState(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	plan, _ := bridge.Update(acpsdk.SessionUpdate{Plan: &acpsdk.SessionUpdatePlan{
		SessionUpdate: "plan", Entries: []acpsdk.PlanEntry{{Content: "step 1", Priority: acpsdk.PlanEntryPriorityHigh, Status: acpsdk.PlanEntryStatusPending}},
	}})
	if len(plan) != 1 || plan[0].Type() != "STATE_DELTA" {
		t.Fatalf("plan: %#v", plan)
	}
	mode, _ := bridge.Update(acpsdk.SessionUpdate{CurrentModeUpdate: &acpsdk.SessionCurrentModeUpdate{SessionUpdate: "current_mode_update", CurrentModeId: "plan"}})
	if len(mode) != 1 || mode[0].Type() != "STATE_DELTA" {
		t.Fatalf("mode: %#v", mode)
	}
	usage, _ := bridge.Update(acpsdk.SessionUpdate{UsageUpdate: &acpsdk.SessionUsageUpdate{SessionUpdate: "usage_update", Size: 200000, Used: 1234}})
	if len(usage) != 1 || usage[0].Type() != "STATE_DELTA" {
		t.Fatalf("usage: %#v", usage)
	}
}

func TestBridgeConfigOptionUnion(t *testing.T) {
	bridge := NewBridge("c", "r")
	evs, err := bridge.Update(acpsdk.SessionUpdate{ConfigOptionUpdate: &acpsdk.SessionConfigOptionUpdate{
		SessionUpdate: "config_option_update",
		ConfigOptions: []acpsdk.SessionConfigOption{
			{Boolean: &acpsdk.SessionConfigOptionBoolean{Id: "b1", Name: "Verbose", CurrentValue: true}},
			{Select: &acpsdk.SessionConfigOptionSelect{Id: "s1", Name: "Model", CurrentValue: "fast"}},
		},
	}})
	if err != nil || len(evs) != 1 || evs[0].Type() != "STATE_DELTA" {
		t.Fatalf("config: %#v err=%v", evs, err)
	}
	b, _ := json.Marshal(evs[0])
	if !strings.Contains(string(b), `"kind":"boolean"`) || !strings.Contains(string(b), `"kind":"select"`) {
		t.Fatalf("config union not decoded: %s", string(b))
	}
}

func TestBridgeUnknownVariantRaw(t *testing.T) {
	// an all-nil SessionUpdate stands in for an unknown/vendor variant
	evs, err := (NewBridge("c", "r")).Update(acpsdk.SessionUpdate{})
	if err != nil || len(evs) != 1 || evs[0].Type() != "RAW" {
		t.Fatalf("unknown → RAW: %#v err=%v", evs, err)
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run 'TestBridgePlan|TestBridgeUnknown' -v`
Expected: FAIL (variants unhandled; all-nil returns nil not RAW).

- [ ] **Step 3: Write minimal implementation**

Add `Update` arms (all via `b.state.set(...)`), and a `default` returning `rawEvent`:

```go
case u.Plan != nil:
	return []events.Event{b.state.set("plan", map[string]any{"entries": planEntries(u.Plan.Entries)})}, nil
case u.PlanUpdate != nil:
	// Unstable ACP. Verify SessionPlanUpdate's shape at impl time: if it carries
	// entries, full-replace like Plan; otherwise surface as RAW (don't guess a merge).
	return []events.Event{rawEvent("plan_update", nil)}, nil
case u.PlanRemoved != nil:
	return []events.Event{b.state.remove("plan")}, nil
case u.CurrentModeUpdate != nil:
	return []events.Event{b.state.set("modes", map[string]any{"currentModeId": string(u.CurrentModeUpdate.CurrentModeId)})}, nil
case u.ConfigOptionUpdate != nil:
	return []events.Event{b.state.set("config", map[string]any{"options": configOptions(u.ConfigOptionUpdate.ConfigOptions)})}, nil
case u.AvailableCommandsUpdate != nil:
	return []events.Event{b.state.set("commands", commands(u.AvailableCommandsUpdate.AvailableCommands))}, nil
case u.UsageUpdate != nil:
	v := map[string]any{"size": u.UsageUpdate.Size, "used": u.UsageUpdate.Used}
	if u.UsageUpdate.Cost != nil { v["cost"] = map[string]any{"amount": u.UsageUpdate.Cost.Amount, "currency": u.UsageUpdate.Cost.Currency} }
	return []events.Event{b.state.set("usage", v)}, nil
case u.SessionInfoUpdate != nil:
	return []events.Event{b.state.set("session_info", map[string]any{"title": deref(u.SessionInfoUpdate.Title)})}, nil
```
```go
// default (no variant matched)
return []events.Event{rawEvent("session_update", nil)}, nil
```

**Rewrite `PermissionPending` to record projection state** (this is what makes Task 8's Snapshot-omits-resolved test reachable — the old `bridge.go:123` version is stateless). Signature is preserved (still returns one `events.Event`, which `run.go:197` consumes):
```go
func (b *Bridge) PermissionPending(requestID string, options []acpsdk.PermissionOption) events.Event {
	choices := make([]map[string]string, 0, len(options))
	for _, o := range options {
		choices = append(choices, map[string]string{"optionId": string(o.OptionId), "name": o.Name, "kind": string(o.Kind)})
	}
	// state.set stores it AND returns the STATE_DELTA (same event type as before).
	return b.state.set("permission", map[string]any{"requestId": requestID, "status": "pending", "options": choices})
}
```

Add the slice→`[]map[string]any` helpers:
```go
func planEntries(entries []acpsdk.PlanEntry) []map[string]any {
	out := make([]map[string]any, 0, len(entries))
	for _, e := range entries {
		out = append(out, map[string]any{"content": e.Content, "priority": string(e.Priority), "status": string(e.Status)})
	}
	return out
}
func commands(cmds []acpsdk.AvailableCommand) []map[string]any {
	out := make([]map[string]any, 0, len(cmds))
	for _, c := range cmds {
		out = append(out, map[string]any{"name": c.Name, "description": c.Description})
	}
	return out
}
// configOptions decodes ACP's discriminated union (Select | Boolean). Verify the
// Select/Boolean field names against types_gen.go:4486-4531 at impl time.
func configOptions(opts []acpsdk.SessionConfigOption) []map[string]any {
	out := make([]map[string]any, 0, len(opts))
	for _, o := range opts {
		switch {
		case o.Boolean != nil:
			out = append(out, map[string]any{"kind": "boolean", "id": string(o.Boolean.Id), "name": o.Boolean.Name, "currentValue": o.Boolean.CurrentValue})
		case o.Select != nil:
			out = append(out, map[string]any{"kind": "select", "id": string(o.Select.Id), "name": o.Select.Name, "currentValue": string(o.Select.CurrentValue)})
		}
	}
	return out
}
```
For `PlanUpdate` merge-vs-replace and `CurrentModeUpdate` (which should update only `currentModeId` while preserving `availableModes` seeded by `SeedSession`), store `modes` as a retained value and patch its `currentModeId` field rather than overwriting the whole namespace.

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run TestBridge -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/internal/agent/agui/bridge.go services/pocketbase/internal/agent/agui/bridge_test.go
git commit -m "feat(agui): plan/mode/config/commands/usage/session_info state + never-drop RAW"
```

---

### Task 8: `SeedSession`, `Snapshot`, `Resolve*`, side-channel invariant

**Files:**
- Modify: `services/pocketbase/internal/agent/agui/bridge.go`
- Test: `services/pocketbase/internal/agent/agui/bridge_test.go`

**Interfaces:**
- Produces the remaining public methods:
  ```go
  func (b *Bridge) SeedSession(modes *acpsdk.SessionModeState, config []acpsdk.SessionConfigOption) []events.Event
  func (b *Bridge) Snapshot() []events.Event
  func (b *Bridge) ResolvePermission(id string) []events.Event
  func (b *Bridge) ResolveElicitation(id string) []events.Event
  func (b *Bridge) ElicitationPending(id, message, mode string, schema any) events.Event
  ```

- [ ] **Step 1: Write the failing test**

```go
func TestBridgeSnapshotOmitsResolvedPermission(t *testing.T) {
	bridge := NewBridge("c", "r")
	bridge.PermissionPending("p1", nil)
	if snap := bridge.Snapshot(); len(snap) == 0 {
		t.Fatal("snapshot should include pending permission")
	}
	bridge.ResolvePermission("p1")
	for _, e := range bridge.Snapshot() {
		b, _ := json.Marshal(e)
		if strings.Contains(string(b), `"permission"`) {
			t.Fatalf("resolved permission must not appear in snapshot: %s", string(b))
		}
	}
}

func TestBridgeSeedSessionModes(t *testing.T) {
	bridge := NewBridge("c", "r")
	modes := &acpsdk.SessionModeState{CurrentModeId: "approve", AvailableModes: []acpsdk.SessionMode{{Id: "approve", Name: "Approve"}}}
	evs := bridge.SeedSession(modes, nil)
	if len(evs) == 0 || evs[0].Type() != "STATE_DELTA" {
		t.Fatalf("seed: %#v", evs)
	}
}

func TestBridgeStateDoesNotCloseOpenMessage(t *testing.T) {
	bridge := NewBridge("c", "r")
	mid := "m1"
	_, _ = bridge.Update(acpsdk.SessionUpdate{AgentMessageChunk: &acpsdk.SessionUpdateAgentMessageChunk{SessionUpdate: "agent_message_chunk", MessageId: &mid, Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "hi"}}}})
	evs, _ := bridge.Update(acpsdk.SessionUpdate{UsageUpdate: &acpsdk.SessionUsageUpdate{SessionUpdate: "usage_update", Size: 1, Used: 1}})
	if contains(eventTypes(evs), "TEXT_MESSAGE_END") {
		t.Fatal("a STATE emission must not close the open text message")
	}
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -run 'TestBridgeSnapshot|TestBridgeSeed|TestBridgeStateDoesNot' -v`
Expected: FAIL (undefined `SeedSession`/`Snapshot`/`ResolvePermission`).

- [ ] **Step 3: Write minimal implementation**

```go
func (b *Bridge) SeedSession(modes *acpsdk.SessionModeState, config []acpsdk.SessionConfigOption) []events.Event {
	var out []events.Event
	if modes != nil {
		out = append(out, b.state.set("modes", map[string]any{
			"currentModeId": string(modes.CurrentModeId), "availableModes": sessionModes(modes.AvailableModes),
		}))
	}
	if len(config) > 0 {
		out = append(out, b.state.set("config", map[string]any{"options": configOptions(config)}))
	}
	return out
}

func (b *Bridge) Snapshot() []events.Event { return b.state.snapshot() }

func (b *Bridge) ResolvePermission(id string) []events.Event {
	return []events.Event{b.state.remove("permission")}
}
func (b *Bridge) ResolveElicitation(id string) []events.Event {
	return []events.Event{b.state.remove("elicitation")}
}

func (b *Bridge) ElicitationPending(id, message, mode string, schema any) events.Event {
	return b.state.set("elicitation", map[string]any{"elicitationId": id, "message": message, "mode": mode, "requestedSchema": schema})
}
```
Add the `sessionModes` helper:
```go
func sessionModes(modes []acpsdk.SessionMode) []map[string]any {
	out := make([]map[string]any, 0, len(modes))
	for _, m := range modes {
		out = append(out, map[string]any{"id": string(m.Id), "name": m.Name, "description": deref(m.Description)})
	}
	return out
}
```
The side-channel test (`TestBridgeStateDoesNotCloseOpenMessage`) passes because `b.state.set` only appends a `STATE_DELTA` and never calls `closeMessage`/`closeReasoning`.

> `ResolvePermission`/`ResolveElicitation` take `id` for a future multi-pending model; v1 stores a single pending entry per namespace, so `remove` suffices. Keep the param for the coordinator's call-site stability.

- [ ] **Step 4: Run to verify it passes**

Run: `cd services/pocketbase && go test ./internal/agent/agui/ -v`
Expected: PASS (entire package).

- [ ] **Step 5: Full build + commit**

```bash
cd services/pocketbase && go build ./... && go vet ./internal/agent/agui/ && gofmt -l internal/agent/agui/
git add services/pocketbase/internal/agent/agui/
git commit -m "feat(agui): SeedSession, Snapshot, Resolve* + side-channel invariant"
```

---

## Final verification

- [ ] `cd services/pocketbase && go build ./...` — green (coordinator still compiles against preserved signatures).
- [ ] `go test ./internal/agent/agui/ -v` — all green; output pristine.
- [ ] `gofmt -l internal/agent/agui/` — empty.
- [ ] Every SDK field name used above verified against `acp-go-sdk@v0.13.5/types_gen.go` during implementation (image `Uri`, `ContentBlockResourceLink`, `ToolCallContentDiff.OldText *string`, `SessionUsageUpdate.{Size,Used,Cost}`, `SessionMode.{Id,Name,Description}`, `PlanEntry.{Content,Priority,Status}`).
- [ ] Coverage checklist vs spec: 13 `SessionUpdate` variants + `RAW` default; 5 `ContentBlock`; 3 `ToolCallContent`; single-shot; soft-miss→RAW-to-client; user-message replay; Snapshot omits resolved; side-channel doesn't perturb text.

**Out of scope (c1↔c2 bridge plan):** coordinator wiring — calling `SeedSession` on run init, treating `Update` soft-misses as non-fatal, calling `Resolve*` on approve/cancel/timeout, and `Snapshot()` on subscriber attach.
