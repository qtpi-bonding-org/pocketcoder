package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// Fix: rename "subagent" mode value to "sandbox_agent" in ai_agents collection
		// (migration 106 used wrong collection name "agents" instead of "ai_agents")
		agents, err := app.FindCollectionByNameOrId("ai_agents")
		if err != nil {
			return nil
		}

		if f := agents.Fields.GetByName("mode"); f != nil {
			if sf, ok := f.(*core.SelectField); ok {
				for i, v := range sf.Values {
					if v == "subagent" {
						sf.Values[i] = "sandbox_agent"
					}
				}
			}
		}

		return app.Save(agents)
	}, func(app core.App) error {
		return nil
	})
}
