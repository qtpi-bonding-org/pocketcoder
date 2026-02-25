package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. Rename opencode_id to agent_id on chats collection
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		if field := chats.Fields.GetByName("opencode_id"); field != nil {
			field.SetName("agent_id")
			if err := app.Save(chats); err != nil {
				return err
			}
		}

		// 2. Rename opencode_id to agent_message_id on messages collection
		messages, err := app.FindCollectionByNameOrId("messages")
		if err != nil {
			return err
		}
		if field := messages.Fields.GetByName("opencode_id"); field != nil {
			field.SetName("agent_message_id")
			if err := app.Save(messages); err != nil {
				return err
			}
		}

		// 3. Rename opencode_id to agent_permission_id on permissions collection
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err != nil {
			return err
		}
		if field := permissions.Fields.GetByName("opencode_id"); field != nil {
			field.SetName("agent_permission_id")
			if err := app.Save(permissions); err != nil {
				return err
			}
		}

		// 4. Drop and recreate subagents collection with new schema
		existingSubagents, err := app.FindCollectionByNameOrId("subagents")
		if err == nil {
			if err := app.Delete(existingSubagents); err != nil {
				return err
			}
		}

		// Create new subagents collection
		subagents := core.NewCollection(core.CollectionTypeBase, "subagents")
		subagents.Id = "pc_subagents"

		// Add fields
		subagents.Fields.Add(&core.TextField{Name: "subagent_id", Required: true})
		subagents.Fields.Add(&core.TextField{Name: "delegating_agent_id", Required: true})
		subagents.Fields.Add(&core.NumberField{Name: "tmux_window_id", Required: false})

		// Add unique index on subagent_id
		subagents.Indexes = []string{"CREATE UNIQUE INDEX idx_subagent_id_unique ON subagents (subagent_id)"}

		// Set auth rules (same as current)
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
		// Down migration: rename back from new names to old names

		// 1. Rename agent_id back to opencode_id on chats collection
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		if field := chats.Fields.GetByName("agent_id"); field != nil {
			field.SetName("opencode_id")
			if err := app.Save(chats); err != nil {
				return err
			}
		}

		// 2. Rename agent_message_id back to opencode_id on messages collection
		messages, err := app.FindCollectionByNameOrId("messages")
		if err != nil {
			return err
		}
		if field := messages.Fields.GetByName("agent_message_id"); field != nil {
			field.SetName("opencode_id")
			if err := app.Save(messages); err != nil {
				return err
			}
		}

		// 3. Rename agent_permission_id back to opencode_id on permissions collection
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err != nil {
			return err
		}
		if field := permissions.Fields.GetByName("agent_permission_id"); field != nil {
			field.SetName("opencode_id")
			if err := app.Save(permissions); err != nil {
				return err
			}
		}

		// 4. Drop new subagents collection and recreate old schema
		newSubagents, err := app.FindCollectionByNameOrId("subagents")
		if err == nil {
			if err := app.Delete(newSubagents); err != nil {
				return err
			}
		}

		// Get chats collection for relation
		chats, err = app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		// Recreate old subagents collection
		oldSubagents := core.NewCollection(core.CollectionTypeBase, "subagents")
		oldSubagents.Id = "pc_subagents"
		oldSubagents.Fields.Add(&core.TextField{Name: "subagent_id", Required: true})
		oldSubagents.Fields.Add(&core.RelationField{Name: "chat", Required: true, CollectionId: chats.Id, MaxSelect: 1})
		oldSubagents.Fields.Add(&core.NumberField{Name: "tmux_window_id", Required: true})
		oldSubagents.ListRule = ptr("@request.auth.id != ''")
		oldSubagents.ViewRule = ptr("@request.auth.id != ''")
		oldSubagents.CreateRule = ptr("@request.auth.id != ''")
		oldSubagents.UpdateRule = ptr("@request.auth.id != ''")
		oldSubagents.DeleteRule = ptr("@request.auth.id != ''")

		if err := app.Save(oldSubagents); err != nil {
			return err
		}

		return nil
	})
}

