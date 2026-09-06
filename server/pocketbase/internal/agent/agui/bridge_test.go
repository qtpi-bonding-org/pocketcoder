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
	event := bridge.PermissionPending("rpc-42", nil, "", nil, nil)
	b, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	want := `"type":"STATE_DELTA"`
	if !strings.Contains(string(b), want) || !strings.Contains(string(b), `"requestId":"rpc-42"`) {
		t.Fatalf("permission event = %s", b)
	}
}

// TestBridgePermissionStateCarriesToolCallID covers the fix for the
// ACP->AG-UI field-drop audit finding: RequestPermissionRequest.ToolCall
// carries the id of the tool call this permission gates, and it must reach
// the client so the phone can correlate a pending permission with its tool
// call (rather than only being able to append it at the end of the
// timeline). Absent id is a no-op (tested above): the key must not appear
// at all rather than surfacing as an empty string.
func TestBridgePermissionStateCarriesToolCallID(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	event := bridge.PermissionPending("rpc-42", nil, "tool-7", nil, nil)
	b, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), `"toolCallId":"tool-7"`) {
		t.Fatalf("permission event missing toolCallId: %s", b)
	}
	event2 := bridge.PermissionPending("rpc-43", nil, "", nil, nil)
	b2, err := json.Marshal(event2)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(b2), `toolCallId`) {
		t.Fatalf("permission event should omit toolCallId when absent: %s", b2)
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

// TestBridgePlanUpdateUnion covers SessionPlanUpdate's discriminated union
// (Items | File | Markdown). Items carries a full entry list and must
// full-replace the /pocketcoder/plan projection the same way Plan does; File
// and Markdown have no entries shape, so they're projected under their own
// keys instead of falling back to RAW.
func TestBridgePlanUpdateUnion(t *testing.T) {
	bridge := NewBridge("c", "r")

	items, err := bridge.Update(acpsdk.SessionUpdate{PlanUpdate: &acpsdk.SessionPlanUpdate{
		SessionUpdate: "plan_update",
		Plan: acpsdk.PlanUpdateContent{Items: &acpsdk.PlanUpdateContentItems{
			Type: "items",
			Entries: []acpsdk.PlanEntry{{
				Content:  "step 1",
				Priority: acpsdk.PlanEntryPriorityHigh,
				Status:   acpsdk.PlanEntryStatusPending,
			}},
		}},
	}})
	if err != nil || len(items) != 1 || items[0].Type() != "STATE_DELTA" {
		t.Fatalf("items: %#v err=%v", items, err)
	}
	b, _ := json.Marshal(items[0])
	if !strings.Contains(string(b), `"content":"step 1"`) {
		t.Fatalf("plan_update items not decoded: %s", string(b))
	}

	file, err := bridge.Update(acpsdk.SessionUpdate{PlanUpdate: &acpsdk.SessionPlanUpdate{
		SessionUpdate: "plan_update",
		Plan:          acpsdk.PlanUpdateContent{File: &acpsdk.PlanUpdateContentFile{Type: "file", Uri: "file:///plan.md"}},
	}})
	if err != nil || len(file) != 1 || file[0].Type() != "STATE_DELTA" {
		t.Fatalf("file: %#v err=%v", file, err)
	}
	b, _ = json.Marshal(file[0])
	if !strings.Contains(string(b), `"uri":"file:///plan.md"`) {
		t.Fatalf("plan_update file not decoded: %s", string(b))
	}

	md, err := bridge.Update(acpsdk.SessionUpdate{PlanUpdate: &acpsdk.SessionPlanUpdate{
		SessionUpdate: "plan_update",
		Plan:          acpsdk.PlanUpdateContent{Markdown: &acpsdk.PlanUpdateContentMarkdown{Type: "markdown", Content: "# Plan"}},
	}})
	if err != nil || len(md) != 1 || md[0].Type() != "STATE_DELTA" {
		t.Fatalf("markdown: %#v err=%v", md, err)
	}
	b, _ = json.Marshal(md[0])
	if !strings.Contains(string(b), `"markdown":"# Plan"`) {
		t.Fatalf("plan_update markdown not decoded: %s", string(b))
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

// TestBridgeConfigSelectOptionsAndDescription covers the fix for the
// ACP->AG-UI field-drop audit finding: a select-type config option's
// candidate values (SessionConfigOptionSelect.Options) were never forwarded,
// so the client had a dropdown control with nothing to select from.
// Description/Category (both boolean and select) were dropped too.
func TestBridgeConfigSelectOptionsAndDescription(t *testing.T) {
	bridge := NewBridge("c", "r")
	desc := "Controls response verbosity"
	category := acpsdk.SessionConfigOptionCategoryMode
	optDesc := "Fastest, least capable"
	ungrouped := acpsdk.SessionConfigSelectOptionsUngrouped{
		{Name: "Fast", Value: "fast", Description: &optDesc},
		{Name: "Slow", Value: "slow"},
	}
	evs, err := bridge.Update(acpsdk.SessionUpdate{ConfigOptionUpdate: &acpsdk.SessionConfigOptionUpdate{
		SessionUpdate: "config_option_update",
		ConfigOptions: []acpsdk.SessionConfigOption{
			{Boolean: &acpsdk.SessionConfigOptionBoolean{Id: "b1", Name: "Verbose", CurrentValue: true, Description: &desc}},
			{Select: &acpsdk.SessionConfigOptionSelect{
				Id: "s1", Name: "Model", CurrentValue: "fast", Category: &category,
				Options: acpsdk.SessionConfigSelectOptions{Ungrouped: &ungrouped},
			}},
		},
	}})
	if err != nil || len(evs) != 1 {
		t.Fatalf("config: %#v err=%v", evs, err)
	}
	b, _ := json.Marshal(evs[0])
	s := string(b)
	for _, want := range []string{
		`"description":"Controls response verbosity"`,
		`"category":"mode"`,
		`"name":"Fast"`,
		`"value":"fast"`,
		`"description":"Fastest, least capable"`,
		`"name":"Slow"`,
		`"value":"slow"`,
	} {
		if !strings.Contains(s, want) {
			t.Fatalf("config event missing %s: %s", want, s)
		}
	}
}

// TestBridgeAvailableCommandsForwardsHint covers the fix for the ACP->AG-UI
// field-drop audit finding: AvailableCommand.Input.Hint (the placeholder
// text for a command's argument, e.g. "/model <name>") was never read.
func TestBridgeAvailableCommandsForwardsHint(t *testing.T) {
	bridge := NewBridge("c", "r")
	evs, err := bridge.Update(acpsdk.SessionUpdate{AvailableCommandsUpdate: &acpsdk.SessionAvailableCommandsUpdate{
		SessionUpdate: "available_commands_update",
		AvailableCommands: []acpsdk.AvailableCommand{
			{
				Name:        "model",
				Description: "Switch the active model",
				Input:       &acpsdk.AvailableCommandInput{Unstructured: &acpsdk.UnstructuredCommandInput{Hint: "model name"}},
			},
			{Name: "help", Description: "Show help"},
		},
	}})
	if err != nil || len(evs) != 1 {
		t.Fatalf("commands: %#v err=%v", evs, err)
	}
	b, _ := json.Marshal(evs[0])
	if !strings.Contains(string(b), `"hint":"model name"`) {
		t.Fatalf("commands event missing hint: %s", b)
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

func TestBridgeDefersResultUntilTerminal(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	inProgress := acpsdk.ToolCallStatusInProgress
	evs, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call", ToolCallId: "tc-defer", Title: "Bash", Status: inProgress,
		Content: []acpsdk.ToolCallContent{{Content: &acpsdk.ToolCallContentContent{
			Type: "content", Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "Sleeping..."}},
		}}},
	}})
	if err != nil {
		t.Fatal(err)
	}
	types := eventTypes(evs)
	if !contains(types, "TOOL_CALL_START") || contains(types, "TOOL_CALL_RESULT") || contains(types, "TOOL_CALL_END") {
		t.Fatalf("unexpected in-progress events: %v", types)
	}
}

func TestBridgeEmitsDeferredResultOnceTerminal(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	inProgress := acpsdk.ToolCallStatusInProgress
	if _, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call", ToolCallId: "tc-defer2", Title: "Bash", Status: inProgress,
		Content: []acpsdk.ToolCallContent{{Content: &acpsdk.ToolCallContentContent{Type: "content", Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "Sleeping_Close"}}}}},
	}}); err != nil {
		t.Fatal(err)
	}
	done := acpsdk.ToolCallStatusCompleted
	evs, err := bridge.Update(acpsdk.SessionUpdate{ToolCallUpdate: &acpsdk.SessionToolCallUpdate{SessionUpdate: "tool_call_update", ToolCallId: "tc-defer2", Status: &done}})
	if err != nil {
		t.Fatal(err)
	}
	types := eventTypes(evs)
	if !contains(types, "TOOL_CALL_RESULT") || !contains(types, "TOOL_CALL_END") {
		t.Fatalf("expected result and end: %v", types)
	}
	var resultEvent events.Event
	for _, e := range evs {
		if e.Type() == "TOOL_CALL_RESULT" {
			resultEvent = e
		}
	}
	b, err := json.Marshal(resultEvent)
	if err != nil || !strings.Contains(string(b), "Sleeping_Close") {
		t.Fatalf("deferred result: %s", b)
	}
}

func TestBridgeNewerContentOverridesPendingResult(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	inProgress := acpsdk.ToolCallStatusInProgress
	start := acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{SessionUpdate: "tool_call", ToolCallId: "tc-defer3", Title: "Bash", Status: inProgress, Content: []acpsdk.ToolCallContent{{Content: &acpsdk.ToolCallContentContent{Type: "content", Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "first chunk"}}}}}}}
	if _, err := bridge.Update(start); err != nil {
		t.Fatal(err)
	}
	stillGoing := acpsdk.ToolCallStatusInProgress
	if _, err := bridge.Update(acpsdk.SessionUpdate{ToolCallUpdate: &acpsdk.SessionToolCallUpdate{SessionUpdate: "tool_call_update", ToolCallId: "tc-defer3", Status: &stillGoing, Content: []acpsdk.ToolCallContent{{Content: &acpsdk.ToolCallContentContent{Type: "content", Content: acpsdk.ContentBlock{Text: &acpsdk.ContentBlockText{Type: "text", Text: "final chunk"}}}}}}}); err != nil {
		t.Fatal(err)
	}
	done := acpsdk.ToolCallStatusCompleted
	evs, err := bridge.Update(acpsdk.SessionUpdate{ToolCallUpdate: &acpsdk.SessionToolCallUpdate{SessionUpdate: "tool_call_update", ToolCallId: "tc-defer3", Status: &done}})
	if err != nil {
		t.Fatal(err)
	}
	var resultEvent events.Event
	for _, e := range evs {
		if e.Type() == "TOOL_CALL_RESULT" {
			resultEvent = e
		}
	}
	if resultEvent == nil {
		t.Fatalf("expected deferred result: %v", eventTypes(evs))
	}
	b, _ := json.Marshal(resultEvent)
	if strings.Contains(string(b), "first chunk") || !strings.Contains(string(b), "final chunk") {
		t.Fatalf("wrong result: %s", b)
	}
}

func TestBridgeProgressDiffsStillEmitImmediately(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	if _, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{SessionUpdate: "tool_call", ToolCallId: "tc-defer4", Title: "Edit", Kind: acpsdk.ToolKindEdit}}); err != nil {
		t.Fatal(err)
	}
	inProgress := acpsdk.ToolCallStatusInProgress
	old := "a\n"
	evs, err := bridge.Update(acpsdk.SessionUpdate{ToolCallUpdate: &acpsdk.SessionToolCallUpdate{SessionUpdate: "tool_call_update", ToolCallId: "tc-defer4", Status: &inProgress, Content: []acpsdk.ToolCallContent{{Diff: &acpsdk.ToolCallContentDiff{Path: "/f.go", OldText: &old, NewText: "b\n"}}}}})
	if err != nil {
		t.Fatal(err)
	}
	types := eventTypes(evs)
	if !contains(types, "CUSTOM") || contains(types, "TOOL_CALL_END") || contains(types, "TOOL_CALL_RESULT") {
		t.Fatalf("unexpected progress: %v", types)
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
	bridge.PermissionPending("p1", nil, "", nil, nil)
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
	resultMap, ok := fin.Result.(map[string]any)
	if !ok {
		t.Fatalf("Result = %#v, want map[string]any", fin.Result)
	}
	reason, _ := resultMap["stopReason"].(string)
	if reason != string(acpsdk.StopReasonRefusal) {
		t.Fatalf("Result.stopReason = %q, want %q", reason, acpsdk.StopReasonRefusal)
	}
}

// TestBridgeElicitationPendingCarriesURL covers the fix for the ACP->AG-UI
// field-drop audit finding: a URL-mode elicitation (UnstableCreateElicitationRequest.Url)
// was reaching the bridge with mode="url" but no message/url, making the
// feature non-functional on the client. ElicitationPending must forward the
// url so the client has something to show/act on; empty url must not add
// the key (mirrors PermissionPending's toolCallId omission).
func TestBridgeElicitationPendingCarriesURL(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	event := bridge.ElicitationPending("elicit-1", "Please authorize in your browser", "url", nil, "https://example.com/auth")
	b, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), `"url":"https://example.com/auth"`) {
		t.Fatalf("elicitation event missing url: %s", b)
	}
	if !strings.Contains(string(b), `"message":"Please authorize in your browser"`) {
		t.Fatalf("elicitation event missing message: %s", b)
	}

	formEvent := bridge.ElicitationPending("elicit-2", "form message", "form", map[string]any{"type": "object"}, "")
	fb, err := json.Marshal(formEvent)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(fb), `"url"`) {
		t.Fatalf("form-mode elicitation should omit url key: %s", fb)
	}
}

func TestReplayStartedIsReplaceMarker(t *testing.T) {
	b := NewBridge("chat-1", "run-1")
	ev := b.ReplayStarted()
	if ev.Type() != events.EventTypeCustom {
		t.Fatalf("want CUSTOM, got %v", ev.Type())
	}
	custom, ok := ev.(*events.CustomEvent)
	if !ok {
		t.Fatalf("event = %#v, want *events.CustomEvent", ev)
	}
	if custom.Name != "pocketcoder:sync" {
		t.Fatalf("Name = %q, want pocketcoder:sync", custom.Name)
	}
	value, ok := custom.Value.(map[string]any)
	if !ok {
		t.Fatalf("Value = %#v, want map[string]any", custom.Value)
	}
	if value["mode"] != "replace" {
		t.Fatalf("Value[mode] = %#v, want \"replace\"", value["mode"])
	}
}

// TestCurrentModeUpdateKeepsAvailableModes guards Task 3: a live
// CurrentModeUpdate must patch only /pocketcoder/modes/currentModeId, not
// replace the whole /pocketcoder/modes subtree (which used to wipe
// availableModes until the next snapshot).
func TestCurrentModeUpdateKeepsAvailableModes(t *testing.T) {
	b := NewBridge("c", "r")
	b.SeedSession(&acpsdk.SessionModeState{
		CurrentModeId: "auto",
		AvailableModes: []acpsdk.SessionMode{
			{Id: "auto", Name: "auto"},
			{Id: "chat", Name: "chat"},
		},
	}, nil)
	if _, err := b.Update(acpsdk.SessionUpdate{
		CurrentModeUpdate: &acpsdk.SessionCurrentModeUpdate{CurrentModeId: "chat"},
	}); err != nil {
		t.Fatalf("Update: %v", err)
	}
	snap := b.Snapshot()
	if len(snap) != 1 {
		t.Fatalf("snapshot = %v, want 1 STATE_SNAPSHOT", snap)
	}
	b2, err := json.Marshal(snap[0])
	if err != nil {
		t.Fatalf("marshal snapshot: %v", err)
	}
	var decoded struct {
		Snapshot struct {
			Pocketcoder struct {
				Modes struct {
					CurrentModeId  string           `json:"currentModeId"`
					AvailableModes []map[string]any `json:"availableModes"`
				} `json:"modes"`
			} `json:"pocketcoder"`
		} `json:"snapshot"`
	}
	if err := json.Unmarshal(b2, &decoded); err != nil {
		t.Fatalf("unmarshal snapshot: %v", err)
	}
	if decoded.Snapshot.Pocketcoder.Modes.CurrentModeId != "chat" {
		t.Fatalf("currentModeId = %q, want chat", decoded.Snapshot.Pocketcoder.Modes.CurrentModeId)
	}
	if len(decoded.Snapshot.Pocketcoder.Modes.AvailableModes) != 2 {
		t.Fatalf("availableModes = %v, want length 2 (must survive the mode update)", decoded.Snapshot.Pocketcoder.Modes.AvailableModes)
	}
}

// TestBridgePermissionStateIncludesTitleAndKind covers the fix for the
// ACP->AG-UI field-drop audit finding: the title and kind of the tool call
// being gated by a permission request must reach the client so the phone
// can label and icon the pending permission with the tool's metadata.
// nil title/kind are no-ops (the key must not appear at all rather than
// surfacing as an empty string).
func TestBridgePermissionStateIncludesTitleAndKind(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	title := "Run shell command"
	kind := acpsdk.ToolKindExecute
	event := bridge.PermissionPending("rpc-42", nil, "", &title, &kind)
	b, err := json.Marshal(event)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), `"title":"Run shell command"`) {
		t.Fatalf("permission event missing title: %s", b)
	}
	if !strings.Contains(string(b), `"kind":"execute"`) {
		t.Fatalf("permission event missing kind: %s", b)
	}

	event2 := bridge.PermissionPending("rpc-43", nil, "", nil, nil)
	b2, err := json.Marshal(event2)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(b2), `"title"`) || strings.Contains(string(b2), `"kind"`) {
		t.Fatalf("permission event should omit title/kind when nil: %s", b2)
	}
}

// ResolvePermission/ResolveElicitation had zero production callers before
// this change (the backend never cleared its own /pocketcoder/<ns> state
// server-side) — these confirm the shape of the remove-delta each emits, now
// that coordinator/run.go actually calls them on decision.
func TestBridgeResolvePermissionEmitsRemoveDelta(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	events := bridge.ResolvePermission("rpc-42")
	if len(events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(events))
	}
	b, err := json.Marshal(events[0])
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), `"op":"remove"`) || !strings.Contains(string(b), `"path":"/pocketcoder/permission"`) {
		t.Fatalf("expected a remove delta for /pocketcoder/permission, got: %s", b)
	}
}

func TestBridgeResolveElicitationEmitsRemoveDelta(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	events := bridge.ResolveElicitation("rpc-42")
	if len(events) != 1 {
		t.Fatalf("expected 1 event, got %d", len(events))
	}
	b, err := json.Marshal(events[0])
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(b), `"op":"remove"`) || !strings.Contains(string(b), `"path":"/pocketcoder/elicitation"`) {
		t.Fatalf("expected a remove delta for /pocketcoder/elicitation, got: %s", b)
	}
}

func TestBridgeCloseOpenToolsEndsEveryStillOpenCall(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	for _, id := range []string{"tool-1", "tool-2"} {
		if _, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
			SessionUpdate: "tool_call",
			ToolCallId:    acpsdk.ToolCallId(id),
			Title:         "read_file",
		}}); err != nil {
			t.Fatal(err)
		}
	}

	closed := bridge.CloseOpenTools()

	if len(closed) != 2 {
		t.Fatalf("expected 2 TOOL_CALL_END events, got %d: %#v", len(closed), closed)
	}
	for _, e := range closed {
		if e.Type() != "TOOL_CALL_END" {
			t.Fatalf("expected TOOL_CALL_END, got %s", e.Type())
		}
	}

	if again := bridge.CloseOpenTools(); len(again) != 0 {
		t.Fatalf("expected no events on a second call, got %#v", again)
	}
}

func TestBridgeFinishedStillClosesOpenToolsAndEmitsRunFinished(t *testing.T) {
	bridge := NewBridge("chat-1", "run-1")
	if _, err := bridge.Update(acpsdk.SessionUpdate{ToolCall: &acpsdk.SessionUpdateToolCall{
		SessionUpdate: "tool_call",
		ToolCallId:    "tool-1",
		Title:         "read_file",
	}}); err != nil {
		t.Fatal(err)
	}

	finished := bridge.Finished(acpsdk.StopReasonEndTurn)

	if len(finished) != 2 || finished[0].Type() != "TOOL_CALL_END" || finished[1].Type() != "RUN_FINISHED" {
		t.Fatalf("unexpected terminal events: %#v", finished)
	}
}
