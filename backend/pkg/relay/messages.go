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
package relay

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
)

func (r *RelayService) recoverMissedMessages() {
	r.app.Logger().Info("🔄 [Relay/Go] Recovery Pump: Checking for unsent user messages...")
	// We check for user messages that are pending or were stuck in 'sending'
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
	// 1. Get Chat Record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		r.app.Logger().Warn("⚠️ [Relay/Go] Could not find chat context", "chatId", chatID, "msgId", msg.Id, "error", err)
		return
	}

	// 2. Mark as sending
	msg.Set("user_message_status", "sending")
	if err := r.app.Save(msg); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to claim message", "id", msg.Id, "error", err)
		return
	}

	// 3. Set turn to assistant immediately to indicate thinking
	chat.Set("turn", "assistant")
	if err := r.app.Save(chat); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to update chat turn", "error", err)
	}

	// 4. Get OpenCode Session
	sessionID, err := r.ensureSession(chatID)
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Session failure", "error", err)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}

	// 5. Send to OpenCode via prompt_async
	// We use prompt_async to avoid long-running HTTP timeouts. 
	// The SSE listener will handle syncing the assistant's response.
	url := fmt.Sprintf("%s/session/%s/prompt_async", r.openCodeURL, sessionID)
	
	var parts []interface{}
	partsRaw := msg.Get("parts")
	if jsonRaw, ok := partsRaw.(types.JSONRaw); ok {
		json.Unmarshal(jsonRaw, &parts)
	} else if p, ok := partsRaw.([]interface{}); ok {
		parts = p
	}

	payload := map[string]interface{}{
		"parts": parts,
	}
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

	// Success! Mark as delivered. We don't wait for the assistant response here.
	msg.Set("user_message_status", "delivered")
	if err := r.app.Save(msg); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to update message metadata", "id", msg.Id, "error", err)
	}
	r.app.Logger().Info("✅ [Relay/Go] Message delivered to OpenCode", "id", msg.Id)
}

func (r *RelayService) syncAssistantMessage(chatID string, ocData map[string]interface{}) {
	if chatID == "" {
		return
	}

	// Acquire per-chat mutex to prevent race conditions on chat record updates
	val, _ := r.chatMutexes.LoadOrStore(chatID, &sync.Mutex{})
	mu := val.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	r.app.Logger().Info("🔄 [Relay/Go] Syncing Assistant Message", "chatId", chatID)
	info, _ := ocData["info"].(map[string]interface{})
	if info == nil {
		info = ocData
	}
	ocMsgID, _ := info["id"].(string)
	if ocMsgID == "" {
		return
	}

	role, _ := info["role"].(string)
	if role != "" && role != "assistant" {
		// Only sync assistant messages to prevent mirror echoes
		r.app.Logger().Debug("⏭️ [Relay/Go] Skipping sync for non-assistant role", "role", role, "chatId", chatID)
		return
	}

	parts, _ := ocData["parts"].([]interface{})
	timeInfo, _ := info["time"].(map[string]interface{})
	completed := timeInfo != nil && timeInfo["completed"] != nil

	// 1. Check if message already exists (upsert)
	existing, _ := r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})

	var record *core.Record
	now := time.Now().Format("2006-01-02 15:04:05.000Z")

	if existing != nil {
		if existing.GetString("role") == "user" {
			// This is just a mirror of a user message we sent. Skip!
			return
		}
		record = existing
		record.Set("updated", now)
	} else {
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
		record.Set("updated", now)
	}

	// 2. Set Envelope Fields (1:1)
	record.Set("parent_id", info["parentID"])

	// 3. Set Status
	newStatus := "processing"
	if completed {
		newStatus = "completed"
	} else if info["error"] != nil {
		newStatus = "failed"
	}

	currentStatus := record.GetString("engine_message_status")
	if currentStatus == "completed" || currentStatus == "failed" {
		r.app.Logger().Debug("🛡️ [Relay/Go] Protecting finished status", "ocMsgID", ocMsgID, "current", currentStatus, "newAttempt", newStatus)
	} else {
		record.Set("engine_message_status", newStatus)
	}

	// 4. Normalize and Set Content
	normalizedParts := make([]interface{}, 0, len(parts))
	for _, p := range parts {
		if partMap, ok := p.(map[string]interface{}); ok {
			if partMap["type"] == "text" && partMap["text"] == nil && partMap["content"] != nil {
				partMap["text"] = partMap["content"]
			}
			normalizedParts = append(normalizedParts, partMap)
		} else {
			normalizedParts = append(normalizedParts, p)
		}
	}

	if len(normalizedParts) > 0 {
		r.app.Logger().Debug("📥 [Relay/Go] Message content update", "ocMsgID", ocMsgID, "partsCount", len(normalizedParts))
		record.Set("parts", normalizedParts)
	}
	
	// Extract preview from normalized parts
	preview := extractPreviewFromParts(normalizedParts)
	r.app.Logger().Debug("🔍 [Relay/Go] Extracted preview", "ocMsgID", ocMsgID, "preview", preview)
	if preview == "" && len(normalizedParts) > 0 {
		r.app.Logger().Debug("🧪 [Relay/Go] Empty preview with non-empty parts", "ocMsgID", ocMsgID)
	}

	if err := r.app.Save(record); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to sync assistant message", "ocMsgID", ocMsgID, "error", err)
		return
	}

	// 5. Check for subagent registration in tool results
	go r.checkForSubagentRegistration(chatID, parts)

	// Update parent chat record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		r.app.Logger().Warn("⚠️ [Relay/Go] Could not find chat", "chatId", chatID, "ocMsgID", ocMsgID, "error", err)
		return
	}

	currentPreview := chat.GetString("preview")
	
	// 'High Water Mark' Logic: Only update preview if it's getting better/longer.
	// This protects against partial events that might have missing parts.
	shouldUpdatePreview := false
	if preview != "" {
		if len(preview) > len(currentPreview) {
			shouldUpdatePreview = true
		} else if len(preview) == len(currentPreview) && preview != currentPreview {
			// Case where both are truncated at 50 chars but content evolved
			shouldUpdatePreview = true
		}
	}

	if shouldUpdatePreview {
		r.app.Logger().Info("✍️ [Relay/Go] Updating chat preview", "chatId", chatID, "preview", preview)
		chat.Set("preview", preview)
	}

	now = time.Now().Format("2006-01-02 15:04:05.000Z")
	chat.Set("last_active", now)
	chat.Set("updated", now)

	if err := r.app.Save(chat); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to update chat metadata", "chatId", chatID, "error", err)
	} else {
		r.app.Logger().Info("✅ [Relay/Go] Assistant sync complete", "ocMsgID", ocMsgID, "chatID", chatID)
	}
}

func (r *RelayService) ensureSession(chatID string) (string, error) {
	// Look up chat record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Chat lookup failed", "chatId", chatID, "error", err)
		return "", err
	}

	existingSession := chat.GetString("ai_engine_session_id")
	if existingSession != "" {
		// Verification: Is this session still alive on OpenCode?
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
				chat.Set("ai_engine_session_id", "")
				r.app.Save(chat)
			}
		} else {
			r.app.Logger().Warn("⚠️ [Relay/Go] Error verifying session", "id", existingSession, "error", vErr)
			// On network error, we don't clear it immediately to allow for transient issues
		}

		// If we haven't cleared it, it means we're opting to try using it for stability
		if chat.GetString("ai_engine_session_id") != "" {
			return existingSession, nil
		}
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
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to decode session response", "error", err)
	}
	r.app.Logger().Debug("📥 [Relay/Go] OpenCode session creation response", "data", res)

	newID, _ := res["id"].(string)
	if newID != "" {
		chat.Set("ai_engine_session_id", newID)
		chat.Set("engine_type", "opencode")
		if err := r.app.Save(chat); err != nil {
			r.app.Logger().Error("❌ [Relay/Go] Failed to update chat with session id", "chatId", chatID, "error", err)
		} else {
			r.app.Logger().Info("✅ [Relay/Go] Linked Chat to OpenCode Session", "chatId", chatID, "sessionId", newID)
		}
		return newID, nil
	}

	return "", fmt.Errorf("failed to extract session id from response")
}

func (r *RelayService) checkForSubagentRegistration(chatID string, parts []interface{}) {
	for _, p := range parts {
		part, ok := p.(map[string]interface{})
		if !ok {
			continue
		}

		partType, _ := part["type"].(string)

		// OpenCode uses type:"tool" with state.output for tool results,
		// not type:"tool_result" with content.
		var toolName string
		var content interface{}

		if partType == "tool_result" {
			// Legacy format
			toolName, _ = part["name"].(string)
			content = part["content"]
			if content == nil {
				content = part["text"]
			}
		} else if partType == "tool" {
			// OpenCode format: type:"tool", tool:"cao_handoff", state.output:"..."
			toolName, _ = part["tool"].(string)
			if state, ok := part["state"].(map[string]interface{}); ok {
				content = state["output"]
			}
		} else {
			continue
		}

		if toolName != "handoff" && toolName != "assign" && toolName != "cao_handoff" && toolName != "cao_assign" {
			continue
		}

		var resultData map[string]interface{}
		
		// Handle both stringified JSON and pre-parsed map
		if contentStr, ok := content.(string); ok && contentStr != "" {
			if err := json.Unmarshal([]byte(contentStr), &resultData); err != nil {
				r.app.Logger().Warn("⚠️ [Relay] Failed to parse tool_result content string as JSON", "error", err, "content", contentStr)
				continue
			}
		} else if contentMap, ok := content.(map[string]interface{}); ok {
			resultData = contentMap
		} else if content != nil {
			// Try to Marshal/Unmarshal if it's some other non-nil type (e.g. nested map)
			if bs, err := json.Marshal(content); err == nil {
				json.Unmarshal(bs, &resultData)
			}
		}

		if resultData == nil {
			continue
		}

		// Check for _pocketcoder_sys_event discriminator at top level.
		// This field is set by HandoffResult model to distinguish PocketCoder
		// system events from normal tool output.
		sysEvent, _ := resultData["_pocketcoder_sys_event"].(string)
		if sysEvent == "" {
			// Fallback to non-aliased name if pydantic didn't use the alias
			sysEvent, _ = resultData["pocketcoder_sys_event"].(string)
		}
		
		if sysEvent != "handoff_complete" {
			continue
		}

		subagentID, _ := resultData["subagent_id"].(string)
		terminalID, _ := resultData["terminal_id"].(string)
		agentProfile, _ := resultData["agent_profile"].(string)

		// Handle tmux_window_id - it could be float64 from JSON
		var tmuxWindowID int
		if tmuxWindow, ok := resultData["tmux_window_id"].(float64); ok {
			tmuxWindowID = int(tmuxWindow)
		}

		r.app.Logger().Info("🤖 [Relay] Detected Subagent Registration",
			"terminalID", terminalID,
			"subagentID", subagentID,
			"windowID", tmuxWindowID,
			"profile", agentProfile,
			"chatID", chatID)

		r.registerSubagentInDB(chatID, subagentID, terminalID, tmuxWindowID, agentProfile)
	}
}

func (r *RelayService) registerSubagentInDB(chatID, subagentID, terminalID string, tmuxWindowID int, agentProfile string) {
	if subagentID == "" {
		r.app.Logger().Warn("⚠️ [Relay] Empty subagent_id, skipping registration", "chatId", chatID, "terminalId", terminalID, "windowId", tmuxWindowID)
		return
	}

	// Look for existing record
	existing, _ := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": subagentID})
	if existing != nil {
		return
	}

	collection, err := r.app.FindCollectionByNameOrId("subagents")
	if err != nil {
		r.app.Logger().Error("❌ [Relay] Could not find subagents collection", "error", err)
		return
	}

	// Resolve delegatingAgentID from chat's ai_engine_session_id field
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
			"subagentID", subagentID,
			"delegatingAgentID", delegatingAgentID,
			"windowID", tmuxWindowID,
			"chatID", chatID,
			"profile", agentProfile)
	}
}

// extractPreviewFromParts extracts a preview text from message parts.
// It finds the first text part and truncates it to 50 characters if needed.
func extractPreviewFromParts(parts []interface{}) string {
	preview := ""
	for _, part := range parts {
		if partMap, ok := part.(map[string]interface{}); ok {
			if text, textOk := partMap["text"].(string); textOk {
				preview = text
				break
			}
		}
	}
	if len(preview) > 50 {
		preview = preview[:50] + "..."
	}
	return preview
}
