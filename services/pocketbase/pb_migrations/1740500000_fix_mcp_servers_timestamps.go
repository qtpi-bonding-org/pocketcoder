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

		// Add created and updated fields if they are missing
		// In newer PocketBase, these are usually 'autodate' type but can be added as such.
		if f := collection.Fields.GetByName("created"); f == nil {
			collection.Fields.Add(&core.AutodateField{
				Name:     "created",
				OnCreate: true,
			})
		}
		if f := collection.Fields.GetByName("updated"); f == nil {
			collection.Fields.Add(&core.AutodateField{
				Name:     "updated",
				OnCreate: true,
				OnUpdate: true,
			})
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil {
			return err
		}

		collection.Fields.RemoveByName("created")
		collection.Fields.RemoveByName("updated")

		return app.Save(collection)
	})
}
