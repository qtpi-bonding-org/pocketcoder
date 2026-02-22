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

// @pocketcoder-core: Sovereign Relay. The "Spinal Cord" that syncs Reasoning with Reality.
package relay

import (
	"fmt"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

// RelayService orchestrates communication between PocketBase and OpenCode
type RelayService struct {
	app           core.App
	openCodeURL   string
	lastHeartbeat int64 // Unix timestamp
	isReady       bool
	chatMutexes sync.Map // Map of chatID (string) -> *sync.Mutex for per-chat locking
}

// NewRelayService creates a new Relay instance
func NewRelayService(app core.App, openCodeURL string) *RelayService {
	return &RelayService{
		app:         app,
		openCodeURL: openCodeURL,
	}
}

// Start begins the relay's background processes:
// 1. Permission Listener (SSE)
// 2. Message Pump (Hooks)
// 3. Agent Sync (Hooks)
// 4. Health Monitor Watchdog
func (r *RelayService) Start() {
	r.app.Logger().Info("[Relay] Starting Go-based Relay Service...")

	// 1. Start SSE Listener (in background)
	go r.listenForEvents()

	// 2. Register Hooks
	r.registerMessageHooks()
	r.registerAgentHooks()
	r.registerSSHKeyHooks()
	r.registerPermissionHooks()
	r.registerSopHooks()
	r.registerMcpHooks()

	// 3. Catch up on missed messages
	go r.recoverMissedMessages()

	// 4. Start Health Monitor Watchdog
	go r.startHealthMonitor()
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
		// Watchdog: If we haven't seen ANYTHING from OpenCode in 45 seconds, it's offline.
		if r.lastHeartbeat > 0 && now-r.lastHeartbeat > 45 {
			if r.isReady {
				r.app.Logger().Warn("⚠️ [Relay/Health] OpenCode responsiveness lost (Watchdog triggered).")
				r.isReady = false
				r.updateHealthcheck("offline")
			}
		} else if r.lastHeartbeat > 0 {
			// If we see activity again, recover to ready
			if !r.isReady {
				r.app.Logger().Info("💓 [Relay/Health] OpenCode responsiveness recovered.")
				r.isReady = true
				r.updateHealthcheck("ready")
			}
		}
	}
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
