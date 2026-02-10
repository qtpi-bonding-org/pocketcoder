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
	log.Println("🔄 [Relay/Go] Checking for missed user messages...")
	// We check for user messages where metadata.processed is NOT true
	// Note: In SQLite/PocketBase, nested JSON checks look like this or use FindRecordsByFilter
	records, err := r.app.FindRecordsByFilter("messages", "role = 'user' && metadata.processed != true", "", 100, 0)
	if err != nil {
		log.Printf("⚠️ [Relay/Go] Recovery check failed: %v", err)
		return
	}

	if len(records) > 0 {
		log.Printf("🔄 [Relay/Go] Found %d missed messages. Processing...", len(records))
		for _, msg := range records {
			go r.processUserMessage(msg)
		}
	} else {
		log.Println("✅ [Relay/Go] No missed messages found.")
	}
}

func (r *RelayService) processUserMessage(msg *core.Record) {
	log.Printf("📨 [Relay/Go] Processing Message: %s", msg.Id)

	chatID := msg.GetString("chat")
	if chatID == "" {
		log.Printf("⚠️ [Relay/Go] Message %s has no chat session", msg.Id)
		return
	}

	// 1. Mark as processed immediately (idempotency)
	meta, _ := msg.Get("metadata").(map[string]any)
	if meta == nil {
		meta = make(map[string]any)
	}
	meta["processed"] = true
	msg.Set("metadata", meta)
	if err := r.app.Save(msg); err != nil {
		log.Printf("❌ [Relay/Go] Failed to update message %s: %v", msg.Id, err)
		return
	}

	// Update parent chat record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		log.Printf("⚠️ [Relay/Go] Could not find chat %s for message %s: %v", chatID, msg.Id, err)
		return
	}

	chat.Set("last_active", time.Now())
	
	// Extract preview from message parts
	var messageParts []interface{}
	partsRaw := msg.Get("parts")
	if partsRaw != nil {
		if jsonRaw, ok := partsRaw.(types.JSONRaw); ok {
			err := json.Unmarshal(jsonRaw, &messageParts)
			if err != nil {
				log.Printf("⚠️ [Relay/Go] Failed to unmarshal message parts: %v", err)
			}
		} else {
			// If not JSONRaw, it might be directly []interface{} from another source
			if p, ok := partsRaw.([]interface{}); ok {
				messageParts = p
			} else {
				log.Printf("⚠️ [Relay/Go] Message parts is neither JSONRaw nor []interface{}: %T", partsRaw)
			}
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
		log.Printf("❌ [Relay/Go] Failed to update chat %s last_active and preview: %v", chatID, err)
	}

	// 2. Get OpenCode Session (Resolve via Chat)
	sessionID, err := r.ensureSession(chatID)
	if err != nil {
		log.Printf("❌ [Relay/Go] Session failure for chat %s: %v", chatID, err)
		return
	}
	log.Printf("🔍 [Relay/Go] Using Session: %s for Chat: %s", sessionID, chatID)

	// 3. Just Send (Pure Pass-through - No filtering, no blanks)
	parts := msg.Get("parts")
	
	// 4. Send to OpenCode
	url := fmt.Sprintf("%s/session/%s/message", r.openCodeURL, sessionID)
	payload := map[string]interface{}{
		"parts": parts,
	}
	body, _ := json.Marshal(payload)
	log.Printf("📡 [Relay/Go] 📤 PUSHING TO AI: %s", string(body))

	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Post(url, "application/json", strings.NewReader(string(body)))
	
	if err != nil {
		log.Printf("❌ [Relay/Go] OpenCode prompt failed: %v", err)
		return
	}
	defer resp.Body.Close()

	log.Printf("📡 [Relay/Go] 📥 AI RESPONSE: %v", resp.Status)

	if resp.StatusCode >= 400 {
		log.Printf("❌ [Relay/Go] OpenCode prompt rejected: %s", resp.Status)
		return
	}

	// 5. Poll for Response (Simplest MVP match for Node behavior)
	var promptRes map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&promptRes)
	
	msgID_OC, _ := promptRes["id"].(string) 
	if msgID_OC == "" {
		// Try info.id
		if info, ok := promptRes["info"].(map[string]interface{}); ok {
			msgID_OC, _ = info["id"].(string)
		}
	}

	if msgID_OC != "" {
		log.Printf("✅ [Relay/Go] Prompt accepted. OpenCode Msg: %s. Waiting for SSE...", msgID_OC)
		// Perform one immediate sync in case it's already finished or has immediate data
		go r.triggerMessageSync(chatID, sessionID, msgID_OC)
	}
}


func (r *RelayService) syncAssistantMessage(chatID string, ocData map[string]interface{}) {
	log.Printf("🔄 [Relay/Go] Syncing Assistant Message for chat %s", chatID)
	info, _ := ocData["info"].(map[string]interface{})
	if info == nil {
		// Try flat structure
		info = ocData
	}

	ocMsgID, _ := info["id"].(string)
	if ocMsgID == "" {
		return
	}

	parts, _ := ocData["parts"].([]interface{})
	timeInfo, _ := info["time"].(map[string]interface{})
	completed := timeInfo != nil && timeInfo["completed"] != nil

	// 1. Check if message already exists (upsert)
	existing, _ := r.app.FindFirstRecordByFilter("messages", "opencode_id = {:id}", map[string]any{"id": ocMsgID})

	var record *core.Record
	if existing != nil {
		record = existing
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

	chat.Set("last_active", time.Now())
	
	// Extract preview from message parts
	var messageParts []interface{} // Renamed from 'parts' to avoid conflict and for clarity
	partsRaw := record.Get("parts")
	if partsRaw != nil {
		if jsonRaw, ok := partsRaw.(types.JSONRaw); ok {
			err := json.Unmarshal(jsonRaw, &messageParts)
			if err != nil {
				log.Printf("⚠️ [Relay/Go] Failed to unmarshal message parts in syncAssistantMessage: %v", err)
			}
		} else {
			// If not JSONRaw, it might be directly []interface{} from another source
			if p, ok := partsRaw.([]interface{}); ok {
				messageParts = p
			} else {
				log.Printf("⚠️ [Relay/Go] Message parts in syncAssistantMessage is neither JSONRaw nor []interface{}: %T", partsRaw)
			}
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
		log.Printf("🔍 [Relay/Go] Found existing session %s for chat %s", existingSession, chatID)
		return existingSession, nil
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
