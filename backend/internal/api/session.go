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

// @pocketcoder-core: Session Resolution API. Maps session IDs to tmux routing info.
package api

import (
	"net/http"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterSessionApi provides session resolution for the Proxy's Smart Router.
func RegisterSessionApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	// Resolve session_id to chat_id and tmux routing info
	e.Router.GET("/api/pocketcoder/resolve_session/{session_id}", func(re *core.RequestEvent) error {
		sessionID := re.Request.PathValue("session_id")
		if sessionID == "" {
			return re.JSON(http.StatusBadRequest, map[string]interface{}{
				"error": "session_id is required",
			})
		}

		// 1. Check if it's the main agent (Poco)
		record, err := app.FindFirstRecordByFilter("chats", "agent_id = {:id}", map[string]any{"id": sessionID})
		if err == nil {
			// Main agent found - use Window 0
			return re.JSON(http.StatusOK, map[string]interface{}{
				"chat_id":         record.Id,
				"session_name":    "pc-" + record.Id,
				"window_id":       0,
				"type":            "main_agent",
				"agent_id":        record.GetString("agent_id"),
			})
		}

		// 2. Check if it's a subagent
		subagent, err := app.FindFirstRecordByFilter("subagents", "subagent_id = {:id}", map[string]any{"id": sessionID})
		if err == nil {
			chatID := subagent.GetString("chat")
			windowID := subagent.GetInt("tmux_window_id")
			
			return re.JSON(http.StatusOK, map[string]interface{}{
				"chat_id":         chatID,
				"session_name":    "pc-" + chatID,
				"window_id":       windowID,
				"type":            "subagent",
				"subagent_id":     subagent.GetString("subagent_id"),
			})
		}

		// 3. Not found - return 404
		return re.JSON(http.StatusNotFound, map[string]interface{}{
			"error": "session not found",
			"session_id": sessionID,
		})
	})
}
