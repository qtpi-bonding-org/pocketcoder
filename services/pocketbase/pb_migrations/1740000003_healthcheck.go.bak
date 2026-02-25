package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		collection, _ := app.FindCollectionByNameOrId("healthchecks")
		if collection != nil {
			return nil
		}

		collection = core.NewCollection(core.CollectionTypeBase, "healthchecks")
		collection.Fields.Add(&core.TextField{Name: "name", Required: true})
		collection.Fields.Add(&core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"ready", "starting", "offline", "error"},
		})
		collection.Fields.Add(&core.DateField{Name: "last_ping"})

		// Rules: Everyone can see health status
		collection.ListRule = ptr("@request.auth.id != ''")
		collection.ViewRule = ptr("@request.auth.id != ''")
		collection.UpdateRule = ptr("") // Only backend can update (no API update)
		collection.CreateRule = ptr("")
		collection.DeleteRule = ptr("")

		return app.Save(collection)
	}, func(app core.App) error {
		collection, _ := app.FindCollectionByNameOrId("healthchecks")
		if collection == nil {
			return nil
		}
		return app.Delete(collection)
	})
}
