package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// This migration is now schema-only. 
		// Data seeding has been moved to the runtime initialization logic in main.go
		// to ensure environment-specific credentials are never hardcoded in migrations.
		
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		// Ensure system users collection has the correct secondary indexes or config if needed
		// For now, genesis.go handles the fields.
		
		return app.Save(users)
	}, func(app core.App) error {
		return nil
	})
}
