package relay

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"github.com/pocketbase/pocketbase/core"
)

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

	// 2. Get OpenCode Session (Resolve via Chat)
	sessionID, err := r.ensureSession(chatID)
	if err != nil {
		log.Printf("❌ [Relay/Go] Session failure for chat %s: %v", chatID, err)
		return
	}

	// 3. Extract Text
	parts := msg.Get("parts") // Need to inspect structure
	// Assuming parts is a JSON array
	partBytes, _ := json.Marshal(parts)
	var typedParts []map[string]interface{}
	json.Unmarshal(partBytes, &typedParts)

	text := ""
	for _, p := range typedParts {
		if p["type"] == "text" {
			if content, ok := p["content"].(string); ok {
				text += content + "\n"
			} else if txt, ok := p["text"].(string); ok {
				text += txt + "\n"
			}
		}
	}

	if text == "" {
		log.Printf("⚠️ [Relay/Go] Skipping empty message %s", msg.Id)
		return
	}

	// 4. Send to OpenCode
	url := fmt.Sprintf("%s/session/%s/message", r.openCodeURL, sessionID)
	payload := map[string]interface{}{
		"parts": []map[string]interface{}{
			{"type": "text", "text": text},
		},
	}
	body, _ := json.Marshal(payload)

	resp, err := http.Post(url, "application/json", strings.NewReader(string(body)))
	if err != nil {
		log.Printf("❌ [Relay/Go] OpenCode prompt failed: %v", err)
		return
	}
	defer resp.Body.Close() // This defer was already present, ensuring resp.Body is closed.

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

	// 4. Set Content
	if len(parts) > 0 {
		record.Set("parts", parts)
	}

	if err := r.app.Save(record); err != nil {
		log.Printf("❌ [Relay/Go] Failed to sync message %s: %v", ocMsgID, err)
	}
}

func (r *RelayService) ensureSession(chatID string) (string, error) {
	// Look up chat record
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		return "", err
	}
	
	existingSession := chat.GetString("opencode_id")
	if existingSession != "" {
		// Validate it?
		return existingSession, nil
	}
	
	// Create new session
	reqURL := fmt.Sprintf("%s/session", r.openCodeURL)
	payload := `{"directory": "/workspace", "agent": "poco"}`
	resp, err := http.Post(reqURL, "application/json", strings.NewReader(payload))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	
	var res map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&res)
	
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
	
	return "", fmt.Errorf("failed to create session")
}
