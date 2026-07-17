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
