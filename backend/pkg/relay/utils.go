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

// resolveChatID attempts to find a chat associated with an agent_id (OpenCode session ID)
// or a subagent_id.
func (r *RelayService) resolveChatID(sessionID string) string {
	if sessionID == "" {
		return ""
	}

	// 1. Check if it's the main agent (Poco)
	record, err := r.app.FindFirstRecordByFilter("chats", "agent_id = {:id}", map[string]any{"id": sessionID})
	if err == nil {
		return record.Id
	}

	// 2. Check if it's a subagent
	subagent, err := r.app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": sessionID})
	if err == nil {
		// Resolve via delegating_agent_id -> chats.agent_id -> chats.id
		delegatingAgentID := subagent.GetString("delegating_agent_id")
		if delegatingAgentID == "" {
			return ""
		}
		chatRecord, err := r.app.FindFirstRecordByFilter("chats", "agent_id = {:id}", map[string]any{"id": delegatingAgentID})
		if err == nil {
			return chatRecord.Id
		}
	}

	return ""
}
