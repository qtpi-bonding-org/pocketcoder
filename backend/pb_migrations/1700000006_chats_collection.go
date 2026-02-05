package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. SETUP CHATS COLLECTION
		chats, _ := app.FindCollectionByNameOrId("chats")
		if chats != nil {
			return nil // Already exists
		}
		
		chats = core.NewCollection(core.CollectionTypeBase, "chats")
		chats.Name = "chats"


		// Fetch users collection to get ID
		usersCollection, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		chats.Fields.Add(&core.TextField{Name: "title", Required: true})
		chats.Fields.Add(&core.RelationField{
			Name:         "user",
			Required:     true,
			CollectionId: usersCollection.Id,
			MaxSelect:    1,
		})

		// Permissions: User deals with their own chats. Agent/Admin sees all.
		chats.ListRule = ptr("@request.auth.id = user.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		chats.ViewRule = ptr("@request.auth.id = user.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'")
		chats.CreateRule = ptr("@request.auth.id != ''")
		chats.UpdateRule = ptr("@request.auth.id = user.id || @request.auth.role = 'admin'")
		chats.DeleteRule = ptr("@request.auth.id = user.id || @request.auth.role = 'admin'")

		if err := app.Save(chats); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		if c, _ := app.FindCollectionByNameOrId("chats"); c != nil {
			app.Delete(c)
		}
		return nil
	})
}
