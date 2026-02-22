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

	// 3.5 Verify the session ID is persisted before calling prompt_async
	// This prevents a race condition where SSE events arrive before the database commit
	// Retry up to 5 times with exponential backoff
	var chat *core.Record
	for attempt := 0; attempt < 5; attempt++ {
		chat, err = r.app.FindRecordById("chats", chatID)
		if err == nil && chat.GetString("ai_engine_session_id") == sessionID {
			break
		}
		if attempt < 4 {
			delay := time.Duration(10*(1<<uint(attempt))) * time.Millisecond // 10ms, 20ms, 40ms, 80ms, 160ms
			r.app.Logger().Warn("⚠️ [Relay/Go] Session ID not yet persisted, retrying...", "chatId", chatID, "sessionId", sessionID, "attempt", attempt+1, "delay_ms", delay.Milliseconds())
			time.Sleep(delay)
		}
	}
	if err != nil || chat.GetString("ai_engine_session_id") != sessionID {
		r.app.Logger().Error("❌ [Relay/Go] Session ID persistence verification failed after retries", "chatId", chatID, "sessionId", sessionID)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}
	r.app.Logger().Info("✅ [Relay/Go] Session ID verified in database", "chatId", chatID, "sessionId", sessionID)

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
// CRITICAL: This function NEVER touches the database. All parts are buffered in memory
// until handleMessageCompletion flushes them atomically. This is the core of the
// Strict Buffer architecture that eliminates race conditions.
//
// Strategy: Always cache the part. The role (user/assistant) is determined by
// handleMessageCompletion when it receives the message.updated event.
func (r *RelayService) upsertMessagePart(chatID string, part map[string]interface{}) {
	ocMsgID, _ := part["messageID"].(string)
	if ocMsgID == "" {
		r.app.Logger().Warn("⚠️ [Relay/Go] upsertMessagePart: missing messageID in part")
		return
	}
	partID, _ := part["id"].(string)
	partType, _ := part["type"].(string)
	r.app.Logger().Info("📦 [Relay/Go] Part received", "ocMsgID", ocMsgID, "partID", partID, "type", partType, "chatID", chatID)

	// Normalise: if this is a text part where text is under "content" instead of "text"
	if partType == "text" {
		if text, _ := part["text"].(string); text == "" {
			if content, _ := part["content"].(string); content != "" {
				part["text"] = content
				r.app.Logger().Info("🔄 [Relay/Go] Normalized text part (content->text)", "ocMsgID", ocMsgID, "partID", partID)
			}
		} else {
			r.app.Logger().Info("📝 [Relay/Go] Text part has content", "ocMsgID", ocMsgID, "partID", partID, "textLen", len(text))
		}
	}

	// CRITICAL: Never touch the database here. Always cache.
	// The role is determined by handleMessageCompletion when it receives message.updated.

	// 1. Lock the cache
	r.partCacheMu.Lock()
	defer r.partCacheMu.Unlock()

	// 2. Initialize nested map if needed
	if r.partCache[ocMsgID] == nil {
		r.partCache[ocMsgID] = make(map[string]interface{})
	}

	// 3. Cache the part (overwrites if exists)
	r.partCache[ocMsgID][partID] = part

	cacheSize := len(r.partCache[ocMsgID])
	r.app.Logger().Info("💾 [Relay/Go] Cached part", "ocMsgID", ocMsgID, "partID", partID, "type", partType, "cacheSize", cacheSize, "chatID", chatID)

	// 4. Update chat preview if text part
	if partType == "text" {
		r.updateChatPreview(chatID, ocMsgID)
	}

	// 5. Check if this part signals a subagent handoff
	go r.checkForSubagentRegistration(chatID, []interface{}{part})
}

// upsertPartToRecord adds or updates a part in an existing message record
func (r *RelayService) upsertPartToRecord(record *core.Record, part map[string]interface{}, chatID string) {
	partID, _ := part["id"].(string)
	partType, _ := part["type"].(string)
	ocMsgID := record.GetString("ai_engine_message_id")
	now := time.Now().Format("2006-01-02 15:04:05.000Z")

	// Set parentID if available
	if parentID, _ := part["parentID"].(string); parentID != "" {
		record.Set("parent_id", parentID)
	}

	// Load existing parts and upsert
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
	record.Set("updated", now)

	if err := r.app.Save(record); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to upsert message part", "ocMsgID", ocMsgID, "error", err)
		return
	}
	r.app.Logger().Info("✅ [Relay/Go] Part upserted to record", "ocMsgID", ocMsgID, "partID", partID, "type", partType, "totalParts", len(existingParts), "recordID", record.Id)

	// Update chat preview if this is a text part
	if partType == "text" {
		preview := extractPreviewFromParts(existingParts)
		if preview != "" {
			r.withChatLock(chatID, func(chat *core.Record) error {
				current := chat.GetString("preview")
				if len(preview) > len(current) || (len(preview) == len(current) && preview != current) {
					r.app.Logger().Debug("✍️ [Relay/Go] Updating chat preview", "chatId", chatID, "preview", preview)
					chat.Set("preview", preview)
				}
				chat.Set("last_active", time.Now().Format("2006-01-02 15:04:05.000Z"))
				return nil
			})
		}
	}

	// Check if this part signals a subagent handoff
	go r.checkForSubagentRegistration(chatID, []interface{}{part})
}

// handleMessageCompletion handles a "message.updated" SSE event.
//
// OpenCode fires this when message-level info changes — typically when a step
// finishes and tokens/cost are tallied. The event contains ONLY the message info
// (role, time.completed, cost, tokens, error). It never contains parts.
//
// This is the authoritative source of truth for message role and status.
// It flushes any cached parts and creates the final database record.
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

	role, _ := info["role"].(string)
	r.app.Logger().Info("📋 [Relay/Go] Message completion event", "ocMsgID", ocMsgID, "role", role, "status", newStatus, "chatID", chatID, "completed", completed, "hasError", hasError)

	// 1. Check for cached parts and flush them
	r.partCacheMu.Lock()
	var cachedParts []interface{}
	if parts, ok := r.partCache[ocMsgID]; ok {
		// Convert map values to slice
		for _, p := range parts {
			cachedParts = append(cachedParts, p)
		}
		delete(r.partCache, ocMsgID)
		r.app.Logger().Info("🔓 [Relay/Go] Flushing cached parts", "ocMsgID", ocMsgID, "partCount", len(cachedParts))
	}
	r.partCacheMu.Unlock()

	// 2. Find existing record
	existing, _ := r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})

	var record *core.Record
	now := time.Now().Format("2006-01-02 15:04:05.000Z")

	if role == "user" {
		// User message handling: Map to our local user message
		records, _ := r.app.FindRecordsByFilter("messages", "chat = {:chat} && role = 'user' && ai_engine_message_id = ''", "-created", 1, 0, map[string]any{"chat": chatID})
		if len(records) > 0 {
			localUserMsg := records[0]
			localUserMsg.Set("ai_engine_message_id", ocMsgID)
			localUserMsg.Set("user_message_status", "delivered")
			if err := r.app.Save(localUserMsg); err != nil {
				r.app.Logger().Error("❌ [Relay/Go] Failed to map user message", "error", err)
			} else {
				r.app.Logger().Info("🔗 [Relay/Go] Mapped local user message", "ocMsgID", ocMsgID, "localMessageID", localUserMsg.Id)
			}
		}

		// Discard any cached parts for user echoes (we don't need them)
		if len(cachedParts) > 0 {
			r.app.Logger().Debug("🗑️ [Relay/Go] Discarded cached parts for user echo", "ocMsgID", ocMsgID, "count", len(cachedParts))
		}

		// User messages don't need further processing
		return
	}

	// Assistant message handling
	if role == "assistant" {
		if existing != nil {
			record = existing
			r.app.Logger().Debug("📝 [Relay/Go] Updating existing assistant record", "ocMsgID", ocMsgID)
		} else {
			// Create new assistant record
			collection, err := r.app.FindCollectionByNameOrId("messages")
			if err != nil {
				r.app.Logger().Error("❌ [Relay/Go] Collection error", "error", err)
				return
			}
			record = core.NewRecord(collection)
			record.Set("chat", chatID)
			record.Set("role", "assistant")
			record.Set("ai_engine_message_id", ocMsgID)
			record.Set("created", now)
			r.app.Logger().Info("🆕 [Relay/Go] Created assistant record from completion event", "ocMsgID", ocMsgID)
		}

		// Set parentID if available
		if parentID, _ := info["parentID"].(string); parentID != "" {
			record.Set("parent_id", parentID)
		}

		// Merge cached parts with existing parts (if any)
		if len(cachedParts) > 0 {
			var existingParts []interface{}
			rawParts := record.Get("parts")
			if jsonRaw, ok := rawParts.(types.JSONRaw); ok {
				json.Unmarshal(jsonRaw, &existingParts)
			} else if ep, ok := rawParts.([]interface{}); ok {
				existingParts = ep
			}

			// Merge cached parts into existing parts (by part ID)
			for _, cachedPart := range cachedParts {
				if cp, ok := cachedPart.(map[string]interface{}); ok {
					cachedPartID := cp["id"]
					merged := false
					for i, ep := range existingParts {
						if epm, ok := ep.(map[string]interface{}); ok {
							if epm["id"] == cachedPartID {
								existingParts[i] = cachedPart
								merged = true
								break
							}
						}
					}
					if !merged {
						existingParts = append(existingParts, cachedPart)
					}
				}
			}

			record.Set("parts", existingParts)
			r.app.Logger().Info("✅ [Relay/Go] Merged cached parts into record", "ocMsgID", ocMsgID, "cached", len(cachedParts), "total", len(existingParts), "recordID", record.Id)
		} else {
			r.app.Logger().Debug("ℹ️ [Relay/Go] No cached parts to merge", "ocMsgID", ocMsgID)
		}
	} else {
		r.app.Logger().Warn("⚠️ [Relay/Go] Unknown role in message.updated", "role", role, "ocMsgID", ocMsgID)
		return
	}

	// 3. Update status (only advance, never demote)
	currentStatus := record.GetString("engine_message_status")
	if currentStatus == "completed" || currentStatus == "failed" {
		r.app.Logger().Debug("🛡️ [Relay/Go] Protecting finished status", "ocMsgID", ocMsgID, "current", currentStatus)
	} else {
		record.Set("engine_message_status", newStatus)
	}

	record.Set("updated", now)

	if err := r.app.Save(record); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to save message", "ocMsgID", ocMsgID, "error", err)
		return
	}

	// 4. Check if we need to generate synthetic text from tool outputs
	var finalParts []interface{}
	rawParts := record.Get("parts")
	if jsonRaw, ok := rawParts.(types.JSONRaw); ok {
		json.Unmarshal(jsonRaw, &finalParts)
	} else if ep, ok := rawParts.([]interface{}); ok {
		finalParts = ep
	}
	
	// Broadcast message_complete event to connected clients (after all parts are finalized)
	r.broadcastToChat(chatID, "message_complete", map[string]interface{}{
		"messageID": ocMsgID,
		"parts":     finalParts,
		"status":    newStatus,
	})
	
	preview := extractPreviewFromParts(finalParts)

	r.withChatLock(chatID, func(chat *core.Record) error {
		if preview != "" {
			current := chat.GetString("preview")
			if len(preview) > len(current) || (len(preview) == len(current) && preview != current) {
				r.app.Logger().Debug("✍️ [Relay/Go] Updating chat preview", "chatId", chatID, "preview", preview)
				chat.Set("preview", preview)
			}
		}
		chat.Set("last_active", time.Now().Format("2006-01-02 15:04:05.000Z"))
		return nil
	})

	r.app.Logger().Info("✅ [Relay/Go] Message completion handled", "ocMsgID", ocMsgID, "status", newStatus, "role", role, "parts", len(finalParts))
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
	// First pass: look for non-empty text parts
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

	// Second pass: if no text found, extract from tool parts (tool-only responses)
	for _, p := range parts {
		if pm, ok := p.(map[string]interface{}); ok {
			if pm["type"] != "tool" {
				continue
			}
			
			// Extract tool output from state.output or state.metadata.output
			if state, ok := pm["state"].(map[string]interface{}); ok {
				// Try state.output first
				if output, ok := state["output"].(string); ok && output != "" {
					if len(output) > 50 {
						return output[:50] + "..."
					}
					return output
				}
				
				// Try state.metadata.output
				if metadata, ok := state["metadata"].(map[string]interface{}); ok {
					if output, ok := metadata["output"].(string); ok && output != "" {
						if len(output) > 50 {
							return output[:50] + "..."
						}
						return output
					}
				}
			}
		}
	}

	return ""
}

// hasTextPart checks if any part in the parts array is a text part with non-empty text
func hasTextPart(parts []interface{}) bool {
	for _, p := range parts {
		if pm, ok := p.(map[string]interface{}); ok {
			if pm["type"] == "text" {
				text, _ := pm["text"].(string)
				if text == "" {
					text, _ = pm["content"].(string)
				}
				// Only return true if we have actual non-empty text
				if text != "" {
					return true
				}
			}
		}
	}
	return false
}

// ─── Stub Helpers for Future Implementation ──────────────────────────────────

// updateChatPreview updates the chat preview from cached text parts.
// This is a stub that will be fully implemented in a later task.
func (r *RelayService) updateChatPreview(chatID string, ocMsgID string) {
	// Get cached parts for this message
	parts, ok := r.partCache[ocMsgID]
	if !ok || len(parts) == 0 {
		return
	}

	// Extract text parts and build preview
	var textParts []interface{}
	for _, p := range parts {
		if pm, ok := p.(map[string]interface{}); ok {
			if pm["type"] == "text" {
				textParts = append(textParts, pm)
			}
		}
	}

	if len(textParts) == 0 {
		return
	}

	preview := extractPreviewFromParts(textParts)
	if preview == "" {
		return
	}

	// Update chat record
	r.withChatLock(chatID, func(chat *core.Record) error {
		current := chat.GetString("preview")
		if len(preview) > len(current) || (len(preview) == len(current) && preview != current) {
			r.app.Logger().Debug("✍️ [Relay/Go] Updating chat preview", "chatId", chatID, "preview", preview)
			chat.Set("preview", preview)
		}
		chat.Set("last_active", time.Now().Format("2006-01-02 15:04:05.000Z"))
		return nil
	})
}