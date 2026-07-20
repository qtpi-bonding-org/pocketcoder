package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		poco, err := app.FindCollectionByNameOrId("poco_configs")
		if err != nil {
			return err
		}
		if poco.Fields.GetByName("mode") == nil {
			// Values are provisional (spec §13.3): only "approve" is verified
			// against the pinned Goose build. Confirm advertised modes first.
			poco.Fields.Add(&core.SelectField{
				Name:      "mode",
				MaxSelect: 1,
				Values:    []string{"auto", "approve", "smart_approve", "chat"},
			})
		}
		if f := poco.Fields.GetByName("config"); f != nil { // dead OpenCode bundle
			poco.Fields.RemoveById(f.GetId())
		}
		return app.Save(poco)
	}, func(app core.App) error {
		poco, err := app.FindCollectionByNameOrId("poco_configs")
		if err != nil {
			return err
		}
		if f := poco.Fields.GetByName("mode"); f != nil {
			poco.Fields.RemoveById(f.GetId())
		}
		if poco.Fields.GetByName("config") == nil {
			poco.Fields.Add(&core.TextField{Name: "config"})
		}
		return app.Save(poco)
	})
}
