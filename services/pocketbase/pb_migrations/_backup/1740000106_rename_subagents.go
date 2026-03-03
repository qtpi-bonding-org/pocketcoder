package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// Rename "subagents" collection to "sandbox_agents"
		collection, err := app.FindCollectionByNameOrId("subagents")
		if err != nil {
			// Collection doesn't exist yet (fresh install will use updated consolidated schema)
			return nil
		}

		collection.Name = "sandbox_agents"

		// Rename subagent_id field to sandbox_agent_id
		if f := collection.Fields.GetByName("subagent_id"); f != nil {
			if tf, ok := f.(*core.TextField); ok {
				tf.Name = "sandbox_agent_id"
			}
		}

		// Update the unique index to use new names
		collection.Indexes = []string{
			"CREATE UNIQUE INDEX idx_sandbox_agent_id_unique ON sandbox_agents (sandbox_agent_id)",
		}

		if err := app.Save(collection); err != nil {
			return err
		}

		// Also update the "subagent" mode value in agents collection to "sandbox_agent"
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
