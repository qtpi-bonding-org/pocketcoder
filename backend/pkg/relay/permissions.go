package relay

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

// handlePermissionAsked is triggered when OpenCode sends a 'permission.asked' event via SSE
func (r *RelayService) handlePermissionAsked(payload map[string]interface{}) {
	permID, ok := payload["id"].(string)
	if !ok {
		log.Printf("⚠️ [Relay] Permission payload missing ID")
		return
	}

	permission, _ := payload["permission"].(string)
	sessionID, _ := payload["sessionID"].(string)
	patterns, _ := payload["patterns"].([]interface{})
	metadata, _ := payload["metadata"].(map[string]interface{})
	message, _ := payload["message"].(string)
	
	// OpenCode sometimes nests tool info
	var messageID, callID string
	if tool, ok := payload["tool"].(map[string]interface{}); ok {
		messageID, _ = tool["messageID"].(string)
		callID, _ = tool["callID"].(string)
	}

	log.Printf("🛡️ [Relay] Permission Requested: %s (%s)", permID, permission)

	// 1. Resolve Chat ID
	chatID := r.resolveChatID(sessionID)
	if chatID == "" {
		log.Printf("⚠️ [Relay] No chat context for session %s, using fallback", sessionID)
		// Try to find ANY chat with this session ID? Or abort.
		// For now, let's create a draft permission anyway so it's visible.
	}

	// 2. Query Sovereign Authority
	// Since we are INSIDE the Go app, we can call the internal logic directly?
	// But sticking to the API keeps the separation clean and tests the endpoint.
	// Actually, for performance, we should ideally invoke the same logic as the endpoint.
	// Let's call the internal API endpoint via loopback or refactor logic.
	// For MVP parity, let's use the DB DIRECTLY here to create the permission record.
	// This replaces the "POST /api/pocketcoder/permission" call.

	// A. Check Whitelists (Replicating main.go logic here or calling shared func)
	isWhitelisted := r.checkWhitelist(permission, patterns, metadata)

	// B. Create Permission Record
	status := "draft"
	if isWhitelisted {
		status = "authorized"
	}

	collection, err := r.app.FindCollectionByNameOrId("permissions")
	if err != nil {
		log.Printf("❌ [Relay] Failed to find permissions collection: %v", err)
		return
	}

	record := core.NewRecord(collection)
	record.Set("opencode_id", permID)
	record.Set("session_id", sessionID)
	record.Set("chat", chatID)
	record.Set("permission", permission)
	record.Set("patterns", patterns)
	record.Set("metadata", metadata)
	record.Set("message_id", messageID)
	record.Set("call_id", callID)
	record.Set("status", status)
	record.Set("source", "relay-go")
	record.Set("message", message)
	
	if err := r.app.Save(record); err != nil {
		log.Printf("❌ [Relay] Failed to save permission record: %v", err)
		return
	}

	// C. Auto-Reply if Authorized
	if isWhitelisted {
		log.Printf("✅ [Relay] Auto-Authorized %s", permID)
		r.replyToOpenCode(permID, "once")
	} else {
		log.Printf("⏳ [Relay] Gated %s (Draft)", permID)
		// Wait for update via hook
	}
}

// listenForEvents connects to OpenCode SSE stream and handles all incoming events.
func (r *RelayService) listenForEvents() {
	url := fmt.Sprintf("%s/event", r.openCodeURL)
	log.Printf("🛡️ [Relay] Connecting SSE Firehose to %s...", url)

	for {
		resp, err := http.Get(url)
		if err != nil {
			log.Printf("❌ [Relay] SSE Connection failed: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		reader := resp.Body
		defer reader.Close()

		for {
			buf := make([]byte, 4096)
			n, err := reader.Read(buf)
			if err != nil {
				if err != io.EOF {
					log.Printf("❌ [Relay] SSE Read error: %v", err)
				}
				break // Reconnect
			}
			
			data := string(buf[:n])
			lines := strings.Split(data, "\n")
			for _, line := range lines {
				if strings.HasPrefix(line, "data: ") {
					jsonStr := strings.TrimPrefix(line, "data: ")
					var event map[string]interface{}
					if err := json.Unmarshal([]byte(jsonStr), &event); err == nil {
						eventType, _ := event["type"].(string)
						properties, _ := event["properties"].(map[string]interface{})
						if properties == nil {
							properties = event // Fallback
						}

						switch eventType {
						case "permission.asked":
							go r.handlePermissionAsked(properties)
						
						case "message.updated":
							// properties.info is the message envelope
							if info, ok := properties["info"].(map[string]interface{}); ok {
								sessionID, _ := info["sessionID"].(string)
								chatID := r.resolveChatID(sessionID)
								if chatID != "" {
									go r.syncAssistantMessage(chatID, properties)
								}
							}

						case "message.part.updated":
							// properties.part is the part, properties.delta is optional
							if part, ok := properties["part"].(map[string]interface{}); ok {
								sessionID, _ := part["sessionID"].(string)
								msgID, _ := part["messageID"].(string)
								chatID := r.resolveChatID(sessionID)
								if chatID != "" {
									// Trigger a poll or fetch the full message to ensure we have all parts
									// For deltas, we might want to be more efficient, but syncing the whole message
									// ensures we don't miss anything.
									go r.triggerMessageSync(chatID, sessionID, msgID)
								}
							}
						}
					}
				}
			}
		}
		time.Sleep(1 * time.Second)
	}
}

// triggerMessageSync fetches the latest state of a message and syncs it.
func (r *RelayService) triggerMessageSync(chatID, sessionID, msgID string) {
	url := fmt.Sprintf("%s/session/%s/message/%s", r.openCodeURL, sessionID, msgID)
	resp, err := http.Get(url)
	if err != nil {
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode == 200 {
		var data map[string]interface{}
		json.NewDecoder(resp.Body).Decode(&data)
		r.syncAssistantMessage(chatID, data)
	}
}

func (r *RelayService) replyToOpenCode(requestID string, replyType string) {
	url := fmt.Sprintf("%s/permission/%s/reply", r.openCodeURL, requestID)
	payload := map[string]string{
		"reply": replyType,
	}
	body, _ := json.Marshal(payload)

	resp, err := http.Post(url, "application/json", strings.NewReader(string(body)))
	if err != nil {
		log.Printf("❌ [Relay] Reply failed: %v", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode >= 400 {
		log.Printf("❌ [Relay] Reply rejected: %s", resp.Status)
	} else {
		log.Printf("✅ [Relay] Reply sent: %s -> %s", requestID, replyType)
	}
}
