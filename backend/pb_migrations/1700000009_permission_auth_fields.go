package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. ADD CHALLENGE/SIGNATURE TO PERMISSIONS
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err != nil {
			return err
		}

		// This is what the client must sign
		permissions.Fields.Add(&core.TextField{Name: "challenge"})
		
		// This is the proof produced by the client
		permissions.Fields.Add(&core.TextField{Name: "signature"})

		return app.Save(permissions)
	}, func(app core.App) error {
		permissions, _ := app.FindCollectionByNameOrId("permissions")
		if permissions != nil {
			permissions.Fields.RemoveByName("challenge")
			permissions.Fields.RemoveByName("signature")
			return app.Save(permissions)
		}
		return nil
	})
}
