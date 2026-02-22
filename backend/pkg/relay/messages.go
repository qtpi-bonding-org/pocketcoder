/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: Message Relayer. Streams conversation events to the database.
//
// # Event Model
//
// OpenCode emits three SSE event types for messages. We only care about two:
//
//   message.part.updated — one complete Part object was created or updated.
//     properties: { part: { id, type, text, messageID, sessionID, ... } }
//     → Handled by: upsertMessagePart
//
//   message.updated — message-level metadata changed (e.g. completion, tokens, cost).
//     properties: { info: { id, role, time.completed, cost, tokens, error, ... } }
//     Contains NO parts. Parts live exclusively as part.updated events.
//     → Handled by: handleMessageCompletion
//
//   message.part.delta — incremental text streaming delta; handled by the frontend only.
//     We intentionally ignore this — full text arrives via message.part.updated.

package relay

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
)

// ─── User Message Pump ────────────────────────────────────────────────────────

func (r *RelayService) recoverMissedMessages() {
	r.app.Logger().Info("🔄 [Relay/Go] Recovery Pump: Checking for unsent user messages...")
	records, err := r.app.FindRecordsByFilter("messages", "role = 'user' && (user_message_status = 'pending' || user_message_status = '')", "created", 100, 0)
	if err != nil {
		r.app.Logger().Error("⚠️ [Relay/Go] Recovery check failed", "error", err)
		return
	}
	if len(records) > 0 {
		r.app.Logger().Info("🔄 [Relay/Go] Pump found unsent messages", "count", len(records))
		for _, msg := range records {
			go r.processUserMessage(msg)
		}
	} else {
		r.app.Logger().Debug("✅ [Relay/Go] Recovery Pump: All messages sent.")
	}
}

func (r *RelayService) processUserMessage(msg *core.Record) {
	r.app.Logger().Info("📨 [Relay/Go] Processing Message", "id", msg.Id)

	chatID := msg.GetString("chat")

	// 1. Claim the message — mark as sending so no other goroutine picks it up
	msg.Set("user_message_status", "sending")
	if err := r.app.Save(msg); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to claim message", "id", msg.Id, "error", err)
		return
	}

	// 2. Flip chat turn to assistant
	if err := r.withChatLock(chatID, func(chat *core.Record) error {
		chat.Set("turn", "assistant")
		return nil
	}); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to update chat turn", "error", err)
	}

	// 3. Get or create an OpenCode session for this chat
	sessionID, err := r.ensureSession(chatID)
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Session failure", "error", err)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}

	// 4. Fire-and-forget prompt to OpenCode via prompt_async.
	//    The SSE listener will handle syncing the assistant's response.
	url := fmt.Sprintf("%s/session/%s/prompt_async", r.openCodeURL, sessionID)

	var parts []interface{}
	partsRaw := msg.Get("parts")
	if jsonRaw, ok := partsRaw.(types.JSONRaw); ok {
		json.Unmarshal(jsonRaw, &parts)
	} else if p, ok := partsRaw.([]interface{}); ok {
		parts = p
	}

	payload := map[string]interface{}{"parts": parts}
	body, _ := json.Marshal(payload)
	r.app.Logger().Debug("📡 [Relay/Go] 📤 ASYNC PUSH", "id", msg.Id, "body", string(body))

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Post(url, "application/json", strings.NewReader(string(body)))
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] OpenCode prompt failed", "error", err)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		r.app.Logger().Error("❌ [Relay/Go] OpenCode prompt rejected", "status", resp.Status)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}

	msg.Set("user_message_status", "delivered")
	if err := r.app.Save(msg); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to mark message delivered", "id", msg.Id, "error", err)
	}
	r.app.Logger().Info("✅ [Relay/Go] Message delivered to OpenCode", "id", msg.Id)
}

// ─── SSE Event Handlers ───────────────────────────────────────────────────────

// upsertMessagePart handles a "message.part.updated" SSE event.
//
// OpenCode fires this once per part as it is created or updated during streaming.
// The event carries one complete Part object: { id, type, text, messageID, sessionID, ... }
//
// We upsert (insert-or-replace by part.id) the incoming part into the existing
// parts array stored on the PocketBase message record — no HTTP round-trip needed.
func (r *RelayService) upsertMessagePart(chatID string, part map[string]interface{}) {
	ocMsgID, _ := part["messageID"].(string)
	if ocMsgID == "" {
		r.app.Logger().Warn("⚠️ [Relay/Go] upsertMessagePart: missing messageID in part")
		return
	}
	partID, _ := part["id"].(string)
	partType, _ := part["type"].(string)
	r.app.Logger().Debug("📦 [Relay/Go] Part received", "ocMsgID", ocMsgID, "partID", partID, "type", partType)

	// Normalise: if this is a text part where text is under "content" instead of "text"
	if partType == "text" {
		if text, _ := part["text"].(string); text == "" {
			if content, _ := part["content"].(string); content != "" {
				part["text"] = content
			}
		}
	}

	// 1. Find-or-create the PocketBase message record.
	// Guard: We must not create assistant records for "user echoes".
	// User messages are mapped by handleMessageCompletion as soon as their metadata arrives.
	// If a part arrives for an unknown message, we only create an assistant record if:
	// - It is explicitly a "step-start" (Assistant marker)
	// - OR it has a parentID (Assistant-only field in schema)
	existing, _ := r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})

	var record *core.Record
	now := time.Now().Format("2006-01-02 15:04:05.000Z")

	if existing != nil {
		if existing.GetString("role") == "user" {
			// Echo of our own user message — skip
			return
		}
		record = existing
	} else {
		// Unknown messageID. We need to decide if this is a new assistant turn
		// starting, or just a user-message echo.
		isAssistant := (partType == "step-start") || (part["parentID"] != nil)

		// Fallback: check the chat's current turn state.
		if !isAssistant {
			chat, _ := r.app.FindRecordById("chats", chatID)
			if chat != nil && chat.GetString("turn") == "assistant" {
				isAssistant = true
			}
		}

		if !isAssistant {
			// If we still can't confirm it's an assistant message, skip it.
			// handleMessageCompletion will definitively map/create it later.
			r.app.Logger().Debug("⏭️ [Relay/Go] Part for unknown message skipped (possible user echo)", "ocMsgID", ocMsgID, "type", partType)
			return
		}

		collection, err := r.app.FindCollectionByNameOrId("messages")
		if err != nil {
			r.app.Logger().Error("❌ [Relay/Go] Collection error", "error", err)
			return
		}
		record = core.NewRecord(collection)
		record.Set("chat", chatID)
		record.Set("role", "assistant")
		record.Set("ai_engine_message_id", ocMsgID)
		record.Set("engine_message_status", "processing")
		record.Set("created", now)
		r.app.Logger().Info("🆕 [Relay/Go] Created assistant record from part stream", "ocMsgID", ocMsgID)
	}
	record.Set("updated", now)

	// Also set parentID if we have it (handy for threading)
	if parentID, _ := part["parentID"].(string); parentID != "" {
		record.Set("parent_id", parentID)
	}

	// 2. Load existing parts and upsert the incoming part by id
	var existingParts []interface{}
	rawParts := record.Get("parts")
	if jsonRaw, ok := rawParts.(types.JSONRaw); ok {
		json.Unmarshal(jsonRaw, &existingParts)
	} else if ep, ok := rawParts.([]interface{}); ok {
		existingParts = ep
	}

	merged := false
	for i, p := range existingParts {
		if pm, ok := p.(map[string]interface{}); ok {
			if pm["id"] == partID {
				existingParts[i] = part
				merged = true
				break
			}
		}
	}
	if !merged {
		existingParts = append(existingParts, part)
	}

	record.Set("parts", existingParts)

	if err := r.app.Save(record); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to upsert message part", "ocMsgID", ocMsgID, "error", err)
		return
	}
	r.app.Logger().Debug("✅ [Relay/Go] Part upserted", "ocMsgID", ocMsgID, "partID", partID, "type", partType)

	// 3. If this is a text part, update the chat preview (high-water-mark)
	if partType == "text" {
		preview := extractPreviewFromParts(existingParts)
		if preview != "" {
			r.withChatLock(chatID, func(chat *core.Record) error {
				current := chat.GetString("preview")
				if len(preview) > len(current) || (len(preview) == len(current) && preview != current) {
					r.app.Logger().Info("✍️ [Relay/Go] Updating chat preview", "chatId", chatID, "preview", preview)
					chat.Set("preview", preview)
				}
				chat.Set("last_active", time.Now().Format("2006-01-02 15:04:05.000Z"))
				return nil
			})
		}
	}

	// 4. Check if this part signals a subagent handoff
	go r.checkForSubagentRegistration(chatID, []interface{}{part})
}

// handleMessageCompletion handles a "message.updated" SSE event.
//
// OpenCode fires this when message-level info changes — typically when a step
// finishes and tokens/cost are tallied. The event contains ONLY the message info
// (role, time.completed, cost, tokens, error). It never contains parts.
//
// We only update the engine_message_status and chat metadata here.
// We never read or write the parts field.
func (r *RelayService) handleMessageCompletion(chatID string, info map[string]interface{}) {
	ocMsgID, _ := info["id"].(string)
	if ocMsgID == "" {
		return
	}

	timeInfo, _ := info["time"].(map[string]interface{})
	completed := timeInfo != nil && timeInfo["completed"] != nil
	hasError := info["error"] != nil

	newStatus := "processing"
	if completed {
		newStatus = "completed"
	} else if hasError {
		newStatus = "failed"
	}

	r.app.Logger().Info("📋 [Relay/Go] Message status update", "ocMsgID", ocMsgID, "status", newStatus, "chatId", chatID)

	// 1. Find or map the record
	existing, _ := r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})

	var record *core.Record
	now := time.Now().Format("2006-01-02 15:04:05.000Z")
	role, _ := info["role"].(string)

	if existing != nil {
		record = existing
	} else if role == "user" {
		// Mapping: Find the latest user message in this chat that doesn't have an ocID yet.
		// We use -created to find the most recent one.
		records, _ := r.app.FindRecordsByFilter("messages", "chat = {:chat} && role = 'user' && ai_engine_message_id = ''", "-created", 1, 0, map[string]any{"chat": chatID})
		if len(records) > 0 {
			record = records[0]
			record.Set("ai_engine_message_id", ocMsgID)
			r.app.Logger().Info("🔗 [Relay/Go] Mapped local user message to OpenCode ID", "chatId", chatID, "ocMsgID", ocMsgID)
		} else {
			r.app.Logger().Debug("⏭️ [Relay/Go] User message.updated arrived but no pending local record found", "ocMsgID", ocMsgID)
			return
		}
	} else if role == "assistant" {
		// Create new assistant record
		collection, err := r.app.FindCollectionByNameOrId("messages")
		if err != nil {
			r.app.Logger().Error("❌ [Relay/Go] Collection error creating message", "error", err)
			return
		}
		record = core.NewRecord(collection)
		record.Set("chat", chatID)
		record.Set("role", "assistant")
		record.Set("ai_engine_message_id", ocMsgID)
		record.Set("created", now)
		if parentID, _ := info["parentID"].(string); parentID != "" {
			record.Set("parent_id", parentID)
		}
		r.app.Logger().Info("🆕 [Relay/Go] Created assistant record from completion event", "ocMsgID", ocMsgID)
	} else {
		return // Unknown role
	}

	// 2. Only advance status — never demote a finished message
	currentStatus := record.GetString("engine_message_status")
	if currentStatus == "completed" || currentStatus == "failed" {
		r.app.Logger().Debug("🛡️ [Relay/Go] Protecting finished status", "ocMsgID", ocMsgID, "current", currentStatus)
	} else {
		record.Set("engine_message_status", newStatus)
		record.Set("updated", now)
		if err := r.app.Save(record); err != nil {
			r.app.Logger().Error("❌ [Relay/Go] Failed to update message metadata", "ocMsgID", ocMsgID, "error", err)
			return
		}
	}

	// Update chat.last_active and re-read preview from the parts we already saved
	var existingParts []interface{}
	rawParts := record.Get("parts")
	if jsonRaw, ok := rawParts.(types.JSONRaw); ok {
		json.Unmarshal(jsonRaw, &existingParts)
	} else if ep, ok := rawParts.([]interface{}); ok {
		existingParts = ep
	}
	preview := extractPreviewFromParts(existingParts)

	r.withChatLock(chatID, func(chat *core.Record) error {
		if preview != "" {
			current := chat.GetString("preview")
			if len(preview) > len(current) || (len(preview) == len(current) && preview != current) {
				r.app.Logger().Info("✍️ [Relay/Go] Updating chat preview on completion", "chatId", chatID, "preview", preview)
				chat.Set("preview", preview)
			}
		}

		chat.Set("last_active", time.Now().Format("2006-01-02 15:04:05.000Z"))
		return nil
	})

	r.app.Logger().Info("✅ [Relay/Go] Message completion handled", "ocMsgID", ocMsgID, "status", newStatus, "chatId", chatID)
}

// ─── Session Management ───────────────────────────────────────────────────────

func (r *RelayService) ensureSession(chatID string) (string, error) {
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Chat lookup failed", "chatId", chatID, "error", err)
		return "", err
	}

	existingSession := chat.GetString("ai_engine_session_id")
	if existingSession != "" {
		verifyURL := fmt.Sprintf("%s/session/%s", r.openCodeURL, existingSession)
		client := &http.Client{Timeout: 5 * time.Second}
		vResp, vErr := client.Get(verifyURL)
		if vErr == nil {
			defer vResp.Body.Close()
			if vResp.StatusCode == 200 {
				r.app.Logger().Debug("✅ [Relay/Go] Existing session is still alive", "id", existingSession)
				return existingSession, nil
			}
			r.app.Logger().Warn("⚠️ [Relay/Go] Existing session check failed", "id", existingSession, "status", vResp.StatusCode)
			if vResp.StatusCode == http.StatusNotFound {
				r.app.Logger().Warn("⚠️ [Relay/Go] Session is gone (404), cleaning up", "id", existingSession)
				r.withChatLock(chatID, func(chat *core.Record) error {
					chat.Set("ai_engine_session_id", "")
					return nil
				})
				existingSession = ""
			}
		} else {
			r.app.Logger().Warn("⚠️ [Relay/Go] Error verifying session", "id", existingSession, "error", vErr)
			// Optimistically try the existing session on network errors
			return existingSession, nil
		}
	}

	if existingSession != "" {
		return existingSession, nil
	}

	// Create new session
	r.app.Logger().Info("🆕 [Relay/Go] Creating new OpenCode session", "chatId", chatID)
	reqURL := fmt.Sprintf("%s/session", r.openCodeURL)
	payload := `{"directory": "/workspace", "agent": "poco"}`
	resp, err := http.Post(reqURL, "application/json", strings.NewReader(payload))
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] OpenCode session creation request failed", "error", err)
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		r.app.Logger().Error("❌ [Relay/Go] OpenCode session creation rejected", "status", resp.Status)
		return "", fmt.Errorf("opencode rejected session creation: %s", resp.Status)
	}

	var res map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&res)

	newID, _ := res["id"].(string)
	if newID == "" {
		return "", fmt.Errorf("failed to extract session id from response")
	}

	if err := r.withChatLock(chatID, func(chat *core.Record) error {
		chat.Set("ai_engine_session_id", newID)
		chat.Set("engine_type", "opencode")
		return nil
	}); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to update chat with session id", "chatId", chatID, "error", err)
	} else {
		r.app.Logger().Info("✅ [Relay/Go] Linked Chat to OpenCode Session", "chatId", chatID, "sessionId", newID)
	}
	return newID, nil
}

// ─── Subagent Detection ───────────────────────────────────────────────────────

// checkForSubagentRegistration inspects a slice of parts for tool results that
// indicate a CAO subagent handoff completed, and persists the lineage to the DB.
func (r *RelayService) checkForSubagentRegistration(chatID string, parts []interface{}) {
	for _, p := range parts {
		part, ok := p.(map[string]interface{})
		if !ok {
			continue
		}

		partType, _ := part["type"].(string)

		var toolName string
		var content interface{}

		switch partType {
		case "tool_result":
			toolName, _ = part["name"].(string)
			content = part["content"]
			if content == nil {
				content = part["text"]
			}
		case "tool", "tool_use":
			toolName, _ = part["tool"].(string)
			if toolName == "" {
				toolName, _ = part["name"].(string)
			}
			r.app.Logger().Debug("🔍 [Relay] Checking tool part", "tool", toolName, "type", partType)
			if state, ok := part["state"].(map[string]interface{}); ok {
				content = state["output"]
				if content == nil {
					content = state["input"]
				}
			} else {
				content = part["input"]
				if content == nil {
					content = part["output"]
				}
			}
		default:
			continue
		}

		if toolName != "handoff" && toolName != "assign" && toolName != "cao_handoff" && toolName != "cao_assign" {
			continue
		}

		var resultData map[string]interface{}
		switch v := content.(type) {
		case string:
			if v != "" {
				if err := json.Unmarshal([]byte(v), &resultData); err != nil {
					r.app.Logger().Warn("⚠️ [Relay] Failed to parse tool content as JSON", "error", err)
					continue
				}
			}
		case map[string]interface{}:
			resultData = v
		default:
			if content != nil {
				if bs, err := json.Marshal(content); err == nil {
					json.Unmarshal(bs, &resultData)
				}
			}
		}

		if resultData == nil {
			continue
		}

		sysEvent, _ := resultData["_pocketcoder_sys_event"].(string)
		if sysEvent == "" {
			sysEvent, _ = resultData["pocketcoder_sys_event"].(string)
		}
		if sysEvent != "" && sysEvent != "handoff_complete" {
			continue
		}

		subagentID, _ := resultData["subagent_id"].(string)
		if subagentID == "" {
			continue
		}
		terminalID, _ := resultData["terminal_id"].(string)
		agentProfile, _ := resultData["agent_profile"].(string)

		var tmuxWindowID int
		if tmuxWindow, ok := resultData["tmux_window_id"].(float64); ok {
			tmuxWindowID = int(tmuxWindow)
		}

		r.app.Logger().Info("🤖 [Relay] Detected Subagent Registration",
			"subagentID", subagentID, "terminalID", terminalID,
			"windowID", tmuxWindowID, "profile", agentProfile, "chatID", chatID)
		r.registerSubagentInDB(chatID, subagentID, terminalID, tmuxWindowID, agentProfile)
	}
}

func (r *RelayService) registerSubagentInDB(chatID, subagentID, terminalID string, tmuxWindowID int, agentProfile string) {
	if subagentID == "" {
		r.app.Logger().Warn("⚠️ [Relay] Empty subagent_id, skipping registration", "chatId", chatID)
		return
	}

	existing, _ := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": subagentID})
	if existing != nil {
		return
	}

	collection, err := r.app.FindCollectionByNameOrId("subagents")
	if err != nil {
		r.app.Logger().Error("❌ [Relay] Could not find subagents collection", "error", err)
		return
	}

	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		r.app.Logger().Error("❌ [Relay] Could not find chat context", "id", chatID, "error", err)
		return
	}
	delegatingAgentID := chat.GetString("ai_engine_session_id")

	record := core.NewRecord(collection)
	record.Set("subagent_id", subagentID)
	record.Set("delegating_agent_id", delegatingAgentID)
	record.Set("tmux_window_id", tmuxWindowID)
	record.Set("chat", chatID)

	if err := r.app.Save(record); err != nil {
		r.app.Logger().Error("❌ [Relay] Failed to save subagent record", "error", err)
	} else {
		r.app.Logger().Info("✅ [Relay] Persisted Subagent Lineage",
			"subagentID", subagentID, "delegatingAgentID", delegatingAgentID,
			"windowID", tmuxWindowID, "chatID", chatID, "profile", agentProfile)
	}
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

// extractPreviewFromParts returns the text of the first text part, truncated to 50 chars.
func extractPreviewFromParts(parts []interface{}) string {
	for _, p := range parts {
		if pm, ok := p.(map[string]interface{}); ok {
			if pm["type"] != "text" {
				continue
			}
			text, _ := pm["text"].(string)
			if text == "" {
				text, _ = pm["content"].(string)
			}
			if text != "" {
				if len(text) > 50 {
					return text[:50] + "..."
				}
				return text
			}
		}
	}
	return ""
}
