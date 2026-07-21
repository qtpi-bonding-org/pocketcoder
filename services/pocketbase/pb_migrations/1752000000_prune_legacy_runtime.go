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

package pb_migrations

import (
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// Removes Goose-superseded turn-state: the messages/permissions/acp_terminals
// collections and the legacy chats session-id/engine fields. Goose owns
// conversation, tool, approval, and terminal state; goose_sessions is the only
// c1 runtime mapping. Forward-only; deleting pre-launch records is acceptable.
func init() {
	migrations.Register(func(app core.App) error {
		for _, name := range []string{"messages", "permissions", "acp_terminals"} {
			col, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				continue // already absent
			}
			if err := app.Delete(col); err != nil {
				return err
			}
		}
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		chats.Indexes = dropIndexes(chats.Indexes, "idx_chats_ai_engine_session_id", "idx_chats_acp_session_id")
		for _, f := range []string{"acp_session_id", "engine_type", "ai_engine_session_id"} {
			if field := chats.Fields.GetByName(f); field != nil {
				chats.Fields.RemoveById(field.GetId())
			}
		}
		return app.Save(chats)
	}, func(app core.App) error {
		// Down: no-op. Pre-launch prune is not reversible by design; recreating
		// empty legacy collections would serve no purpose.
		return nil
	})
}

// dropIndexes returns the index definitions that do not mention any of names.
func dropIndexes(indexes []string, names ...string) []string {
	kept := make([]string, 0, len(indexes))
	for _, idx := range indexes {
		drop := false
		for _, n := range names {
			if strings.Contains(strings.ToLower(idx), strings.ToLower(n)) {
				drop = true
				break
			}
		}
		if !drop {
			kept = append(kept, idx)
		}
	}
	return kept
}