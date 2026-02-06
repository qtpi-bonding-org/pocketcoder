package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. SETUP DEVICES COLLECTION
		devices := core.NewCollection(core.CollectionTypeBase, "devices")
		devices.Name = "devices"

		// Fields
		devices.Fields.Add(&core.RelationField{
			Name:         "user",
			Required:     true,
			CollectionId: "_pb_users_auth_", // users collection
			MaxSelect:    1,
		})
		devices.Fields.Add(&core.TextField{Name: "name", Required: true})
		devices.Fields.Add(&core.TextField{Name: "fingerprint", Required: true})
		devices.Fields.Add(&core.JSONField{Name: "publicKey", Required: true})

		// Indices
		devices.AddIndex("idx_devices_fingerprint", true, "fingerprint", "")

		// PERMISSIONS:
		// User can List/View/Create/Update/Delete their own devices.
		devices.ListRule = ptr("@request.auth.id = user.id")
		devices.ViewRule = ptr("@request.auth.id = user.id")
		devices.CreateRule = ptr("@request.auth.id = @request.body.user")
		devices.UpdateRule = ptr("@request.auth.id = user.id")
		devices.DeleteRule = ptr("@request.auth.id = user.id")

		if err := app.Save(devices); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		if c, _ := app.FindCollectionByNameOrId("devices"); c != nil {
			return app.Delete(c)
		}
		return nil
	})
}
