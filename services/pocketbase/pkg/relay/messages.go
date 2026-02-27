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
	"sort"
	"strings"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
)

// recoverMissedMessages checks for user messages that were not processed.
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

// processUserMessage sends a user message to OpenCode.
func (r *RelayService) processUserMessage(msg *core.Record) {
	r.app.Logger().Info("📨 [Relay/Go] Processing Message", "id", msg.Id)

	chatID := msg.GetString("chat")
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		r.app.Logger().Warn("⚠️ [Relay/Go] Could not find chat context", "chatId", chatID, "msgId", msg.Id, "error", err)
		return
	}

	msg.Set("user_message_status", "sending")
	if err := r.app.Save(msg); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to claim message", "id", msg.Id, "error", err)
		return
	}

	chat.Set("turn", "assistant")
	if err := r.app.Save(chat); err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to update chat turn", "error", err)
	}

	sessionID, err := r.ensureSession(chatID)
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Session failure", "error", err)
		msg.Set("user_message_status", "failed")
		r.app.Save(msg)
		return
	}

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
		r.app.Logger().Error("❌ [Relay/Go] Failed to update message metadata", "id", msg.Id, "error", err)
	}
	r.app.Logger().Info("✅ [Relay/Go] Message delivered to OpenCode", "id", msg.Id)
}

// ─── SSE Event Handlers ───────────────────────────────────────────────────────

// saveWithRetry handles database save operations with an exponential backoff retry
// for referential integrity errors (race conditions during chat/message creation).
func (r *RelayService) saveWithRetry(record *core.Record) error {
	var lastErr error
	for attempt := 0; attempt < 20; attempt++ {
		if err := r.app.Save(record); err == nil {
			return nil
		} else {
			lastErr = err
			errStr := err.Error()
			if strings.Contains(errStr, "Failed to find all relation records") {
				log.Printf("⚠️ [Relay/Go] Relation not found yet for record %s (%s), retrying save... (attempt %d)", record.Id, record.Collection().Name, attempt+1)
				time.Sleep(time.Duration(50*(attempt+1)) * time.Millisecond)
				continue
			}
			log.Printf("❌ [Relay/Go] Non-retryable save error for record %s (%s): %v", record.Id, record.Collection().Name, err)
			return err
		}
	}
	log.Printf("❌ [Relay/Go] saveWithRetry EXHAUSTED for record %s (%s): %v", record.Id, record.Collection().Name, lastErr)
	return lastErr
}

// ensureMessageRecord finds or creates a message record safely.
func (r *RelayService) ensureMessageRecord(chatID, ocMsgID string, role string, part map[string]interface{}) (*core.Record, error) {
	// 1. Existing check
	record, err := r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})
	if err == nil && record != nil {
		return record, nil
	}

	// 2. Echo check for pending user messages
	// We check for any pending user message if the role is "user" OR if the role is ambiguous ("")
	if role == "user" || role == "" {
		records, _ := r.app.FindRecordsByFilter("messages", "chat = {:chat} && role = 'user' && ai_engine_message_id = ''", "-created", 1, 0, map[string]any{"chat": chatID})
		if len(records) > 0 {
			localUserMsg := records[0]
			localUserMsg.Set("ai_engine_message_id", ocMsgID)
			localUserMsg.Set("user_message_status", "delivered")
			if err := r.saveWithRetry(localUserMsg); err == nil {
				log.Printf("🔗 [Relay/Go] Mapped pending user message: %s -> %s", ocMsgID, localUserMsg.Id)
				return localUserMsg, nil
			}
		}
		
		if role == "user" {
			// If we definitely expected a user echo but found nothing, skip it – handleMessageCompletion will definitively handle it
			return nil, fmt.Errorf("pending user message not found for echo")
		}
	}

	// 3. Assistant detection (Heuristics from git history)
	var partType string
	if part != nil {
		partType, _ = part["type"].(string)
	}

	isAssistant := (role == "assistant") || (partType == "step-start")
	if !isAssistant && part != nil {
		if part["parentID"] != nil {
			isAssistant = true
		}
		if metadata, ok := part["metadata"].(map[string]interface{}); ok && metadata["parentID"] != nil {
			isAssistant = true
		}
	}

	// Fallback: check chat turn
	if !isAssistant {
		chat, _ := r.app.FindRecordById("chats", chatID)
		if chat != nil && chat.GetString("turn") == "assistant" {
			isAssistant = true
		}
	}

	if !isAssistant {
		// Not sure if assistant – skip for now to avoid hijacking user echoes.
		// We'll try again when more parts arrive or when completion hits.
		return nil, fmt.Errorf("message role ambiguous, skipping initial create")
	}

	// 4. Create new assistant record
	collection, err := r.app.FindCollectionByNameOrId("messages")
	if err != nil {
		return nil, err
	}

	record = core.NewRecord(collection)
	record.Set("chat", chatID)
	record.Set("role", "assistant")
	record.Set("ai_engine_message_id", ocMsgID)
	record.Set("engine_message_status", "processing")
	record.Set("created", time.Now().Format("2006-01-02 15:04:05.000Z"))

	if err := r.saveWithRetry(record); err != nil {
		return nil, err
	}

	log.Printf("🆕 [Relay/Go] Created assistant record: %s", ocMsgID)
	return record, nil
}

// upsertMessagePart handles a "message.part.updated" SSE event.
// It buffers parts in memory (partCache) and broadcasts them without blocking for DB writes.
func (r *RelayService) upsertMessagePart(chatID string, part map[string]interface{}) {
	ocMsgID, _ := part["messageID"].(string)
	if ocMsgID == "" {
		return
	}

	// 0. Deduplication & Authoritative Check
	r.completedMessagesMu.RLock()
	isCompleted := r.completedMessages[ocMsgID]
	r.completedMessagesMu.RUnlock()

	if isCompleted {
		// Late arrival: If already completed, we still broadcast AND sync to DB
		// to avoid data loss (e.g. final text deltas arriving after completion).
		r.broadcastToChat(chatID, "message_part", map[string]interface{}{
			"messageID": ocMsgID,
			"part":      part,
		})
		
		// Cache it temporarily so broadcastMessageSnapshot can see it
		r.partCacheMu.Lock()
		if _, ok := r.partCache[ocMsgID]; !ok {
			r.partCache[ocMsgID] = make(map[string]interface{})
		}
		partID, _ := part["id"].(string)
		r.partCache[ocMsgID][partID] = part
		r.partCacheMu.Unlock()

		// Run a snapshot sync for this latecomer
		go func() {
			log.Printf("🩹 [Relay/Go] Late-arriving part for %s, syncing to DB", ocMsgID)
			r.broadcastMessageSnapshot(chatID, ocMsgID)
			
			// Optional: cleanup after a short delay since completion already happened
			time.Sleep(2 * time.Second)
			r.partCacheMu.Lock()
			delete(r.partCache, ocMsgID)
			r.partCacheMu.Unlock()
		}()
		return
	}

	// Lock this message to serialize with handled completion
	val, _ := r.msgMutexes.LoadOrStore(ocMsgID, &sync.Mutex{})
	mu := val.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	partID, _ := part["id"].(string)
	partType, _ := part["type"].(string)

	// Normalize text parts
	if partType == "text" {
		if text, _ := part["text"].(string); text == "" {
			if content, _ := part["content"].(string); content != "" {
				part["text"] = content
			}
		}
	}

	// 1. Update In-Memory Cache & Deduplicate
	r.partCacheMu.Lock()
	_, exists := r.partCache[ocMsgID]
	if !exists {
		r.partCache[ocMsgID] = make(map[string]interface{})
	}
	
	// Rigorous Deduplication: Only proceed if content changed
	existing, ok := r.partCache[ocMsgID][partID]
	if ok {
		existingJSON, _ := json.Marshal(existing)
		incomingJSON, _ := json.Marshal(part)
		if string(existingJSON) == string(incomingJSON) {
			r.partCacheMu.Unlock()
			return
		}
	}

	r.partCache[ocMsgID][partID] = part
	r.partCacheMu.Unlock()

	// 1b. Ensure record exists (OUTSIDE partCacheMu lock, but INSIDE msgMutex)
	if !exists {
		// WRITE #1 (INIT): Create the record immediately on first part arrival
		// This ensures polling tests and UI see the processing state instantly.
		role, _ := part["role"].(string)
		
		// If role is missing, we must infer it safely.
		// Echoes (user messages) should already exist in DB.
		// If we create a record here, it's almost certainly an assistant message.
		if role == "" {
			role = "assistant"
		}

		// Synchronous call within the per-message mutex is safe because 
		// upsertMessagePart is called in a goroutine per-event.
		_, err := r.ensureMessageRecord(chatID, ocMsgID, role, part)
		if err != nil {
			log.Printf("❌ [Relay/Go] Failed to ensure record for %s: %v", ocMsgID, err)
		}
	}

	// 2. Schedule Snapshot Broadcast (Throttled Sequencer)
	r.scheduleSnapshotBroadcast(chatID, ocMsgID)

	// 3. Subagent handoff check
	if partType == "tool" {
		go r.checkForSubagentRegistration(chatID, []interface{}{part})
	}
}

// applyMessagePartDelta handles a "message.part.delta" SSE event for real-time text streaming.
func (r *RelayService) applyMessagePartDelta(chatID, ocMsgID, partID, delta string) {
	if ocMsgID == "" || partID == "" || delta == "" {
		return
	}

	// Lock this message to serialize with other updates
	val, _ := r.msgMutexes.LoadOrStore(ocMsgID, &sync.Mutex{})
	mu := val.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	// 1. Update In-Memory Cache
	r.partCacheMu.Lock()
	parts, ok := r.partCache[ocMsgID]
	if !ok {
		parts = make(map[string]interface{})
		r.partCache[ocMsgID] = parts
	}

	partObj, ok := parts[partID]
	var part map[string]interface{}
	if !ok {
		// Create a stub text part if it doesn't exist
		part = map[string]interface{}{
			"id":   partID,
			"type": "text",
			"text": "",
		}
		parts[partID] = part
	} else {
		part = partObj.(map[string]interface{})
	}

	// 2. Append delta to text
	currentText, _ := part["text"].(string)
	part["text"] = currentText + delta
	r.partCacheMu.Unlock()

	// 3. Immediately broadcast the delta to listeners for smooth UI
	r.broadcastTextDelta(chatID, partID, delta)

	// 4. Schedule authoritative Snapshot Sync to DB
	r.scheduleSnapshotBroadcast(chatID, ocMsgID)
}

// scheduleSnapshotBroadcast debounces snapshots to provide a smooth, ordered 50fps UI experience.
func (r *RelayService) scheduleSnapshotBroadcast(chatID, ocMsgID string) {
	r.broadcastTimersMu.Lock()
	defer r.broadcastTimersMu.Unlock()

	if timer, ok := r.broadcastTimers[ocMsgID]; ok {
		timer.Stop()
	}

	r.broadcastTimers[ocMsgID] = time.AfterFunc(20*time.Millisecond, func() {
		r.broadcastMessageSnapshot(chatID, ocMsgID)
		r.broadcastTimersMu.Lock()
		delete(r.broadcastTimers, ocMsgID)
		r.broadcastTimersMu.Unlock()
	})
}

// broadcastMessageSnapshot pulls all parts, sorts them by ID, sends a full snapshot,
// AND syncs the parts to the database record for UI/Test visibility.
func (r *RelayService) broadcastMessageSnapshot(chatID, ocMsgID string) {
	val, ok := r.msgMutexes.Load(ocMsgID)
	if !ok { return }
	mu := val.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	r.partCacheMu.RLock()
	partsMap, ok := r.partCache[ocMsgID]
	if !ok || len(partsMap) == 0 {
		r.partCacheMu.RUnlock()
		return
	}
	
	// Copy parts for sorting
	parts := make([]map[string]interface{}, 0, len(partsMap))
	for _, p := range partsMap {
		parts = append(parts, p.(map[string]interface{}))
	}
	r.partCacheMu.RUnlock()

	// 1. Rigorous Lexicographical Sort by part.id
	sort.Slice(parts, func(i, j int) bool {
		return parts[i]["id"].(string) < parts[j]["id"].(string)
	})

	// 1. Authoritative Record & Role retrieval
	role := "assistant" // Default for safety
	record, err := r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})
	if err == nil && record != nil {
		role = record.GetString("role")
	}

	// 2. Broadcast the snapshot to SSE clients
	r.broadcastToChat(chatID, "message_snapshot", map[string]interface{}{
		"messageID": ocMsgID,
		"role":      role,
		"parts":     parts,
	})

	// 3. Authoritative Sync to DB for live visibility (essential for tests)
	// We do this SYNCHRONOUSLY within the msgMutex to avoid race conditions with handleMessageCompletion.
	// Since we are inside a per-message mutex and debounced by 20ms, this is performant.
	record, err = r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})
	if err == nil && record != nil {
		status := record.GetString("engine_message_status")
		// CRITICAL: Only update if not already final to avoid overwriting completion status or final parts snapshot.
		if status != "completed" && status != "failed" {
			record.Set("parts", parts)
			if status == "" {
				record.Set("engine_message_status", "processing")
			}
			r.saveWithRetry(record)
		}
	}
}

// handleMessageCompletion handles a "message.updated" SSE event.
// It performs a final authoritative sync from the partCache to the database.
func (r *RelayService) handleMessageCompletion(chatID string, info map[string]interface{}) {
	ocMsgID, _ := info["id"].(string)
	if ocMsgID == "" {
		return
	}

	// 0. Deduplication - only block if we've already handled a FINAL update (completed or error)
	r.completedMessagesMu.RLock()
	if r.completedMessages[ocMsgID] {
		r.completedMessagesMu.RUnlock()
		return
	}
	r.completedMessagesMu.RUnlock()

	timeInfo, _ := info["time"].(map[string]interface{})
	completed := timeInfo != nil && timeInfo["completed"] != nil
	hasError := info["error"] != nil
	role, _ := info["role"].(string)

	if completed || hasError || role == "user" {
		r.completedMessagesMu.Lock()
		r.completedMessages[ocMsgID] = true
		r.completedMessagesMu.Unlock()
	}

	log.Printf("📋 [Relay/Go] Received message.updated - ID: %s, role: %s, completed: %v, error: %v", ocMsgID, role, completed, hasError)

	newStatus := "processing"
	if completed || role == "user" {
		newStatus = "completed"
	} else if hasError {
		newStatus = "failed"
	}

	// 1. Lock this message to prevent concurrent completion/parts handling
	val, _ := r.msgMutexes.LoadOrStore(ocMsgID, &sync.Mutex{})
	mu := val.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	// 1b. Cancel any pending broadcast timers - this is the final sync
	r.broadcastTimersMu.Lock()
	if timer, ok := r.broadcastTimers[ocMsgID]; ok {
		timer.Stop()
		delete(r.broadcastTimers, ocMsgID)
	}
	r.broadcastTimersMu.Unlock()

	// 2. Flush parts from cache
	r.partCacheMu.Lock()
	partsMap, hasCachedParts := r.partCache[ocMsgID]
	if newStatus != "processing" {
		delete(r.partCache, ocMsgID)
	}
	r.partCacheMu.Unlock()

	// 3. Ensure record exists (with retry)
	record, err := r.ensureMessageRecord(chatID, ocMsgID, role, nil)
	if err != nil {
		log.Printf("❌ [Relay/Go] handleMessageCompletion: failed to ensure record %s: %v", ocMsgID, err)
		return
	}

	// 4. Authoritative Parts Merge
	if hasCachedParts {
		var existingParts []interface{}
		rawParts := record.Get("parts")
		if jsonRaw, ok := rawParts.(types.JSONRaw); ok {
			json.Unmarshal(jsonRaw, &existingParts)
		} else if ep, ok := rawParts.([]interface{}); ok {
			existingParts = ep
		}

		for _, part := range partsMap {
			pData := part.(map[string]interface{})
			partID := pData["id"]
			merged := false
			for i, ep := range existingParts {
				if epm, ok := ep.(map[string]interface{}); ok {
					if epm["id"] == partID {
						existingParts[i] = part
						merged = true
						break
					}
				}
			}
			if !merged {
				existingParts = append(existingParts, part)
			}
		}

		// Rigorous Ordered Merge: Always sort by lexical ID before final save
		sort.Slice(existingParts, func(i, j int) bool {
			idI, _ := existingParts[i].(map[string]interface{})["id"].(string)
			idJ, _ := existingParts[j].(map[string]interface{})["id"].(string)
			return idI < idJ
		})

		record.Set("parts", existingParts)
	}

	if record.GetString("role") == "" {
		record.Set("role", role)
	}
	
	currentStatus := record.GetString("engine_message_status")
	if currentStatus != "completed" && currentStatus != "failed" {
		record.Set("engine_message_status", newStatus)
	}

	if parentID, _ := info["parentID"].(string); parentID != "" {
		record.Set("parent_id", parentID)
	}

	record.Set("updated", time.Now().Format("2006-01-02 15:04:05.000Z"))

	// 5. Final Authoritative Save
	if err := r.saveWithRetry(record); err != nil {
		log.Printf("❌ [Relay/Go] Failed to save final record %s: %v", ocMsgID, err)
		return
	}

	log.Printf("✅ [Relay/Go] Final record saved: %s (Status: %s)", ocMsgID, record.GetString("engine_message_status"))

	// 6. Broadcast completion
	var finalParts []interface{}
	recordRawParts := record.Get("parts")
	if jsonRaw, ok := recordRawParts.(types.JSONRaw); ok {
		json.Unmarshal(jsonRaw, &finalParts)
	} else if ep, ok := recordRawParts.([]interface{}); ok {
		finalParts = ep
	}

	r.broadcastToChat(chatID, "message_complete", map[string]interface{}{
		"messageID": ocMsgID,
		"parts":     finalParts,
		"status":    newStatus,
	})

	// 7. Update Chat Metadata (High Water Mark)
	preview := extractPreviewFromParts(finalParts)
	r.withChatLock(chatID, func(chat *core.Record) error {
		if preview != "" {
			current := chat.GetString("preview")
			if len(preview) > len(current) || (len(preview) == len(current) && preview != current) {
				chat.Set("preview", preview)
			}
		}
		chat.Set("last_active", time.Now().Format("2006-01-02 15:04:05.000Z"))
		return nil
	})

	// 8. Delayed cleanup of tracking maps to allow for very late SSE messages
	go func() {
		time.Sleep(30 * time.Second)
		r.completedMessagesMu.Lock()
		delete(r.completedMessages, ocMsgID)
		r.completedMessagesMu.Unlock()

		r.partCacheMu.Lock()
		delete(r.partCache, ocMsgID)
		r.partCacheMu.Unlock()
		
		r.msgMutexes.Delete(ocMsgID)
	}()
}

func (r *RelayService) ensureSession(chatID string) (string, error) {
	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
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
				return existingSession, nil
			}
			if vResp.StatusCode == http.StatusNotFound {
				// Safety: Only clear if it's not a known subagent session ID.
				// This prevents Poco from thinking its own session is gone while it's actually
				// just relaying for a subagent that might have just completed.
				isSubagent, _ := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": existingSession})
				if isSubagent == nil {
					r.app.Logger().Warn("🗑️ [Relay/Go] Clearing vanished session from chat", "chatID", chatID, "sessionID", existingSession)
					chat.Set("ai_engine_session_id", "")
					r.app.Save(chat)
				}
			}
		} else {
			return existingSession, nil // Opt-in stability
		}
	}

	reqURL := fmt.Sprintf("%s/session", r.openCodeURL)
	payload := `{"directory": "/workspace", "agent": "poco"}`
	resp, err := http.Post(reqURL, "application/json", strings.NewReader(payload))
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return "", fmt.Errorf("opencode rejected session creation: %s", resp.Status)
	}

	var res map[string]interface{}
	json.NewDecoder(resp.Body).Decode(&res)
	newID, _ := res["id"].(string)
	if newID != "" {
		chat.Set("ai_engine_session_id", newID)
		chat.Set("engine_type", "opencode")
		r.app.Save(chat)
		return newID, nil
	}

	return "", fmt.Errorf("failed to extract session id")
}

func (r *RelayService) checkForSubagentRegistration(chatID string, parts []interface{}) {
	for _, p := range parts {
		part, ok := p.(map[string]interface{})
		if !ok { continue }

		partType, _ := part["type"].(string)
		var toolName string
		var content interface{}

		if partType == "tool" {
			toolName, _ = part["tool"].(string)
			if state, ok := part["state"].(map[string]interface{}); ok {
				content = state["output"]
			}
		} else { continue }

		if toolName != "handoff" && toolName != "assign" && toolName != "cao_handoff" && toolName != "cao_assign" {
			continue
		}

		var resultData map[string]interface{}
		if contentStr, ok := content.(string); ok && contentStr != "" {
			json.Unmarshal([]byte(contentStr), &resultData)
		}

		if resultData == nil { continue }
		sysEvent, _ := resultData["_pocketcoder_sys_event"].(string)
		if sysEvent == "" {
			sysEvent, _ = resultData["pocketcoder_sys_event"].(string)
		}
		
		if sysEvent != "handoff_complete" { continue }

		subagentID, _ := resultData["subagent_id"].(string)
		terminalID, _ := resultData["terminal_id"].(string)
		agentProfile, _ := resultData["agent_profile"].(string)
		var tmuxWindowID int
		if tmuxWindow, ok := resultData["tmux_window_id"].(float64); ok {
			tmuxWindowID = int(tmuxWindow)
		}

		r.registerSubagentInDB(chatID, subagentID, terminalID, tmuxWindowID, agentProfile)
	}
}

func (r *RelayService) registerSubagentInDB(chatID, subagentID, terminalID string, tmuxWindowID int, agentProfile string) {
	existing, _ := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": subagentID})
	if existing != nil { return }

	collection, err := r.app.FindCollectionByNameOrId("subagents")
	if err != nil { return }

	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil { return }
	delegatingAgentID := chat.GetString("ai_engine_session_id")

	record := core.NewRecord(collection)
	record.Set("subagent_id", subagentID)
	record.Set("delegating_agent_id", delegatingAgentID)
	record.Set("tmux_window_id", tmuxWindowID)
	record.Set("chat", chatID)

	if err := r.app.Save(record); err == nil {
		log.Printf("✅ [Relay] Persisted Subagent Lineage: %s", subagentID)
	}
}

func extractPreviewFromParts(parts []interface{}) string {
	preview := ""
	for _, part := range parts {
		if partMap, ok := part.(map[string]interface{}); ok {
			type_val, _ := partMap["type"].(string)
			if type_val == "text" {
				if text, ok := partMap["text"].(string); ok && text != "" {
					preview = text
					break
				}
			}
		}
	}
	if len(preview) > 50 {
		preview = preview[:50] + "..."
	}
	return preview
}

// ─── Error & Lifecycle Handlers ─────────────────────────────────────────────

func (r *RelayService) handleMessageError(infoData map[string]interface{}) {
	ocMsgID, _ := infoData["id"].(string)
	sessionID, _ := infoData["sessionID"].(string)
	chatID := r.resolveChatID(sessionID)
	if chatID == "" {
		return
	}

	errorData, _ := infoData["error"].(map[string]interface{})
	envelope := NewProviderError(errorData)

	// Find PB record ID for this message
	record, err := r.app.FindFirstRecordByFilter("messages", "ai_engine_message_id = {:id}", map[string]any{"id": ocMsgID})
	if err == nil && record != nil {
		r.handleErrorCompletion(chatID, record.Id, envelope)
	}
}

func (r *RelayService) handleErrorCompletion(chatID string, pbMsgID string, envelope ErrorEnvelope) {
	record, err := r.app.FindRecordById("messages", pbMsgID)
	if err != nil {
		return
	}

	record.Set("engine_message_status", "failed")

	// Store error in parts
	var parts []interface{}
	partsRaw := record.Get("parts")
	if jsonRaw, ok := partsRaw.(types.JSONRaw); ok {
		json.Unmarshal(jsonRaw, &parts)
	} else if p, ok := partsRaw.([]interface{}); ok {
		parts = p
	}

	errPart := map[string]interface{}{
		"type":   "error",
		"source": envelope.GetSource(),
		"error":  envelope,
	}
	parts = append(parts, errPart)
	record.Set("parts", parts)

	r.saveWithRetry(record)

	// Broadcast failure
	r.broadcastError(chatID, pbMsgID, envelope)

	// Update chat turn to user so they can try again
	r.withChatLock(chatID, func(chat *core.Record) error {
		chat.Set("turn", "user")
		return nil
	})
}

func (r *RelayService) handleSessionError(properties map[string]interface{}) {
	sessionID, _ := properties["id"].(string)
	if sessionID == "" {
		sessionID, _ = properties["sessionID"].(string)
	}
	chatID := r.resolveChatID(sessionID)
	if chatID == "" {
		return
	}

	errorData, _ := properties["error"].(map[string]interface{})
	envelope := NewProviderError(errorData)

	r.broadcastToChat(chatID, "session_error", envelope)
}

func (r *RelayService) handleStreamClosed() {
	r.app.Logger().Warn("⚠️ [Relay/Go] SSE Stream closed unexpectedly.")
	envelope := NewInfrastructureError(ErrCodeStreamClosed)
	r.failAllActiveSessions(envelope)
}

func (r *RelayService) handleHeartbeatTimeout() {
	r.app.Logger().Warn("⚠️ [Relay/Go] SSE Heartbeat timeout.")
	envelope := NewInfrastructureError(ErrCodeHeartbeatTimeout)
	r.failAllActiveSessions(envelope)
}