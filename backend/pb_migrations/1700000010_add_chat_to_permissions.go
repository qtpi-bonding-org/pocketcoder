package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err != nil {
			return err
		}


		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		// Add 'chat' relation
		permissions.Fields.Add(&core.RelationField{
			Name:         "chat",
			CollectionId: chats.Id,
			CascadeDelete: false,
			MaxSelect:    1,
		})

		return app.Save(permissions)
	}, func(app core.App) error {
		// Rollback
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err != nil {
			return err
		}
		permissions.Fields.RemoveByName("chat")
		return app.Save(permissions)
	})
}
