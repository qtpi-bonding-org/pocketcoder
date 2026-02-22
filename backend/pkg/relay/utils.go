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

// @pocketcoder-core: Relay Utilities. Common logic for the Spinal Cord.
package relay

import (
	"time"
)

// resolveChatID attempts to find a chat associated with an ai_engine_session_id (OpenCode session ID)
// or a subagent_id. Retries with exponential backoff to handle race conditions.
func (r *RelayService) resolveChatID(sessionID string) string {
	if sessionID == "" {
		return ""
	}

	// Retry up to 10 times with exponential backoff to handle database write delays
	for attempt := 0; attempt < 10; attempt++ {
		// 1. Check if it's the main agent (Poco)
		record, err := r.app.FindFirstRecordByFilter("chats", "ai_engine_session_id = {:id}", map[string]any{"id": sessionID})
		if err == nil {
			if attempt > 0 {
				r.app.Logger().Info("✅ [Relay/Go] resolveChatID succeeded after retry", "sessionID", sessionID, "attempt", attempt+1)
			}
			return record.Id
		}

		// 2. Check if it's a subagent
		subagent, err := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": sessionID})
		if err == nil {
			// Use the direct chat relation if available
			chatID := subagent.GetString("chat")
			if chatID != "" {
				if attempt > 0 {
					r.app.Logger().Info("✅ [Relay/Go] resolveChatID (subagent) succeeded after retry", "sessionID", sessionID, "attempt", attempt+1)
				}
				return chatID
			}

			// Fallback: Resolve via delegating_agent_id -> chats.ai_engine_session_id -> chats.id
			delegatingAgentID := subagent.GetString("delegating_agent_id")
			if delegatingAgentID != "" {
				chatRecord, err := r.app.FindFirstRecordByFilter("chats", "ai_engine_session_id = {:id}", map[string]any{"id": delegatingAgentID})
				if err == nil {
					if attempt > 0 {
						r.app.Logger().Info("✅ [Relay/Go] resolveChatID (via delegating agent) succeeded after retry", "sessionID", sessionID, "attempt", attempt+1)
					}
					return chatRecord.Id
				}
			}
		}

		// If not found and we have retries left, wait and try again
		if attempt < 9 {
			delay := time.Duration(10*(1<<uint(attempt))) * time.Millisecond // 10ms, 20ms, 40ms, 80ms, 160ms, 320ms, 640ms, 1280ms, 2560ms, 5120ms
			r.app.Logger().Warn("⚠️ [Relay/Go] resolveChatID not found, retrying...", "sessionID", sessionID, "attempt", attempt+1, "delay_ms", delay.Milliseconds())
			time.Sleep(delay)
		}
	}

	r.app.Logger().Warn("⚠️ [Relay/Go] resolveChatID failed after all retries", "sessionID", sessionID)
	return ""
}
