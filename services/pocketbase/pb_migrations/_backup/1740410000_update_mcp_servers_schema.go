package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil {
			return err
		}

		// Add new fields for autonomous provisioning
		collection.Fields.Add(&core.TextField{
			Name: "image",
		})
		collection.Fields.Add(&core.JSONField{
			Name: "config_schema",
		})

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil {
			return err
		}

		collection.Fields.RemoveByName("image")
		collection.Fields.RemoveByName("config_schema")

		return app.Save(collection)
	})
}
