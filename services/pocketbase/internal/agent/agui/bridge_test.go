package agui

import (
	"encoding/json"
	"strings"
	"testing"

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
	finished := bridge.Finished()
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
	events, err := bridge.Update(update)
	if err != nil {
		t.Fatal(err)
	}
	if len(events) != 2 || events[0].Type() != "TOOL_CALL_RESULT" || events[1].Type() != "TOOL_CALL_END" {
		t.Fatalf("unexpected tool result events: %#v", events)
	}
	b, err := json.Marshal(events[0])
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
	finished := bridge.Finished()
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
