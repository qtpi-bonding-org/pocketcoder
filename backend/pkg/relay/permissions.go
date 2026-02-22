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

// @pocketcoder-core: Permission Relayer. Handles real-time authorization requests.
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
		r.app.Logger().Warn("⚠️ [Relay] Permission payload missing ID")
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
		r.app.Logger().Warn("⚠️ [Relay] No chat context for session, using fallback", "sessionId", sessionID)
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
		r.app.Logger().Error("❌ [Relay] Failed to find permissions collection", "error", err)
		return
	}

	record := core.NewRecord(collection)
	record.Set("ai_engine_permission_id", permID)
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
		r.app.Logger().Error("❌ [Relay] Failed to save permission record", "id", permID, "error", err)
		return
	}

	// C. Auto-Reply if Authorized
	if isWhitelisted {
		r.app.Logger().Info("✅ [Relay] Auto-Authorized permission", "id", permID)
		r.replyToOpenCode(permID, "once")
	} else {
		r.app.Logger().Info("⏳ [Relay] Gated permission (Draft)", "id", permID)
		// Wait for update via hook
	}
}

// listenForEvents connects to OpenCode SSE stream and handles all incoming events.
func (r *RelayService) listenForEvents() {
	url := fmt.Sprintf("%s/event", r.openCodeURL)
	r.app.Logger().Info("🛡️ [Relay] Connecting SSE Firehose", "url", url)

	for {
		resp, err := http.Get(url)
		if err != nil {
			r.app.Logger().Error("❌ [Relay] SSE Connection failed", "error", err)
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
				r.app.Logger().Error("❌ [Relay/SSE] Failed to unmarshal event", "error", err, "data", jsonStr)
				continue
			}

			eventType, _ := event["type"].(string)
			r.app.Logger().Debug("📥 [Relay/SSE] Event received", "type", eventType)
			properties, _ := event["properties"].(map[string]interface{})
			if properties == nil {
				properties = event // Fallback
			}

			switch eventType {
			case "server.heartbeat":
				r.lastHeartbeat = time.Now().Unix()
				if !r.isReady {
					r.app.Logger().Info("💓 [Relay/SSE] First heartbeat received. System ready.")
					r.isReady = true
					r.updateHealthcheck("ready")
				}
				continue

			case "permission.asked":
				go r.handlePermissionAsked(properties)

			case "message.updated":
				// properties = { info: { id, role, time.completed, cost, tokens, ... } }
				if info, ok := properties["info"].(map[string]interface{}); ok {
					sessionID, _ := info["sessionID"].(string)
					chatID := r.resolveChatID(sessionID)
					if chatID != "" {
						go r.handleMessageCompletion(chatID, info)
					} else {
						r.app.Logger().Warn("⚠️ [Relay/SSE] Could not resolve Chat ID for session", "sessionId", sessionID)
					}
				} else {
					r.app.Logger().Warn("⚠️ [Relay/SSE] message.updated missing 'info' block")
				}

				
				case "message.part.updated":
				// properties = { part: { id, type, text, messageID, sessionID, ... } }
				// One complete part — upsert it directly, no HTTP round-trip needed.
				if part, ok := properties["part"].(map[string]interface{}); ok {
					sessionID, _ := part["sessionID"].(string)
					chatID := r.resolveChatID(sessionID)
					if chatID != "" {
						go r.upsertMessagePart(chatID, part)
					} else {
						log.Printf("⚠️ [Relay/SSE] Could not resolve Chat ID for session (part): %s", sessionID)
					}
				}

			case "session.idle":
				r.app.Logger().Debug("😴 [Relay/SSE] session.idle", "properties", properties)
				sID, _ := properties["id"].(string)
				if sID == "" { sID, _ = properties["sessionID"].(string) }
				if sID != "" {
					go r.handleSessionIdle(sID)
				}

			case "session.updated":
				r.app.Logger().Debug("🔄 [Relay/SSE] session.updated", "properties", properties)
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
		r.app.Logger().Warn("⚠️ [Relay/SSE] Could not find chat", "chatId", chatID, "error", err)
		return
	}

	turn := chat.GetString("turn")
	r.app.Logger().Debug("🔄 [Relay/SSE] Checking turn state", "chatId", chatID, "turn", turn)

	if turn == "assistant" {
		// Safeguard: Do not flip the turn to user if there is a pending permission request.
		// A pending permission means the assistant's turn is technically "paused" awaiting human input,
		// but not yet finished. Holding the assistant turn ensures tests and UI wait for the post-approval response.
		pending, _ := r.app.FindFirstRecordByFilter("permissions", "chat = {:chat} && status = 'pending'", map[string]any{"chat": chatID})
		if pending != nil {
			r.app.Logger().Info("⏳ [Relay/SSE] Session idle but pending permission exists, holding assistant turn", "chatId", chatID)
			return
		}

		r.app.Logger().Info("😴 [Relay/SSE] Flipping turn to user", "chatId", chatID)
		err := r.withChatLock(chatID, func(chat *core.Record) error {
			chat.Set("turn", "user")
			return nil
		})
		if err != nil {
			r.app.Logger().Error("❌ [Relay] Failed to flip turn", "chatId", chatID, "error", err)
		} else {
			// Trigger "The Pump" to catch any double-texting that was queued
			go r.recoverMissedMessages()
		}
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
		r.app.Logger().Error("❌ [Relay] Reply to OpenCode failed", "id", requestID, "error", err)
		return
	}
	defer resp.Body.Close()
	
	if resp.StatusCode >= 400 {
		r.app.Logger().Error("❌ [Relay] Reply rejected by OpenCode", "id", requestID, "status", resp.Status)
	} else {
		r.app.Logger().Info("✅ [Relay] Reply sent to OpenCode", "id", requestID, "reply", replyType)
	}
}

func (r *RelayService) updateHealthcheck(status string) {
	collection, err := r.app.FindCollectionByNameOrId("healthchecks")
	if err != nil {
		r.app.Logger().Warn("⚠️ [Relay] healthchecks collection not found, skipping sync")
		return
	}

	// We use a single record with a specific ID or just the first one
	existing, _ := r.app.FindFirstRecordByFilter("healthchecks", "name = 'opencode'")

	var record *core.Record
	if existing != nil {
		record = existing
	} else {
		record = core.NewRecord(collection)
		record.Set("name", "opencode")
	}

	record.Set("status", status)
	record.Set("last_ping", time.Now().Format("2006-01-02 15:04:05.000Z"))

	if err := r.app.Save(record); err != nil {
		log.Printf("❌ [Relay] Failed to save healthcheck: %v", err)
	}
}

func (r *RelayService) registerPermissionHooks() {
	r.app.OnRecordAfterUpdateSuccess("permissions").BindFunc(func(e *core.RecordEvent) error {
		status := e.Record.GetString("status")
		id := e.Record.GetString("ai_engine_permission_id")

		if status == "authorized" {
			r.app.Logger().Info("🔓 [Relay] Permission AUTHORIZED. Replying to OpenCode...", "id", id)
			go r.replyToOpenCode(id, "once")
		} else if status == "denied" {
			r.app.Logger().Info("🚫 [Relay] Permission DENIED. Replying to OpenCode...", "id", id)
			go r.replyToOpenCode(id, "reject")
		}
		return e.Next()
	})
}
