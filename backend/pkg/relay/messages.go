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
	records, err := r.app.FindRecordsByFilter("messages", "role = 'user' && (delivery = 'pending' || delivery = '')", "created", 100, 0)
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
	msg.Set("delivery", "sending")
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
		msg.Set("delivery", "failed")
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
		msg.Set("delivery", "failed")
		r.app.Save(msg)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("❌ [Relay/Go] OpenCode prompt rejected: %s", resp.Status)
		msg.Set("delivery", "failed")
		r.app.Save(msg)
		return
	}

	// Success! Mark as delivered. We don't wait for the assistant response here.
	msg.Set("delivery", "delivered")
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
	existing, _ := r.app.FindFirstRecordByFilter("messages", "opencode_id = {:id}", map[string]any{"id": ocMsgID})

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
		record.Set("opencode_id", ocMsgID)
		record.Set("created", now)
		record.Set("updated", now)
	}

	// 2. Set Envelope Fields (1:1)
	record.Set("parent_id", info["parentID"])
	record.Set("agent", info["agent"])
	record.Set("provider_id", info["providerID"])
	record.Set("model_id", info["modelID"])
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
	record.Set("status", status)

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

	if err := r.app.Save(record); err != nil {
		log.Printf("❌ [Relay/Go] Failed to sync message %s: %v", ocMsgID, err)
		return
	}

	// Update parent chat record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		log.Printf("⚠️ [Relay/Go] Could not find chat %s for assistant message %s: %v", chatID, ocMsgID, err)
		return
	}

	now = time.Now().Format("2006-01-02 15:04:05.000Z")
	chat.Set("last_active", now)
	chat.Set("updated", now)

	// Extract preview from message parts
	var messageParts []interface{}
	partsRaw := record.Get("parts")
	if partsRaw != nil {
		if jsonRaw, ok := partsRaw.(types.JSONRaw); ok {
			err := json.Unmarshal(jsonRaw, &messageParts)
			if err != nil {
				log.Printf("⚠️ [Relay/Go] Failed to unmarshal message parts in syncAssistantMessage: %v", err)
			}
		} else if p, ok := partsRaw.([]interface{}); ok {
			messageParts = p
		}
	}
	preview := ""
	for _, part := range messageParts {
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

	existingSession := chat.GetString("opencode_id")
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
				chat.Set("opencode_id", "")
				r.app.Save(chat)
			}
		} else {
			log.Printf("⚠️ [Relay/Go] Error verifying session %s: %v", existingSession, vErr)
			// On network error, we don't clear it immediately to allow for transient issues
		}

		// If we haven't cleared it, it means we're opting to try using it for stability
		if chat.GetString("opencode_id") != "" {
			return existingSession, nil
		}
	}

	// Create new session
	log.Printf("🆕 [Relay/Go] Creating new OpenCode session for chat %s", chatID)
	reqURL := fmt.Sprintf("%s/session", r.openCodeURL)
	payload := `{"directory": "/workspace", "agent": "build"}`
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
		chat.Set("opencode_id", newID)
		if err := r.app.Save(chat); err != nil {
			log.Printf("❌ [Relay/Go] Failed to update chat %s with opencode_id: %v", chatID, err)
		} else {
			log.Printf("✅ [Relay/Go] Linked Chat %s to OpenCode Session %s", chatID, newID)
		}
		return newID, nil
	}

	return "", fmt.Errorf("failed to extract session id from response")
}
