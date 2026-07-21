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
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// Replaces the old unique index on (agent, tool, pattern) — which pointed at the
// deprecated ai_agents collection — with (poco_config, tool, pattern) to match the
// ACP schema rename. NULL poco_config rows are global permissions; SQLite treats
// each NULL as distinct so multiple global entries for the same tool/pattern are
// still allowed.
func init() {
	migrations.Register(func(app core.App) error {
		tp, err := app.FindCollectionByNameOrId("tool_permissions")
		if err != nil {
			return err
		}

		newIndexes := make([]string, 0, len(tp.Indexes))
		for _, idx := range tp.Indexes {
			if idx == "CREATE UNIQUE INDEX idx_tool_perms_agent_tool_pattern ON tool_permissions (agent, tool, pattern)" {
				continue
			}
			newIndexes = append(newIndexes, idx)
		}
		newIndexes = append(newIndexes,
			"CREATE UNIQUE INDEX idx_tool_perms_poco_config_tool_pattern ON tool_permissions (poco_config, tool, pattern)",
		)
		tp.Indexes = newIndexes
		return app.Save(tp)
	}, func(app core.App) error {
		tp, err := app.FindCollectionByNameOrId("tool_permissions")
		if err != nil {
			return err
		}

		newIndexes := make([]string, 0, len(tp.Indexes))
		for _, idx := range tp.Indexes {
			if idx == "CREATE UNIQUE INDEX idx_tool_perms_poco_config_tool_pattern ON tool_permissions (poco_config, tool, pattern)" {
				continue
			}
			newIndexes = append(newIndexes, idx)
		}
		newIndexes = append(newIndexes,
			"CREATE UNIQUE INDEX idx_tool_perms_agent_tool_pattern ON tool_permissions (agent, tool, pattern)",
		)
		tp.Indexes = newIndexes
		return app.Save(tp)
	})
}
