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
