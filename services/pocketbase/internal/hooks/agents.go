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

// @pocketcoder-core: Agent Hooks. Triggers re-bundling when agent records change.
package hooks

import (
	"log"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agents"
)

// RegisterAgentHooks registers hooks that trigger agent re-bundling.
func RegisterAgentHooks(app core.App) {
	// Trigger assembly on Agents change (Modify record BEFORE save to avoid extra writes/recursion)
	app.OnRecordCreateRequest("ai_agents").BindFunc(func(e *core.RecordRequestEvent) error {
		bundle, err := agents.GetAgentBundle(app, e.Record)
		if err == nil {
			e.Record.Set("config", bundle)
		}
		return e.Next()
	})

	app.OnRecordUpdateRequest("ai_agents").BindFunc(func(e *core.RecordRequestEvent) error {
		bundle, err := agents.GetAgentBundle(app, e.Record)
		if err == nil {
			e.Record.Set("config", bundle)
		}
		return e.Next()
	})

	// For prompts and models, we find the affected agents and re-assemble them (REQUIRES Save)
	app.OnRecordAfterUpdateSuccess("ai_prompts", "ai_models").BindFunc(func(e *core.RecordEvent) error {
		collection := e.Record.Collection().Name

		if collection == "ai_prompts" {
			agentsList, err := app.FindRecordsByFilter("ai_agents", "prompt = {:id}", "created", 100, 0, map[string]any{"id": e.Record.Id})
			if err != nil {
				log.Printf("⚠️ [Agents] Failed to query agents by prompt %s: %v", e.Record.Id, err)
			}
			for _, a := range agentsList {
				agents.UpdateAgentConfig(app, a)
			}
		}

		if collection == "ai_models" {
			agentsList, err := app.FindRecordsByFilter("ai_agents", "model = {:id}", "created", 100, 0, map[string]any{"id": e.Record.Id})
			if err != nil {
				log.Printf("⚠️ [Agents] Failed to query agents by model %s: %v", e.Record.Id, err)
			}
			for _, a := range agentsList {
				agents.UpdateAgentConfig(app, a)
			}
		}

		return e.Next()
	})
}
