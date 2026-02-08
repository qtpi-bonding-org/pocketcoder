package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		messages, err := app.FindCollectionByNameOrId("messages")
		if err != nil {
			return err
		}

		// Update permissions to prioritize role checks
		messages.ListRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user.id = @request.auth.id)")
		messages.ViewRule = ptr("@request.auth.id != '' && (@request.auth.role = 'agent' || @request.auth.role = 'admin' || chat.user.id = @request.auth.id)")

		return app.Save(messages)
	}, func(app core.App) error {
		// Rollback: restore old permissions
		messages, err := app.FindCollectionByNameOrId("messages")
		if err != nil {
			return err
		}

		messages.ListRule = ptr("@request.auth.id != '' && (chat.user.id = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin')")
		messages.ViewRule = ptr("@request.auth.id != '' && (chat.user.id = @request.auth.id || @request.auth.role = 'agent' || @request.auth.role = 'admin')")

		return app.Save(messages)
	})
}
