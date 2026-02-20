package hooks

import (
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-automaton/pocketcoder/backend/internal/agents"
)

// RegisterAgentHooks registers hooks that trigger agent re-bundling.
func RegisterAgentHooks(app *pocketbase.PocketBase) {
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
			agentsList, _ := app.FindRecordsByFilter("ai_agents", "prompt = {:id}", "created", 100, 0, map[string]any{"id": e.Record.Id})
			for _, a := range agentsList {
				agents.UpdateAgentConfig(app, a)
			}
		}

		if collection == "ai_models" {
			agentsList, _ := app.FindRecordsByFilter("ai_agents", "model = {:id}", "created", 100, 0, map[string]any{"id": e.Record.Id})
			for _, a := range agentsList {
				agents.UpdateAgentConfig(app, a)
			}
		}

		return e.Next()
	})
}
