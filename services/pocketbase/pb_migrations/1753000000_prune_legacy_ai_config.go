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

// Drops the pre-Goose-migration AI/LLM config schema
// (ai_agents/ai_prompts/ai_models/llm_keys/llm_providers/model_selection).
// Nothing in Go has read these since the ACP/AG-UI rewrite — they were
// only still reachable through two Flutter screens
// (agent_management_screen.dart, llm_management_screen.dart) that wrote to
// them with zero effect on Goose. See
// spikes/goose-acp-config-surface/{README.md,ownership-map.md} for the
// full audit. ai_agents has four surviving relation fields pointing at it
// (chats.agent, sandbox_agents.delegating_agent, tool_permissions.agent,
// cron_jobs.agent) — all dropped first since a collection can't keep a
// relation field pointing at a collection that no longer exists. The
// other five dead collections have no surviving incoming relations.
func init() {
	migrations.Register(func(app core.App) error {
		agentRelations := map[string]string{
			"chats":            "agent",
			"sandbox_agents":   "delegating_agent",
			"tool_permissions": "agent",
			"cron_jobs":        "agent",
		}
		for colName, fieldName := range agentRelations {
			col, err := app.FindCollectionByNameOrId(colName)
			if err != nil {
				return err
			}
			col.Fields.RemoveByName(fieldName)
			if err := app.Save(col); err != nil {
				return err
			}
		}

		for _, name := range []string{
			"ai_agents", "ai_prompts", "ai_models",
			"llm_keys", "llm_providers", "model_selection",
		} {
			col, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				return err
			}
			if err := app.Delete(col); err != nil {
				return err
			}
		}
		return nil
	}, func(app core.App) error {
		// Forward-only prune, matching 1752000000_prune_legacy_runtime.go's
		// precedent — recreating six collections' full historical field
		// sets is not worth maintaining for a rollback path nothing has
		// needed so far.
		return nil
	})
}
