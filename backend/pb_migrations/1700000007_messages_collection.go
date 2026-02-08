package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. Find the CHATS collection
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		// 2. SETUP MESSAGES COLLECTION
		messages, _ := app.FindCollectionByNameOrId("messages")
		if messages != nil {
			return nil // Already exists
		}
		
		messages = core.NewCollection(core.CollectionTypeBase, "messages")
		messages.Name = "messages"

		messages.Fields.Add(&core.RelationField{
			Name:         "chat",
			Required:     true,
			CollectionId: chats.Id,
			MaxSelect:    1,
		})
		
		messages.Fields.Add(&core.SelectField{
			Name:      "role",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"user", "assistant", "system"},
		})

		// The Big JSON Blob for OpenCode fidelity
		messages.Fields.Add(&core.JSONField{Name: "parts", Required: true})
		messages.Fields.Add(&core.JSONField{Name: "metadata"})
		
		// Indexes for speed
		messages.AddIndex("idx_messages_chat", false, "chat", "")

		// Permissions
		messages.ListRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user.id = @request.auth.id)")
		messages.ViewRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user.id = @request.auth.id)")
		// Create: Users in own chat, Agents anywhere
		messages.CreateRule = ptr("@request.auth.id != ''")
		// Update: Agents (appending tokens/status) or Admin
		messages.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		messages.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(messages); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		if c, _ := app.FindCollectionByNameOrId("messages"); c != nil {
			app.Delete(c)
		}
		return nil
	})
}
