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

// @pocketcoder-core: Sovereign Relay. The orchestration layer that syncs OpenCode with the Sandbox.
package relay

import (
	"fmt"
	"log"
	"sync"
	"sync/atomic"
	"time"

	"github.com/pocketbase/pocketbase/core"
)


// RelayService orchestrates communication between PocketBase and OpenCode
type RelayService struct {
	app           core.App
	openCodeURL   string
	lastHeartbeat atomic.Int64 // Unix timestamp
	isReady       bool
	chatMutexes   sync.Map // Map of chatID (string) -> *sync.Mutex for per-chat locking
	msgMutexes    sync.Map // Map of ocMsgID (string) -> *sync.Mutex for per-message locking
 
	// partCache stores parts for messages whose role hasn't been determined yet
	// Key: ocMsgID (OpenCode message ID), Value: map of partID -> part data
	partCache     map[string]map[string]interface{} // map[ocMsgID]map[partID]PartData
	partCacheMu   sync.RWMutex

	// completedMessages tracks which messages have been flushed to prevent late arrivals
	completedMessages   map[string]bool // map[ocMsgID]bool
	completedMessagesMu sync.RWMutex

	// sessionChatCache maps OpenCode session IDs (including subagents) to Chat IDs
	sessionChatCache   map[string]string
	sessionChatCacheMu sync.RWMutex

	// brokerTimers manages the debouncing/batching of message snapshots for the realtime broker (50ms)
	brokerTimers   map[string]*time.Timer // map[ocMsgID]*time.Timer
	brokerTimersMu sync.Mutex

	// dbTimers manages the debouncing of message snapshots to the database (1000ms)
	dbTimers   map[string]*time.Timer // map[ocMsgID]*time.Timer
	dbTimersMu sync.Mutex
}

// NewRelayService creates a new Relay instance
func NewRelayService(app core.App, openCodeURL string) *RelayService {
	return &RelayService{
		app:               app,
		openCodeURL:       openCodeURL,
		completedMessages: make(map[string]bool),
		partCache:         make(map[string]map[string]interface{}),
		sessionChatCache:  make(map[string]string),
		brokerTimers:      make(map[string]*time.Timer),
		dbTimers:          make(map[string]*time.Timer),
	}
}

// Start begins the relay's background processes:
// 1. Permission Listener (SSE)
// 2. Message Pump (Hooks)
// 3. Agent Sync (Hooks)
// 4. Health Monitor Watchdog
func (r *RelayService) Start() {
	log.Println("🚀 [Relay] Starting Go-based Relay Service...")

	// 1. Start SSE Listener (in background)
	log.Println("🔌 [Relay] Starting SSE listener...")
	go r.listenForEvents()

	// 2. Register Hooks
	log.Println("🪝 [Relay] Registering hooks...")
	r.registerMessageHooks()
	r.registerAgentHooks()
	r.registerSSHKeyHooks()
	r.registerPermissionHooks()
	r.registerSopHooks()
	r.registerMcpHooks()

	// 3. Catch up on missed messages
	log.Println("🔄 [Relay] Starting message recovery...")
	go r.recoverMissedMessages()

	// 4. Start Health Monitor Watchdog
	log.Println("💓 [Relay] Starting health monitor...")
	go r.startHealthMonitor()
	
	log.Println("✅ [Relay] All services started successfully")
}

// withChatLock ensures that chat record updates are atomic and thread-safe.
func (r *RelayService) withChatLock(chatID string, fn func(chat *core.Record) error) error {
	if chatID == "" {
		return fmt.Errorf("empty chatID")
	}

	val, _ := r.chatMutexes.LoadOrStore(chatID, &sync.Mutex{})
	mu := val.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	chat, err := r.app.FindRecordById("chats", chatID)
	if err != nil {
		return err
	}

	if err := fn(chat); err != nil {
		return err
	}

	return r.app.Save(chat)
}


func (r *RelayService) startHealthMonitor() {
	ticker := time.NewTicker(20 * time.Second)
	defer ticker.Stop()

	for range ticker.C {
		now := time.Now().Unix()
		lastHeartbeat := r.lastHeartbeat.Load()
		// Watchdog: If we haven't seen ANYTHING from OpenCode in 45 seconds, it's offline.
		if lastHeartbeat > 0 && now-lastHeartbeat > 45 {
			if r.isReady {
				r.app.Logger().Warn("⚠️ [Relay/Health] OpenCode responsiveness lost (Watchdog triggered).")
				r.isReady = false
				r.updateHealthcheck("offline")
			}
		} else if lastHeartbeat > 0 {
			// If we see activity again, recover to ready
			if !r.isReady {
				r.app.Logger().Info("💓 [Relay/Health] OpenCode responsiveness recovered.")
				r.isReady = true
				r.updateHealthcheck("ready")
			}
		}
	}
}

// failAllActiveSessions queries all messages with status="processing" and marks them as failed
// with the provided error envelope. This is used by handleHeartbeatTimeout and handleStreamClosed
// to fail all sessions when connection to OpenCode is lost.
// Requirements: 1.2, 7.1
func (r *RelayService) failAllActiveSessions(envelope ErrorEnvelope) {
	// Query all messages with engine_message_status = "processing"
	records, err := r.app.FindRecordsByFilter(
		"messages",
		"engine_message_status = 'processing'",
		"", // no sort
		0,  // no limit
		0,  // no offset
	)
	if err != nil {
		r.app.Logger().Error("❌ [Relay/Go] Failed to query active messages", "error", err)
		return
	}

	failedCount := 0
	for _, msg := range records {
		chatID := msg.GetString("chat")
		messageID := msg.Id

		if chatID == "" {
			r.app.Logger().Warn("⚠️ [Relay/Go] Skipping message without chatID", "messageID", messageID)
			continue
		}

		// Call handleErrorCompletion for each active message
		r.handleErrorCompletion(chatID, messageID, envelope)
		failedCount++
	}

	r.app.Logger().Info("✅ [Relay/Go] Failed all active sessions", "count", failedCount, "errorCode", envelope.GetSource())
}

func (r *RelayService) registerMessageHooks() {
	// Intercept new user messages and send to OpenCode
	r.app.OnRecordAfterCreateSuccess("messages").BindFunc(func(e *core.RecordEvent) error {
		role := e.Record.GetString("role")
		userMessageStatus := e.Record.GetString("user_message_status")

		// If no user_message_status is set, default to pending for user messages
		if role == "user" && (userMessageStatus == "pending" || userMessageStatus == "") {
			r.app.Logger().Info("[Relay] Intercepted user message", "id", e.Record.Id)
			go r.processUserMessage(e.Record)
		}
		return e.Next()
	})
}

func (r *RelayService) registerAgentHooks() {
	// Sync agent files on Create/Update
	sync := func(e *core.RecordEvent) error {
		go r.deployAgent(e.Record)
		return e.Next()
	}

	r.app.OnRecordAfterCreateSuccess("ai_agents").BindFunc(sync)
	r.app.OnRecordAfterUpdateSuccess("ai_agents").BindFunc(sync)
	
	// Initial Sync on startup
	go r.syncAllAgents()
}
