package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		// Add 'opencode_id' to store the reasoning session mapping
		chats.Fields.Add(&core.TextField{
			Name: "opencode_id",
		})

		return app.Save(chats)
	}, func(app core.App) error {
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		chats.Fields.RemoveByName("opencode_id")
		return app.Save(chats)
	})
}
