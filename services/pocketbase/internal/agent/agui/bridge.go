// Package agui translates the deliberately small ACP subset used by Goose into
// typed AG-UI events. It owns no history: Goose remains the source of truth.
package agui

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/ag-ui-protocol/ag-ui/sdks/community/go/pkg/core/events"
	acpsdk "github.com/coder/acp-go-sdk"
	"github.com/google/uuid"
)

// toolMeta is the per-tool retained state kept while a tool call is open: the
// last seen title/kind/status (read-modify-write across tool_call_update).
// Declared here in Task 5 so the openTools map can carry structured values
// from the start; Task 6 populates it through startTool/updateTool.
type toolMeta struct {
	title, kind, status string
}

// Bridge keeps only the open-event state needed to turn ACP chunks into AG-UI
// message boundaries for one run.
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

// NewBridge starts an AG-UI run for one PocketCoder chat / Goose session pair.
func NewBridge(threadID, runID string) *Bridge {
	return &Bridge{
		threadID:  threadID,
		runID:     runID,
		openTools: map[string]toolMeta{},
	}
}

// Started emits the first AG-UI event for a turn.
func (b *Bridge) Started() events.Event {
	return events.NewRunStartedEvent(b.threadID, b.runID)
}

// Update converts output-bearing ACP updates. Unknown update variants are
// intentionally ignored rather than leaking vendor details to Flutter.
func (b *Bridge) Update(update acpsdk.SessionUpdate) ([]events.Event, error) {
	switch {
	case update.UserMessageChunk != nil:
		return b.messageChunk("user", update.UserMessageChunk.MessageId, update.UserMessageChunk.Content), nil
	case update.AgentMessageChunk != nil:
		return b.messageChunk("assistant", update.AgentMessageChunk.MessageId, update.AgentMessageChunk.Content), nil
	case update.AgentThoughtChunk != nil:
		text, media, ok := renderContent(update.AgentThoughtChunk.Content)
		if media != nil {
			// Media in a reasoning chunk: emit CUSTOM pocketcoder:content without
			// opening a REASONING_MESSAGE scope.
			id := b.ensureReasoningID(update.AgentThoughtChunk.MessageId)
			return []events.Event{customContent(id, *media)}, nil
		}
		if !ok || text == "" {
			return nil, nil
		}
		result := b.closeMessage()
		if b.reasoningOpen && update.AgentThoughtChunk.MessageId != nil && *update.AgentThoughtChunk.MessageId != b.reasoningID {
			result = append(result, b.closeReasoning()...)
		}
		reasoningID := b.ensureReasoningID(update.AgentThoughtChunk.MessageId)
		if !b.reasoningOpen {
			result = append(result, events.NewReasoningMessageStartEvent(reasoningID, "assistant"))
			b.reasoningOpen = true
		}
		return append(result, events.NewReasoningMessageContentEvent(reasoningID, text)), nil
	case update.ToolCall != nil:
		result := b.closeReasoning()
		result = append(result, b.closeMessage()...)
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
		b.openTools[id] = toolMeta{}
		return result, nil
	case update.ToolCallUpdate != nil:
		tool := update.ToolCallUpdate
		id := string(tool.ToolCallId)
		if id == "" {
			return nil, fmt.Errorf("ACP tool_call_update missing toolCallId")
		}
		var result []events.Event
		if tool.RawInput != nil {
			input, err := json.Marshal(tool.RawInput)
			if err != nil {
				return nil, fmt.Errorf("encode ACP tool update: %w", err)
			}
			result = append(result, events.NewToolCallArgsEvent(id, string(input)))
		}
		output, hasOutput, err := toolResultText(tool.Content, tool.RawOutput)
		if err != nil {
			return nil, err
		}
		if hasOutput {
			result = append(result, events.NewToolCallResultEvent("tool-result-"+id, id, output))
		}
		if tool.Status != nil && isTerminalToolStatus(string(*tool.Status)) {
			if _, open := b.openTools[id]; open {
				delete(b.openTools, id)
				result = append(result, events.NewToolCallEndEvent(id))
			}
		}
		return result, nil
	}
	return nil, nil
}

// messageChunk is the shared emit path for ACP user/agent message chunks. It
// routes text to TEXT_MESSAGE_START/CONTENT with the given role, and routes
// media (image/audio/resource/resource_link) to CUSTOM pocketcoder:content
// without opening a text scope. Reasoning and the previous message are closed
// before opening a new assistant text scope, so mutual-exclusion between
// REASONING_MESSAGE and TEXT_MESSAGE is preserved across chunks.
//
// The msgID switch check happens before ensureMessageID mutates b.messageID
// (ensureMessageID itself resets b.messageOpen when the ID changes), so a
// pending TEXT_MESSAGE_END for the previous message still fires.
func (b *Bridge) messageChunk(role string, msgID *string, content acpsdk.ContentBlock) []events.Event {
	text, media, ok := renderContent(content)
	if media != nil {
		id := b.ensureMessageID(msgID)
		return []events.Event{customContent(id, *media)}
	}
	if !ok || text == "" {
		return nil
	}
	var result []events.Event
	result = append(result, b.closeReasoning()...)
	if b.messageOpen && msgID != nil && *msgID != "" && *msgID != b.messageID {
		result = append(result, b.closeMessage()...)
	}
	id := b.ensureMessageID(msgID)
	if !b.messageOpen {
		result = append(result, events.NewTextMessageStartEvent(id, events.WithRole(role)))
		b.messageOpen = true
		b.messageRole = role
	}
	return append(result, events.NewTextMessageContentEvent(id, text))
}

// PermissionPending represents the one transient c1 state exposed to AG-UI.
// The detailed choices stay in the authenticated c1 approval endpoint.
func (b *Bridge) PermissionPending(requestID string, options []acpsdk.PermissionOption) events.Event {
	choices := make([]map[string]string, 0, len(options))
	for _, option := range options {
		choices = append(choices, map[string]string{"optionId": string(option.OptionId), "name": option.Name, "kind": string(option.Kind)})
	}
	return events.NewStateDeltaEvent([]events.JSONPatchOperation{{
		Op:    "add",
		Path:  "/pocketcoder/permission",
		Value: map[string]any{"requestId": requestID, "status": "pending", "options": choices},
	}})
}

// Finished closes all lifecycle events. Call this only after the correlated
// session/prompt response, never by guessing from the final text chunk.
func (b *Bridge) Finished() []events.Event {
	result := b.closeReasoning()
	result = append(result, b.closeMessage()...)
	for id := range b.openTools {
		result = append(result, events.NewToolCallEndEvent(id))
	}
	b.openTools = map[string]toolMeta{}
	return append(result, events.NewRunFinishedEventWithOptions(b.threadID, b.runID, events.WithSuccessOutcome()))
}

func (b *Bridge) closeMessage() []events.Event {
	if !b.messageOpen {
		return nil
	}
	b.messageOpen = false
	return []events.Event{events.NewTextMessageEndEvent(b.messageID)}
}

func (b *Bridge) closeReasoning() []events.Event {
	if !b.reasoningOpen {
		return nil
	}
	b.reasoningOpen = false
	return []events.Event{events.NewReasoningMessageEndEvent(b.reasoningID)}
}

func (b *Bridge) ensureReasoningID(messageID *string) string {
	if messageID != nil && *messageID != "" && *messageID != b.reasoningID {
		b.reasoningID = *messageID
		b.reasoningOpen = false
	}
	if b.reasoningID == "" {
		b.reasoningID = uuid.NewString()
	}
	return b.reasoningID
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

// toolResultText renders a tool call's produced content for the UI. Text
// blocks are preferred; RawOutput is JSON-encoded as a fallback so Flutter
// always sees what the tool returned, not just that it finished.
//
// Deprecated: superseded by renderContent/renderToolContent (Task 6 will wire
// those in). Kept here so Task 5's tool arms keep the diff scoped to the
// message/reasoning paths only.
func toolResultText(content []acpsdk.ToolCallContent, rawOutput any) (string, bool, error) {
	var parts []string
	for _, block := range content {
		if block.Content == nil {
			continue
		}
		if text, ok := textContent(block.Content.Content); ok && text != "" {
			parts = append(parts, text)
		}
	}
	if len(parts) > 0 {
		return strings.Join(parts, "\n"), true, nil
	}
	if rawOutput != nil {
		encoded, err := json.Marshal(rawOutput)
		if err != nil {
			return "", false, fmt.Errorf("encode ACP tool output: %w", err)
		}
		return string(encoded), true, nil
	}
	return "", false, nil
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
