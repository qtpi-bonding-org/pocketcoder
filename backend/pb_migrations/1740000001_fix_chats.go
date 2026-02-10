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

		chats.Fields.Add(&core.DateField{Name: "last_active"})
		chats.Fields.Add(&core.TextField{Name: "preview"})

		return app.Save(chats)
	}, func(app core.App) error {
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}

		chats.Fields.RemoveByName("last_active")
		chats.Fields.RemoveByName("preview")

		return app.Save(chats)
	})
}
