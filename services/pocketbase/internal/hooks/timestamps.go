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

// @pocketcoder-core: Timestamp Hooks. Manages created/updated/last_active fields globally.
package hooks

import (
	"time"

	"github.com/pocketbase/pocketbase/core"
)

// RegisterGlobalTimestamps registers hooks for created, updated, and last_active timestamps.
func RegisterGlobalTimestamps(app core.App) {
	handler := func(e *core.RecordEvent) error {
		now := time.Now().Format("2006-01-02 15:04:05.000Z")
		collection := e.Record.Collection()

		if f := collection.Fields.GetByName("created"); f != nil {
			if e.Record.GetString("created") == "" {
				e.Record.Set("created", now)
			}
		}
		if f := collection.Fields.GetByName("updated"); f != nil {
			e.Record.Set("updated", now)
		}
		if collection.Name == "chats" {
			if f := collection.Fields.GetByName("last_active"); f != nil {
				e.Record.Set("last_active", now)
			}
		}
		return e.Next()
	}

	collections := []string{"chats", "messages", "permissions", "usages", "ssh_keys", "ai_agents"}
	for _, col := range collections {
		app.OnRecordCreate(col).BindFunc(handler)
		app.OnRecordUpdate(col).BindFunc(handler)
	}
}
