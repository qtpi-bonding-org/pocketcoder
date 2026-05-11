package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

// Removes chats.current_role — added in 1748000100 but never referenced by
// any hook or client code.
func init() {
	migrations.Register(func(app core.App) error {
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		if f := chats.Fields.GetByName("current_role"); f != nil {
			chats.Fields.RemoveById(f.GetId())
			return app.Save(chats)
		}
		return nil
	}, func(app core.App) error {
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		if chats.Fields.GetByName("current_role") == nil {
			chats.Fields.Add(&core.SelectField{
				Name:   "current_role",
				Values: []string{"user", "assistant"},
			})
			return app.Save(chats)
		}
		return nil
	})
}
