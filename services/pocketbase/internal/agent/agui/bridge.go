// Package agui translates the deliberately small ACP subset used by Goose into
// typed AG-UI events. It owns no history: Goose remains the source of truth.
package agui

import (
	"encoding/json"

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
		return b.startTool(update.ToolCall), nil
	case update.ToolCallUpdate != nil:
		return b.updateTool(update.ToolCallUpdate), nil
	case update.Plan != nil:
		return []events.Event{b.state.set("plan", map[string]any{"entries": planEntries(update.Plan.Entries)})}, nil
	case update.PlanUpdate != nil:
		// Unstable ACP. Verify SessionPlanUpdate's shape at impl time: if it carries
		// entries, full-replace like Plan; otherwise surface as RAW (don't guess a merge).
		return []events.Event{rawEvent("plan_update", nil)}, nil
	case update.PlanRemoved != nil:
		return []events.Event{b.state.remove("plan")}, nil
	case update.CurrentModeUpdate != nil:
		return []events.Event{b.state.set("modes", map[string]any{"currentModeId": string(update.CurrentModeUpdate.CurrentModeId)})}, nil
	case update.ConfigOptionUpdate != nil:
		return []events.Event{b.state.set("config", map[string]any{"options": configOptions(update.ConfigOptionUpdate.ConfigOptions)})}, nil
	case update.AvailableCommandsUpdate != nil:
		return []events.Event{b.state.set("commands", commands(update.AvailableCommandsUpdate.AvailableCommands))}, nil
	case update.UsageUpdate != nil:
		v := map[string]any{"size": update.UsageUpdate.Size, "used": update.UsageUpdate.Used}
		if update.UsageUpdate.Cost != nil {
			v["cost"] = map[string]any{"amount": update.UsageUpdate.Cost.Amount, "currency": update.UsageUpdate.Cost.Currency}
		}
		return []events.Event{b.state.set("usage", v)}, nil
	case update.SessionInfoUpdate != nil:
		return []events.Event{b.state.set("session_info", map[string]any{"title": deref(update.SessionInfoUpdate.Title)})}, nil
	}
	// default (no variant matched) — never-drop: surface as redacted RAW so the
	// client still sees that an update arrived, just not the undecoded blob.
	return []events.Event{rawEvent("session_update", nil)}, nil
}

// startTool handles the initial tool_call. tc is the FLAT SessionUpdate variant:
// fields (ToolCallId, Title, Kind, Status, Content, RawInput, RawOutput,
// Locations) live directly on it. Single-shot: an initial terminal status with
// content emits TOOL_CALL_RESULT + TOOL_CALL_END in the same burst so the
// output is never lost when ACP delivers a completed call up-front.
func (b *Bridge) startTool(tc *acpsdk.SessionUpdateToolCall) []events.Event {
	id := string(tc.ToolCallId)
	if id == "" {
		// Soft miss: never abort the turn; surface as redacted RAW.
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
	if len(tc.Content) > 0 {
		result = append(result, b.toolResult(id, tc.Content, tc.RawOutput)...)
	}
	if isTerminalToolStatus(status) {
		result = append(result, b.endTool(id)...)
	}
	return result
}

// updateTool handles tool_call_update. Its fields are POINTERS (partial
// update), unlike startTool's flat non-pointer struct — read-modify-write the
// retained meta. Unknown tool ids still emit an update (zero-value meta) so
// the client always sees the latest state.
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

// toolResult splits ACP tool result content into TOOL_CALL_RESULT (text/
// rawOutput fallback) plus CUSTOM pocketcoder:{diff,terminal} for structured
// results. Returns a single redacted RAW on render error so the client still
// sees that something arrived, just not the malformed blob.
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

// endTool closes a single open tool id. Returns nil if the id is unknown so
// re-entry (e.g. a late terminal status) is a no-op rather than a duplicate
// TOOL_CALL_END.
func (b *Bridge) endTool(id string) []events.Event {
	if _, open := b.openTools[id]; !open {
		return nil
	}
	delete(b.openTools, id)
	return []events.Event{events.NewToolCallEndEvent(id)}
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
// Routing through b.state.set records the pending permission in the projection
// (so Snapshot() surfaces it) AND returns the same STATE_DELTA/add/pocketcoder-
// permission event shape the bare version emitted — TestBridgePermissionState
// keeps passing on the payload, and Task 8's Snapshot-omits-resolved becomes
// reachable because the value is now retained.
func (b *Bridge) PermissionPending(requestID string, options []acpsdk.PermissionOption) events.Event {
	choices := make([]map[string]string, 0, len(options))
	for _, option := range options {
		choices = append(choices, map[string]string{"optionId": string(option.OptionId), "name": option.Name, "kind": string(option.Kind)})
	}
	return b.state.set("permission", map[string]any{"requestId": requestID, "status": "pending", "options": choices})
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

func isTerminalToolStatus(status string) bool {
	return status == "completed" || status == "failed" || status == "cancelled"
}

// planEntries projects an ACP plan entry slice into the AG-UI client's
// expected shape (content + priority + status strings). Helper kept
// package-private since it's only consumed by the Update dispatch.
func planEntries(entries []acpsdk.PlanEntry) []map[string]any {
	out := make([]map[string]any, 0, len(entries))
	for _, e := range entries {
		out = append(out, map[string]any{
			"content":  e.Content,
			"priority": string(e.Priority),
			"status":   string(e.Status),
		})
	}
	return out
}

// commands projects an ACP available-commands slice into the AG-UI client's
// expected shape (name + description).
func commands(cmds []acpsdk.AvailableCommand) []map[string]any {
	out := make([]map[string]any, 0, len(cmds))
	for _, c := range cmds {
		out = append(out, map[string]any{
			"name":        c.Name,
			"description": c.Description,
		})
	}
	return out
}

// configOptions decodes ACP's discriminated union (Boolean | Select). The
// `kind` discriminator is preserved so clients can branch on it; the original
// id/name/currentValue are carried alongside so the Flutter side can rebuild
// either a checkbox or a dropdown from one slice.
func configOptions(opts []acpsdk.SessionConfigOption) []map[string]any {
	out := make([]map[string]any, 0, len(opts))
	for _, o := range opts {
		switch {
		case o.Boolean != nil:
			out = append(out, map[string]any{
				"kind":         "boolean",
				"id":           string(o.Boolean.Id),
				"name":         o.Boolean.Name,
				"currentValue": o.Boolean.CurrentValue,
			})
		case o.Select != nil:
			out = append(out, map[string]any{
				"kind":         "select",
				"id":           string(o.Select.Id),
				"name":         o.Select.Name,
				"currentValue": string(o.Select.CurrentValue),
			})
		}
	}
	return out
}

// SeedSession primes the /pocketcoder projection with the modes and config that
// the agent advertised on session/new (or session/load). It is called once per
// run, before any Update. The returned events are STATE_DELTAs that a
// subscriber can replay so the Flutter side has the initial state without
// waiting for a CurrentModeUpdate / ConfigOptionUpdate to arrive.
func (b *Bridge) SeedSession(modes *acpsdk.SessionModeState, config []acpsdk.SessionConfigOption) []events.Event {
	var out []events.Event
	if modes != nil {
		out = append(out, b.state.set("modes", map[string]any{
			"currentModeId":  string(modes.CurrentModeId),
			"availableModes": sessionModes(modes.AvailableModes),
		}))
	}
	if len(config) > 0 {
		out = append(out, b.state.set("config", map[string]any{"options": configOptions(config)}))
	}
	return out
}

// Snapshot returns the current /pocketcoder projection as a single
// STATE_SNAPSHOT (or nil when nothing has been recorded). Intended for
// subscriber attach so a late-joining client can catch up without re-emitting
// every delta.
func (b *Bridge) Snapshot() []events.Event {
	return b.state.snapshot()
}

// ResolvePermission clears a pending permission from the projection. The id
// is accepted for call-site symmetry with the c1 approval endpoint and a
// future multi-pending model; v1 stores a single pending entry per namespace
// so the param is unused and remove suffices.
func (b *Bridge) ResolvePermission(id string) []events.Event {
	_ = id
	return []events.Event{b.state.remove("permission")}
}

// ResolveElicitation clears a pending elicitation from the projection. Same
// id-symmetry rationale as ResolvePermission.
func (b *Bridge) ResolveElicitation(id string) []events.Event {
	_ = id
	return []events.Event{b.state.remove("elicitation")}
}

// ElicitationPending records a pending elicitation in the projection. The
// returned STATE_DELTA mirrors PermissionPending's shape so the client UI can
// render any pending side-channel request from the same STATE stream.
func (b *Bridge) ElicitationPending(id, message, mode string, schema any) events.Event {
	return b.state.set("elicitation", map[string]any{
		"elicitationId":   id,
		"message":         message,
		"mode":            mode,
		"requestedSchema": schema,
	})
}

// sessionModes projects an ACP session-mode slice into the AG-UI client's
// expected shape (id + name + optional description). Kept package-private; it
// is only consumed by SeedSession.
func sessionModes(modes []acpsdk.SessionMode) []map[string]any {
	out := make([]map[string]any, 0, len(modes))
	for _, m := range modes {
		out = append(out, map[string]any{
			"id":          string(m.Id),
			"name":        m.Name,
			"description": deref(m.Description),
		})
	}
	return out
}
