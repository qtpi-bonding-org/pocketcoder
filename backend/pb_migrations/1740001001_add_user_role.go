package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		// Add role field if it doesn't exist
		if f := users.Fields.GetByName("role"); f == nil {
			users.Fields.Add(&core.SelectField{
				Name:      "role",
				MaxSelect: 1,
				Values:    []string{"admin", "agent", "user"},
			})
		}

		return app.Save(users)
	}, func(app core.App) error {
		// Rollback logic here if needed
		return nil
	})
}
