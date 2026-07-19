package agui

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
)

func TestBridgeMessageLifecycleAndTerminal(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	messageID := "agent-message-1"
	update := acpsdk.SessionUpdate{AgentMessageChunk: &acpsdk.SessionUpdateAgentMessageChunk{
		SessionUpdate: "agent_message_chunk",
		MessageId:     &messageID,
		Content:       acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "hello"}},
	}}

	events, err := bridge.Update(update)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 2 || events[0].Type() != "TEXT_MESSAGE_START" || events[1].Type() != "TEXT_MESSAGE_CONTENT" {
		t.Fatalf("unexpected chunk events: %#v", events)
	}
	finished := bridge.Finished(acpsdk.StopReasonEndTurn)
	if len(finished) != 2 || finished[0].Type() != "TEXT_MESSAGE_END" || finished[1].Type() != "RUN_FINISHED" {
		t.Fatalf("unexpected terminal events: %#v", finished)
	}
}

func TestBridgePermissionState(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	event := bridge.PermissionPending("rpc-42", nil)
	b, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	want := `"type":"STATE_DELTA"`
	if !strings.Contains(string(b), want) || !strings.Contains(string(b), `"requestId":"rpc-42"`) {
		t.Fatalf("permission event = %s", b)
	}
}

// TestBridgeEmitsToolResultBeforeEnd covers the legacy two-shot sequence
// (start without status, update with status + content). The new semantics
// still emit TOOL_CALL_RESULT before TOOL_CALL_END on a terminal update, so
// clients that consume that ordering keep working; a CUSTOM pocketcoder:tool
// event now lands between them carrying the tool's kind/status/locations
// (never-drop: every tool_call_update surfaces its metadata, not just start).
func TestBridgeEmitsToolResultBeforeEnd(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	start := acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call",
		ToolCallId:    "tool-1",
		Title:         "read_file",
	}}
	if _, err := bridge.Update(start); err != nil {
		t.Fatal(err)
	}
	status := acpsdk.ToolCallStatusCompleted
	update := acpsdk.SessionUpdate{ToolCallUpdate: &acpsdk.SessionToolCallUpdate{
		SessionUpdate: "tool_call_update",
		ToolCallId:    "tool-1",
		Status:        &status,
		Content: []acpsdk.ToolCallContent{{Content: &acpsdk.ToolCallContentContent{
			Type:    "content",
			Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "file body"}},
		}}},
	}}
	evs, err := bridge.Update(update)
	if err != nil {
		t.Fatal(err)
	}
	if len(evs) != 3 || evs[0].Type() != "TOOL_CALL_RESULT" || evs[1].Type() != "CUSTOM" || evs[2].Type() != "TOOL_CALL_END" {
		t.Fatalf("unexpected tool result events: %#v", evs)
	}
	b, err := json.Marshal(evs[0])
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), "file body") || !strings.Contains(string(b), `"toolCallId":"tool-1"`) {
		t.Fatalf("tool result payload = %s", b)
	}
}

func TestBridgeEmitsReasoningLifecycle(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	thoughtID := "thought-1"
	update := acpsdk.SessionUpdate{AgentThoughtChunk: &acpsdk.SessionUpdateAgentThoughtChunk{
		SessionUpdate: "agent_thought_chunk",
		MessageId:     &thoughtID,
		Content:       acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "let me think"}},
	}}
	events, err := bridge.Update(update)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 2 || events[0].Type() != "REASONING_MESSAGE_START" || events[1].Type() != "REASONING_MESSAGE_CONTENT" {
		t.Fatalf("unexpected reasoning events: %#v", events)
	}
	finished := bridge.Finished(acpsdk.StopReasonEndTurn)
	if len(finished) == 0 || finished[0].Type() != "REASONING_MESSAGE_END" {
		t.Fatalf("expected reasoning end first on finish: %#v", finished)
	}
}

func TestBridgeClosesReasoningWhenAgentMessageStarts(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	thoughtID := "thought-1"
	if _, err := bridge.Update(acpsdk.SessionUpdate{AgentThoughtChunk: &acpsdk.SessionUpdateAgentThoughtChunk{
		SessionUpdate: "agent_thought_chunk",
		MessageId:     &thoughtID,
		Content:       acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "thinking"}},
	}}); err != nil {
		t.Fatal(err)
	}
	messageID := "agent-message-1"
	events, err := bridge.Update(acpsdk.SessionUpdate{AgentMessageChunk: &acpsdk.SessionUpdateAgentMessageChunk{
		SessionUpdate: "agent_message_chunk",
		MessageId:     &messageID,
		Content:       acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "answer"}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 3 || events[0].Type() != "REASONING_MESSAGE_END" || events[1].Type() != "TEXT_MESSAGE_START" {
		t.Fatalf("expected reasoning to close before text: %#v", events)
	}
}

func TestBridgeClosesPreviousMessageBeforeNewMessage(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	firstID := "agent-message-1"
	secondID := "agent-message-2"
	chunk := func(id *string) acpsdk.SessionUpdate {
		return acpsdk.SessionUpdate{AgentMessageChunk: &acpsdk.SessionUpdateAgentMessageChunk{
			SessionUpdate: "agent_message_chunk",
			MessageId:     id,
			Content:       acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "hello"}},
		}}
	}
	if _, err := bridge.Update(chunk(&firstID)); err != nil {
		t.Fatal(err)
	}
	events, err := bridge.Update(chunk(&secondID))
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 3 || events[0].Type() != "TEXT_MESSAGE_END" || events[1].Type() != "TEXT_MESSAGE_START" {
		t.Fatalf("unexpected message switch events: %#v", events)
	}
}

// TestBridgeUserMessageChunkReplay covers the UserMessageChunk arm added in
// Task 5: a user chunk must replay as a TEXT_MESSAGE_START (role=user) +
// TEXT_MESSAGE_CONTENT pair, mirroring the agent chunk shape but with the
// "user" role so Flutter can render replayed inputs verbatim.
func TestBridgeUserMessageChunkReplay(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	mid := "user-1"
	evs, err := bridge.Update(acpsdk.SessionUpdate{UserMessageChunk: &acpsdk.SessionUpdateUserMessageChunk{
		SessionUpdate: "user_message_chunk",
		MessageId:     &mid,
		Content:       acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "do X"}},
	}})
	if err != nil {
		t.Fatalf("user chunk error: %v", err)
	}
	if len(evs) != 2 {
		t.Fatalf("expected 2 events, got %#v", evs)
	}
	if evs[0].Type() != "TEXT_MESSAGE_START" {
		t.Fatalf("event 0 type = %s, want TEXT_MESSAGE_START", evs[0].Type())
	}
	if evs[1].Type() != "TEXT_MESSAGE_CONTENT" {
		t.Fatalf("event 1 type = %s, want TEXT_MESSAGE_CONTENT", evs[1].Type())
	}
	b, err := json.Marshal(evs[0])
	if err != nil {
		t.Fatalf("marshal start: %v", err)
	}
	if !strings.Contains(string(b), `"role":"user"`) {
		t.Fatalf("expected user role in start payload: %s", string(b))
	}
}

// TestBridgeAgentImageEmitsContentCustom covers Task 5's media path on the
// agent side: an image content block must produce a CUSTOM pocketcoder:content
// event instead of opening a text scope, with image metadata preserved.
func TestBridgeAgentImageEmitsContentCustom(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	mid := "m1"
	uri := "https://x/y.png"
	evs, err := bridge.Update(acpsdk.SessionUpdate{AgentMessageChunk: &acpsdk.SessionUpdateAgentMessageChunk{
		SessionUpdate: "agent_message_chunk",
		MessageId:     &mid,
		Content:       acpsdk.ContentBlock{Image: &acpsdk.ContentBlockImage{Type: "image", MimeType: "image/png", Uri: &uri}},
	}})
	if err != nil {
		t.Fatalf("image chunk error: %v", err)
	}
	found := false
	for _, e := range evs {
		if e.Type() == "CUSTOM" {
			found = true
			b, _ := json.Marshal(e)
			if !strings.Contains(string(b), `"pocketcoder:content"`) {
				t.Fatalf("custom event missing pocketcoder:content name: %s", string(b))
			}
			if !strings.Contains(string(b), `"kind":"image"`) {
				t.Fatalf("custom event missing kind=image: %s", string(b))
			}
			if !strings.Contains(string(b), `"uri":"https://x/y.png"`) {
				t.Fatalf("custom event missing uri: %s", string(b))
			}
		}
		if e.Type() == "TEXT_MESSAGE_START" {
			t.Fatalf("media chunk must not open TEXT_MESSAGE scope: got %#v", evs)
		}
	}
	if !found {
		t.Fatalf("image chunk should emit CUSTOM pocketcoder:content, got %#v", evs)
	}
}

// TestBridgeSingleShotCompletedToolCall covers Task 6's single-shot fix: ACP
// can deliver a tool_call already in a terminal state with content. The bridge
// must emit START, RESULT, and END in one burst so the output is never lost
// (the old code only tracked the tool as open and waited for an update that
// never came).
func TestBridgeSingleShotCompletedToolCall(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	status := acpsdk.ToolCallStatusCompleted
	evs, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call",
		ToolCallId:    "tc1",
		Title:         "Read",
		Kind:          acpsdk.ToolKindRead,
		Status:        status,
		Content: []acpsdk.ToolCallContent{{Content: &acpsdk.ToolCallContentContent{
			Type:    "content",
			Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "file body"}},
		}}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	types := eventTypes(evs)
	if !contains(types, "TOOL_CALL_START") || !contains(types, "TOOL_CALL_RESULT") || !contains(types, "TOOL_CALL_END") {
		t.Fatalf("single-shot must emit START+RESULT+END: %v", types)
	}
}

// TestBridgeToolUpdateDiffEmitsCustom covers the structured diff path: a
// tool_call_update carrying a diff content block must surface a CUSTOM
// pocketcoder:diff event AND close the tool with TOOL_CALL_END when the
// status is terminal.
func TestBridgeToolUpdateDiffEmitsCustom(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	if _, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call",
		ToolCallId:    "tc2",
		Title:         "Edit",
		Kind:          acpsdk.ToolKindEdit,
	}}); err != nil {
		t.Fatal(err)
	}
	old := "a\n"
	done := acpsdk.ToolCallStatusCompleted
	evs, err := bridge.Update(acpsdk.SessionUpdate{ToolCallUpdate: &acpsdk.SessionToolCallUpdate{
		SessionUpdate: "tool_call_update",
		ToolCallId:    "tc2",
		Status:        &done,
		Content: []acpsdk.ToolCallContent{{Diff: &acpsdk.ToolCallContentDiff{
			Path:    "/f.go",
			OldText: &old,
			NewText: "b\n",
		}}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	types := eventTypes(evs)
	if !contains(types, "CUSTOM") || !contains(types, "TOOL_CALL_END") {
		t.Fatalf("diff update should emit CUSTOM + END: %v", types)
	}
}

// TestBridgeToolCallMissingIDRaw covers the soft-miss case: a tool_call with
// no ToolCallId must surface as a single redacted RAW event rather than an
// error, so a single malformed update doesn't abort the whole turn.
func TestBridgeToolCallMissingIDRaw(t *testing.T) {
	evs, err := (NewBridge("c", "r")).Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call",
		Title:         "x", // no ToolCallId (flat struct — no nested acpsdk.ToolCall)
	}})
	if err != nil {
		t.Fatalf("missing toolCallId must not error: %v", err)
	}
	if len(evs) != 1 || evs[0].Type() != "RAW" {
		t.Fatalf("missing toolCallId → RAW to client, not error: %#v err=%v", evs, err)
	}
}

// TestBridgePlanAndModeAndUsageState covers Task 7's state-bearing Update
// arms: Plan / CurrentModeUpdate / UsageUpdate must each surface as a single
// STATE_DELTA carrying the corresponding /pocketcoder/* namespace. The
// existing Task 5/6 tests already exercised message/tool paths; this pins the
// projection wiring so a regression in b.state.set dispatch is caught.
func TestBridgePlanAndModeAndUsageState(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	plan, _ := bridge.Update(acpsdk.SessionUpdate{Plan: &acpsdk.SessionUpdatePlan{
		SessionUpdate: "plan",
		Entries: []acpsdk.PlanEntry{{
			Content:  "step 1",
			Priority: acpsdk.PlanEntryPriorityHigh,
			Status:   acpsdk.PlanEntryStatusPending,
		}},
	}})
	if len(plan) != 1 || plan[0].Type() != "STATE_DELTA" {
		t.Fatalf("plan: %#v", plan)
	}
	mode, _ := bridge.Update(acpsdk.SessionUpdate{CurrentModeUpdate: &acpsdk.SessionCurrentModeUpdate{
		SessionUpdate: "current_mode_update",
		CurrentModeId: "plan",
	}})
	if len(mode) != 1 || mode[0].Type() != "STATE_DELTA" {
		t.Fatalf("mode: %#v", mode)
	}
	usage, _ := bridge.Update(acpsdk.SessionUpdate{UsageUpdate: &acpsdk.SessionUsageUpdate{
		SessionUpdate: "usage_update",
		Size:          200000,
		Used:          1234,
	}})
	if len(usage) != 1 || usage[0].Type() != "STATE_DELTA" {
		t.Fatalf("usage: %#v", usage)
	}
}

// TestBridgeConfigOptionUnion covers the ACP discriminated-union decode:
// a ConfigOptionUpdate carrying both a Boolean and a Select option must
// produce one STATE_DELTA whose payload preserves the kind discriminator
// for each entry, so the client can rebuild either a checkbox or a dropdown.
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

// TestBridgeUnknownVariantRaw covers the never-drop default: an all-nil
// SessionUpdate stands in for an unknown / vendor / future variant, and must
// surface as a single redacted RAW event rather than silently returning nil
// (which would otherwise be dropped on the wire).
func TestBridgeUnknownVariantRaw(t *testing.T) {
	evs, err := (NewBridge("c", "r")).Update(acpsdk.SessionUpdate{})
	if err != nil || len(evs) != 1 || evs[0].Type() != "RAW" {
		t.Fatalf("unknown → RAW: %#v err=%v", evs, err)
	}
}

// helpers

// eventTypes flattens an event slice to its Type() strings for easy
// substring-presence checks in tests.
func eventTypes(evs []events.Event) []string {
	out := make([]string, 0, len(evs))
	for _, e := range evs {
		out = append(out, string(e.Type()))
	}
	return out
}

// contains is a tiny linear search helper — stdlib slices.Contains isn't in
// the supported toolchain baseline for this package's tests.
func contains(s []string, v string) bool {
	for _, x := range s {
		if x == v {
			return true
		}
	}
	return false
}

// TestBridgeSnapshotOmitsResolvedPermission covers Task 8's Snapshot invariant:
// a permission recorded via PermissionPending shows up in Snapshot, and after
// ResolvePermission it must be gone. This is the test that required Task 7's
// PermissionPending rewrite to route through b.state.set (so the value is
// retained rather than emitted-and-forgotten).
func TestBridgeSnapshotOmitsResolvedPermission(t *testing.T) {
	bridge := NewBridge("c", "r")
	bridge.PermissionPending("p1", nil)
	snap := bridge.Snapshot()
	if len(snap) == 0 {
		t.Fatal("snapshot should include pending permission")
	}
	sawPermission := false
	for _, e := range snap {
		b, _ := json.Marshal(e)
		if strings.Contains(string(b), `"permission"`) {
			sawPermission = true
		}
	}
	if !sawPermission {
		t.Fatalf("pending permission should appear in snapshot: %v", snap)
	}
	bridge.ResolvePermission("p1")
	for _, e := range bridge.Snapshot() {
		b, _ := json.Marshal(e)
		if strings.Contains(string(b), `"permission"`) {
			t.Fatalf("resolved permission must not appear in snapshot: %s", string(b))
		}
	}
}

// TestBridgeSeedSessionModes covers Task 8's SeedSession: a non-nil
// SessionModeState must produce at least one STATE_DELTA event carrying the
// currentModeId + availableModes shape so subscribers can render the initial
// mode dropdown before any CurrentModeUpdate arrives.
func TestBridgeSeedSessionModes(t *testing.T) {
	bridge := NewBridge("c", "r")
	modes := &acpsdk.SessionModeState{
		CurrentModeId: "approve",
		AvailableModes: []acpsdk.SessionMode{
			{Id: "approve", Name: "Approve"},
		},
	}
	evs := bridge.SeedSession(modes, nil)
	if len(evs) == 0 || evs[0].Type() != "STATE_DELTA" {
		t.Fatalf("seed: %#v", evs)
	}
	b, _ := json.Marshal(evs[0])
	if !strings.Contains(string(b), `/pocketcoder/modes`) || !strings.Contains(string(b), `"currentModeId":"approve"`) {
		t.Fatalf("seed payload missing modes/currentModeId: %s", string(b))
	}
}

// TestBridgeStateDoesNotCloseOpenMessage covers the side-channel invariant:
// emitting a STATE_DELTA (via UsageUpdate → b.state.set) must NOT close the
// currently-open TEXT_MESSAGE. The text machine's open/close lifecycle is
// scoped to message/reasoning/tool calls only; state events ride alongside
// without disturbing them. This is the regression guard the plan calls out:
// "side-channels don't perturb the text machine."
func TestBridgeStateDoesNotCloseOpenMessage(t *testing.T) {
	bridge := NewBridge("c", "r")
	mid := "m1"
	if _, err := bridge.Update(acpsdk.SessionUpdate{AgentMessageChunk: &acpsdk.SessionUpdateAgentMessageChunk{
		SessionUpdate: "agent_message_chunk",
		MessageId:     &mid,
		Content:       acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "hi"}},
	}}); err != nil {
		t.Fatal(err)
	}
	evs, err := bridge.Update(acpsdk.SessionUpdate{UsageUpdate: &acpsdk.SessionUsageUpdate{
		SessionUpdate: "usage_update",
		Size:          1,
		Used:          1,
	}})
	if err != nil {
		t.Fatal(err)
	}
	if contains(eventTypes(evs), "TEXT_MESSAGE_END") {
		t.Fatal("a STATE emission must not close the open text message")
	}
}

// TestFinishedSuccessOnEndTurn covers Task 8's success path: when the run
// stops with StopReasonEndTurn, the trailing RUN_FINISHED carries the success
// outcome (the default pre-Task-8 behavior), not a Result map.
func TestFinishedSuccessOnEndTurn(t *testing.T) {
	b := NewBridge("chat", "run")
	evs := b.Finished(acpsdk.StopReasonEndTurn)
	if len(evs) == 0 || evs[len(evs)-1].Type() != events.EventTypeRunFinished {
		t.Fatalf("expected trailing RUN_FINISHED, got %v", evs)
	}
	fin := evs[len(evs)-1].(*events.RunFinishedEvent)
	if fin.Result != nil {
		t.Fatalf("end_turn stop must not attach a Result, got %#v", fin.Result)
	}
}

// TestFinishedCarriesStopReasonOnNonEndTurn covers Task 8's non-success path:
// any stop reason other than EndTurn must produce a RUN_FINISHED that attaches
// a Result carrying the stopReason, so clients can distinguish refusal /
// max-tokens / cancelled from a clean end-of-turn.
func TestFinishedCarriesStopReasonOnNonEndTurn(t *testing.T) {
	b := NewBridge("chat", "run")
	evs := b.Finished(acpsdk.StopReasonRefusal)
	if len(evs) == 0 || evs[len(evs)-1].Type() != events.EventTypeRunFinished {
		t.Fatalf("expected RUN_FINISHED on refusal, got %v", evs)
	}
	fin := evs[len(evs)-1].(*events.RunFinishedEvent)
	if fin.Result == nil {
		t.Fatal("non-end_turn stop must attach a Result carrying the stopReason")
	}
	reason, _ := fin.Result["stopReason"].(string)
	if reason != string(acpsdk.StopReasonRefusal) {
		t.Fatalf("Result.stopReason = %q, want %q", reason, acpsdk.StopReasonRefusal)
	}
}
