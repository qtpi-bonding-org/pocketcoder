package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. Get Chats Collection
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		// 2. Create Subagents Collection
		subagents := core.NewCollection(core.CollectionTypeBase, "subagents")
		subagents.Id = "pc_subagents"
		
		// Use standard field addition pattern
		subagents.Fields.Add(&core.TextField{Name: "subagent_id", Required: true})
		subagents.Fields.Add(&core.RelationField{Name: "chat", Required: true, CollectionId: chats.Id, MaxSelect: 1})
		subagents.Fields.Add(&core.NumberField{Name: "tmux_window_id", Required: true})
		
		// Rules (Internal use mostly, but allow auth users to view)
		subagents.ListRule = ptr("@request.auth.id != ''")
		subagents.ViewRule = ptr("@request.auth.id != ''")
		subagents.CreateRule = ptr("@request.auth.id != ''")
		subagents.UpdateRule = ptr("@request.auth.id != ''")
		subagents.DeleteRule = ptr("@request.auth.id != ''")

		if err := app.Save(subagents); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("subagents")
		if err == nil {
			return app.Delete(collection)
		}
		return nil
	})
}
