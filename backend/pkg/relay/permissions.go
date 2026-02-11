package relay

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/permission"
)

// handlePermissionAsked is triggered when OpenCode sends a 'permission.asked' event via SSE
func (r *RelayService) handlePermissionAsked(properties map[string]interface{}) {
	permID, ok := properties["id"].(string)
	if !ok {
		log.Printf("⚠️ [Relay] Permission payload missing ID")
		return
	}

	permissionStr, _ := properties["permission"].(string)
	sessionID, _ := properties["sessionID"].(string)
	patterns, _ := properties["patterns"].([]interface{})
	metadata, _ := properties["metadata"].(map[string]interface{})
	message, _ := properties["message"].(string)
	
	// OpenCode sometimes nests tool info
	var messageID, callID string
	if tool, ok := properties["tool"].(map[string]interface{}); ok {
		messageID, _ = tool["messageID"].(string)
		callID, _ = tool["callID"].(string)
	}

	log.Printf("🛡️ [Relay] Permission Requested: %s (%s)", permID, permissionStr)

	// 1. Resolve Chat ID
	chatID := r.resolveChatID(sessionID)
	if chatID == "" {
		log.Printf("⚠️ [Relay] No chat context for session %s, using fallback", sessionID)
		// Try to find ANY chat with this session ID? Or abort.
		// For now, let's create a draft permission anyway so it's visible.
	}

	// 2. Query Sovereign Authority
	// We use the shared internal permission package to evaluate against whitelists.

	// A. Check Whitelists using shared authority
	patternsList := make([]string, 0, len(patterns))
	for _, p := range patterns {
		if s, ok := p.(string); ok {
			patternsList = append(patternsList, s)
		}
	}

	isWhitelisted, status := permission.Evaluate(r.app.(*pocketbase.PocketBase), permission.EvaluationInput{
		Permission: permissionStr,
		Patterns:   patternsList,
		Metadata:   metadata,
	})

	collection, err := r.app.FindCollectionByNameOrId("permissions")
	if err != nil {
		log.Printf("❌ [Relay] Failed to find permissions collection: %v", err)
		return
	}

	record := core.NewRecord(collection)
	record.Set("opencode_id", permID)
	record.Set("session_id", sessionID)
	record.Set("chat", chatID)
	record.Set("permission", permissionStr)
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

		scanner := bufio.NewScanner(resp.Body)
		for scanner.Scan() {
			line := scanner.Text()
			if !strings.HasPrefix(line, "data: ") {
				continue
			}

			jsonStr := strings.TrimPrefix(line, "data: ")
			if jsonStr == "" || jsonStr == "{}" {
				continue
			}

			var event map[string]interface{}
			if err := json.Unmarshal([]byte(jsonStr), &event); err != nil {
				log.Printf("❌ [Relay/SSE] Failed to unmarshal event: %v | Data: %s", err, jsonStr)
				continue
			}

			eventType, _ := event["type"].(string)
			if eventType == "server.heartbeat" {
				continue
			}

			log.Printf("📥 [Relay/SSE] Event: %s", eventType)
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
								role, _ := info["role"].(string)
								if role != "assistant" {
									// Only sync assistant messages to prevent mirror echos
									log.Printf("⏭️ [Relay/SSE] Skipping sync for role: %s", role)
									continue
								}
								sessionID, _ := info["sessionID"].(string)
								chatID := r.resolveChatID(sessionID)
								if chatID != "" {
									go r.syncAssistantMessage(chatID, properties)
								} else {
									log.Printf("⚠️ [Relay/SSE] Could not resolve Chat ID for Session: %s", sessionID)
								}
							} else {
								log.Printf("⚠️ [Relay/SSE] message.updated missing 'info' block")
							}

						case "message.part.updated":
							// properties.part is the part, properties.delta is optional
							if part, ok := properties["part"].(map[string]interface{}); ok {
								sessionID, _ := part["sessionID"].(string)
								msgID, _ := part["messageID"].(string)
								chatID := r.resolveChatID(sessionID)
								if chatID != "" {
									go r.triggerMessageSync(chatID, sessionID, msgID)
								} else {
									log.Printf("⚠️ [Relay/SSE] Could not resolve Chat ID for Session (part): %s", sessionID)
								}
							}

						case "session.idle":
							log.Printf("😴 [Relay/SSE] session.idle properties: %v", properties)
							sID, _ := properties["id"].(string)
							if sID == "" { sID, _ = properties["sessionID"].(string) }
							if sID != "" {
								go r.handleSessionIdle(sID)
							}

						case "session.updated":
							log.Printf("🔄 [Relay/SSE] session.updated properties: %v", properties)
							status, _ := properties["status"].(string)
							sID, _ := properties["id"].(string)
							if sID == "" { sID, _ = properties["sessionID"].(string) }
							if status == "idle" && sID != "" {
								go r.handleSessionIdle(sID)
							}
						}
					}
		resp.Body.Close()
		time.Sleep(1 * time.Second)
	}
}

// handleSessionIdle flips the turn back to the user and triggers the pump
func (r *RelayService) handleSessionIdle(sessionID string) {
	log.Printf("😴 [Relay/SSE] Session %s reported IDLE", sessionID)
	chatID := r.resolveChatID(sessionID)
	if chatID == "" {
		log.Printf("⚠️ [Relay/SSE] Could not resolve Chat ID for Session %s", sessionID)
		return
	}

	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		log.Printf("⚠️ [Relay/SSE] Could not find chat %s: %v", chatID, err)
		return
	}

	turn := chat.GetString("turn")
	log.Printf("🔄 [Relay/SSE] Chat %s current turn: %s", chatID, turn)

	if turn == "assistant" {
		log.Printf("😴 [Relay/SSE] Flipping turn for chat %s -> user", chatID)
		chat.Set("turn", "user")
		if err := r.app.Save(chat); err != nil {
			log.Printf("❌ [Relay] Failed to flip turn: %v", err)
		} else {
			// Trigger "The Pump" to catch any double-texting that was queued
			go r.recoverMissedMessages()
		}
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
	
	payload := map[string]interface{}{
		"reply": replyType,
	}
	if replyType == "reject" {
		payload["message"] = "User denied permission."
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

func (r *RelayService) registerPermissionHooks() {
	r.app.OnRecordAfterUpdateSuccess("permissions").BindFunc(func(e *core.RecordEvent) error {
		status := e.Record.GetString("status")
		id := e.Record.GetString("opencode_id")

		if status == "authorized" {
			log.Printf("🔓 [Relay] Permission AUTHORIZED: %s. Replying to OpenCode...", id)
			go r.replyToOpenCode(id, "once")
		} else if status == "denied" {
			log.Printf("🚫 [Relay] Permission DENIED: %s. Replying to OpenCode...", id)
			go r.replyToOpenCode(id, "reject")
		}
		return e.Next()
	})
}
