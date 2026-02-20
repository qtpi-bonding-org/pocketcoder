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
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
)

func (r *RelayService) recoverMissedMessages() {
	log.Println("🔄 [Relay/Go] Recovery Pump: Checking for unsent user messages...")
	// We check for user messages that are pending or were stuck in 'sending'
	records, err := r.app.FindRecordsByFilter("messages", "role = 'user' && (user_message_status = 'pending' || user_message_status = '')", "created", 100, 0)
	if err != nil {
		log.Printf("⚠️ [Relay/Go] Recovery check failed: %v", err)
		return
	}

	if len(records) > 0 {
		log.Printf("🔄 [Relay/Go] Pump found %d unsent messages. Processing...", len(records))
		for _, msg := range records {
			go r.processUserMessage(msg)
		}
	} else {
		log.Println("✅ [Relay/Go] Recovery Pump: All messages sent.")
	}
}

func (r *RelayService) processUserMessage(msg *core.Record) {
	log.Printf("📨 [Relay/Go] Processing Message: %s", msg.Id)

	chatID := msg.GetString("chat")
	// 1. Get Chat Record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		log.Printf("⚠️ [Relay/Go] Could not find chat %s for message %s: %v", chatID, msg.Id, err)
		return
	}

	// 2. Mark as sending
	msg.Set("user_message_status", "sending")
	if err := r.app.Save(msg); err != nil {
		log.Printf("❌ [Relay/Go] Failed to claim message %s: %v", msg.Id, err)
		return
	}

	// 3. Set turn to assistant immediately to indicate thinking
	chat.Set("turn", "assistant")
	if err := r.app.Save(chat); err != nil {
		log.Printf("❌ [Relay/Go] Failed to update chat turn: %v", err)
	}

	// 4. Get OpenCode Session
	sessionID, err := r.ensureSession(chatID)
	if err != nil {
		log.Printf("❌ [Relay/Go] Session failure: %v", err)
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
	log.Printf("📡 [Relay/Go] 📤 ASYNC PUSH (Msg: %s): %s", msg.Id, string(body))

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Post(url, "application/json", strings.NewReader(string(body)))

	if err != nil {
		log.Printf("❌ [Relay/Go] OpenCode prompt failed: %v", err)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("❌ [Relay/Go] OpenCode prompt rejected: %s", resp.Status)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}

	// Success! Mark as delivered. We don't wait for the assistant response here.
	msg.Set("user_message_status", "delivered")
	if err := r.app.Save(msg); err != nil {
		log.Printf("❌ [Relay/Go] Failed to update message %s after delivery: %v", msg.Id, err)
	}
	log.Printf("✅ [Relay/Go] Message %s delivered to OpenCode.", msg.Id)
}


func (r *RelayService) syncAssistantMessage(chatID string, ocData map[string]interface{}) {
	log.Printf("🔄 [Relay/Go] Syncing Assistant Message for chat %s", chatID)
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
			log.Printf("❌ [Relay/Go] Collection error: %v", err)
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
	record.Set("agent_name", info["agent"])
	record.Set("provider_name", info["providerID"])
	record.Set("model_name", info["modelID"])
	record.Set("cost", info["cost"])
	record.Set("tokens", info["tokens"])
	record.Set("error", info["error"])
	record.Set("finish_reason", info["finish"])

	// 3. Set Status
	status := "processing"
	if completed {
		status = "completed"
	} else if info["error"] != nil {
		status = "failed"
	}
	record.Set("engine_message_status", status)

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
		log.Printf("📥 [Relay/Go] Syncing parts for %s: %v", ocMsgID, normalizedParts)
		record.Set("parts", normalizedParts)
	}
	
	// Extract preview from normalized parts (before saving to avoid DB read race condition)
	preview := extractPreviewFromParts(normalizedParts)

	if err := r.app.Save(record); err != nil {
		log.Printf("❌ [Relay/Go] Failed to sync message %s: %v", ocMsgID, err)
		return
	}

	// 5. Check for subagent registration in tool results
	go r.checkForSubagentRegistration(chatID, parts)

	// Update parent chat record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		log.Printf("⚠️ [Relay/Go] Could not find chat %s for assistant message %s: %v", chatID, ocMsgID, err)
		return
	}

	now = time.Now().Format("2006-01-02 15:04:05.000Z")
	chat.Set("last_active", now)
	chat.Set("updated", now)
	chat.Set("preview", preview)

	if err := r.app.Save(chat); err != nil {
		log.Printf("❌ [Relay/Go] Failed to update chat %s last_active and preview for assistant message: %v", chatID, err)
	}
}

func (r *RelayService) ensureSession(chatID string) (string, error) {
	// Look up chat record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		log.Printf("❌ [Relay/Go] Chat lookup failed for %s: %v", chatID, err)
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
				log.Printf("✅ [Relay/Go] Existing session %s is still alive.", existingSession)
				return existingSession, nil
			}
			
			log.Printf("⚠️ [Relay/Go] Existing session %s returned status %d.", existingSession, vResp.StatusCode)
			if vResp.StatusCode == http.StatusNotFound {
				log.Printf("⚠️ [Relay/Go] Session %s is gone (404), cleaning up...", existingSession)
				chat.Set("ai_engine_session_id", "")
				r.app.Save(chat)
			}
		} else {
			log.Printf("⚠️ [Relay/Go] Error verifying session %s: %v", existingSession, vErr)
			// On network error, we don't clear it immediately to allow for transient issues
		}

		// If we haven't cleared it, it means we're opting to try using it for stability
		if chat.GetString("ai_engine_session_id") != "" {
			return existingSession, nil
		}
	}

	// Create new session
	log.Printf("🆕 [Relay/Go] Creating new OpenCode session for chat %s", chatID)
	reqURL := fmt.Sprintf("%s/session", r.openCodeURL)
	payload := `{"directory": "/workspace", "agent": "poco"}`
	resp, err := http.Post(reqURL, "application/json", strings.NewReader(payload))
	if err != nil {
		log.Printf("❌ [Relay/Go] OpenCode session creation request failed: %v", err)
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("❌ [Relay/Go] OpenCode session creation rejected: %s", resp.Status)
		return "", fmt.Errorf("opencode rejected session creation: %s", resp.Status)
	}

	var res map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&res); err != nil {
		log.Printf("❌ [Relay/Go] Failed to decode session response: %v", err)
	}
	log.Printf("📥 [Relay/Go] OpenCode session creation response: %+v", res)

	newID, _ := res["id"].(string)
	if newID != "" {
		chat.Set("ai_engine_session_id", newID)
		chat.Set("engine_type", "opencode")
		if err := r.app.Save(chat); err != nil {
			log.Printf("❌ [Relay/Go] Failed to update chat %s with ai_engine_session_id: %v", chatID, err)
		} else {
			log.Printf("✅ [Relay/Go] Linked Chat %s to OpenCode Session %s", chatID, newID)
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
		var content string

		if partType == "tool_result" {
			// Legacy format
			toolName, _ = part["name"].(string)
			content, _ = part["content"].(string)
			if content == "" {
				content, _ = part["text"].(string)
			}
		} else if partType == "tool" {
			// OpenCode format: type:"tool", tool:"cao_handoff", state.output:"..."
			toolName, _ = part["tool"].(string)
			if state, ok := part["state"].(map[string]interface{}); ok {
				content, _ = state["output"].(string)
			}
		} else {
			continue
		}

		if toolName != "handoff" && toolName != "assign" && toolName != "cao_handoff" && toolName != "cao_assign" {
			continue
		}

		if content == "" {
			continue
		}

		var resultData map[string]interface{}
		if err := json.Unmarshal([]byte(content), &resultData); err != nil {
			log.Printf("⚠️ [Relay] Failed to parse tool_result content as JSON: %v", err)
			continue
		}

		// Check for _pocketcoder_sys_event discriminator at top level.
		// This field is set by HandoffResult model to distinguish PocketCoder
		// system events from normal tool output.
		sysEvent, _ := resultData["_pocketcoder_sys_event"].(string)
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

		log.Printf("🤖 [Relay] Detected Subagent Registration: terminal=%s, subagent=%s, window=%d, profile=%s for Chat %s",
			terminalID, subagentID, tmuxWindowID, agentProfile, chatID)

		r.registerSubagentInDB(chatID, subagentID, terminalID, tmuxWindowID, agentProfile)
	}
}

func (r *RelayService) registerSubagentInDB(chatID, subagentID, terminalID string, tmuxWindowID int, agentProfile string) {
	if subagentID == "" {
		log.Printf("⚠️ [Relay] Empty subagent_id for chat %s, terminal=%s, window=%d — skipping registration (will retry on next handoff)", chatID, terminalID, tmuxWindowID)
		return
	}

	// Look for existing record
	existing, _ := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": subagentID})
	if existing != nil {
		return
	}

	collection, err := r.app.FindCollectionByNameOrId("subagents")
	if err != nil {
		log.Printf("❌ [Relay] Could not find subagents collection: %v", err)
		return
	}

	// Resolve delegatingAgentID from chat's ai_engine_session_id field
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		log.Printf("❌ [Relay] Could not find chat %s: %v", chatID, err)
		return
	}
	delegatingAgentID := chat.GetString("ai_engine_session_id")

	record := core.NewRecord(collection)
	record.Set("subagent_id", subagentID)
	record.Set("delegating_agent_id", delegatingAgentID)
	record.Set("tmux_window_id", tmuxWindowID)
	record.Set("chat", chatID)

	if err := r.app.Save(record); err != nil {
		log.Printf("❌ [Relay] Failed to save subagent record: %v", err)
	} else {
		log.Printf("✅ [Relay] Persisted Subagent Lineage: subagent=%s, delegating_agent=%s, window=%d, chat=%s, profile=%s",
			subagentID, delegatingAgentID, tmuxWindowID, chatID, agentProfile)
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
