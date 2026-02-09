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

		// Update rules to allow agent/admin to update chats
		// (needed for linking opencode_id)
		rule := "@request.auth.id = user.id || @request.auth.role = 'agent' || @request.auth.role = 'admin'"
		chats.UpdateRule = &rule

		return app.Save(chats)
	}, func(app core.App) error {
		chats, err := app.FindCollectionByNameOrId("chats")
		if err != nil {
			return err
		}
		// Rollback to original rule
		rule := "@request.auth.id = user.id || @request.auth.role = 'admin'"
		chats.UpdateRule = &rule
		return app.Save(chats)
	})
}
