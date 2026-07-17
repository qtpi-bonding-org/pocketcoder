// Package agui translates the deliberately small ACP subset used by Goose into
// typed AG-UI events. It owns no history: Goose remains the source of truth.
package agui

import (
	"encoding/json"
	"fmt"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/google/uuid"
)

// Bridge keeps only the open-event state needed to turn ACP chunks into AG-UI
// message boundaries for one run.
type Bridge struct {
	threadID, runID string
	messageID       string
	messageOpen     bool
	openTools       map[string]bool
}

// NewBridge starts an AG-UI run for one PocketCoder chat / Goose session pair.
func NewBridge(threadID, runID string) *Bridge {
	return &Bridge{threadID: threadID, runID: runID, openTools: make(map[string]bool)}
}

// Started emits the first AG-UI event for a turn.
func (b *Bridge) Started() events.Event {
	return events.NewRunStartedEvent(b.threadID, b.runID)
}

// Update converts output-bearing ACP updates. Unknown update variants are
// intentionally ignored rather than leaking vendor details to Flutter.
func (b *Bridge) Update(update acpsdk.SessionUpdate) ([]events.Event, error) {
	switch {
	case update.AgentMessageChunk != nil:
		text, ok := textContent(update.AgentMessageChunk.Content)
		if !ok || text == "" {
			return nil, nil
		}
		result := make([]events.Event, 0, 3)
		if b.messageOpen && update.AgentMessageChunk.MessageId != nil && *update.AgentMessageChunk.MessageId != b.messageID {
			result = append(result, b.closeMessage()...)
		}
		messageID := b.ensureMessageID(update.AgentMessageChunk.MessageId)
		if !b.messageOpen {
			result = append(result, events.NewTextMessageStartEvent(messageID, events.WithRole("assistant")))
			b.messageOpen = true
		}
		return append(result, events.NewTextMessageContentEvent(messageID, text)), nil
	case update.ToolCall != nil:
		result := b.closeMessage()
		tool := update.ToolCall
		id := string(tool.ToolCallId)
		if id == "" {
			return nil, fmt.Errorf("ACP tool_call missing toolCallId")
		}
		result = append(result, events.NewToolCallStartEvent(id, tool.Title))
		if tool.RawInput != nil {
			input, err := json.Marshal(tool.RawInput)
			if err != nil {
				return nil, fmt.Errorf("encode ACP tool input: %w", err)
			}
			result = append(result, events.NewToolCallArgsEvent(id, string(input)))
		}
		b.openTools[id] = true
		return result, nil
	case update.ToolCallUpdate != nil:
		tool := update.ToolCallUpdate
		id := string(tool.ToolCallId)
		if id == "" {
			return nil, fmt.Errorf("ACP tool_call_update missing toolCallId")
		}
		if tool.RawInput != nil {
			input, err := json.Marshal(tool.RawInput)
			if err != nil {
				return nil, fmt.Errorf("encode ACP tool update: %w", err)
			}
			return []events.Event{events.NewToolCallArgsEvent(id, string(input))}, nil
		}
		if tool.Status != nil && isTerminalToolStatus(string(*tool.Status)) {
			if b.openTools[id] {
				delete(b.openTools, id)
				return []events.Event{events.NewToolCallEndEvent(id)}, nil
			}
		}
	}
	return nil, nil
}

// PermissionPending represents the one transient c1 state exposed to AG-UI.
// The detailed choices stay in the authenticated c1 approval endpoint.
func (b *Bridge) PermissionPending(requestID string, options []acpsdk.PermissionOption) events.Event {
	choices := make([]map[string]string, 0, len(options))
	for _, option := range options {
		choices = append(choices, map[string]string{"optionId": string(option.OptionId), "name": option.Name, "kind": string(option.Kind)})
	}
	return events.NewStateDeltaEvent([]events.JSONPatchOperation{{
		Op: "add", Path: "/pocketcoder/permission", Value: map[string]any{"requestId": requestID, "status": "pending", "options": choices},
	}})
}

// Finished closes all lifecycle events. Call this only after the correlated
// session/prompt response, never by guessing from the final text chunk.
func (b *Bridge) Finished() []events.Event {
	result := b.closeMessage()
	for id := range b.openTools {
		result = append(result, events.NewToolCallEndEvent(id))
	}
	b.openTools = make(map[string]bool)
	return append(result, events.NewRunFinishedEventWithOptions(b.threadID, b.runID, events.WithSuccessOutcome()))
}

func (b *Bridge) closeMessage() []events.Event {
	if !b.messageOpen {
		return nil
	}
	b.messageOpen = false
	return []events.Event{events.NewTextMessageEndEvent(b.messageID)}
}

func (b *Bridge) ensureMessageID(messageID *string) string {
	if messageID != nil && *messageID != "" && *messageID != b.messageID {
		b.messageID = *messageID
		b.messageOpen = false
	}
	if b.messageID == "" {
		b.messageID = uuid.NewString()
	}
	return b.messageID
}

func textContent(block acpsdk.ContentBlock) (string, bool) {
	if block.Text == nil {
		return "", false
	}
	return block.Text.Text, true
}

func isTerminalToolStatus(status string) bool {
	return status == "completed" || status == "failed" || status == "cancelled"
}
