package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		configs := core.NewCollection(core.CollectionTypeBase, "configs")
		configs.Name = "configs"

		configs.Fields.Add(&core.TextField{
			Name:     "key",
			Required: true,
		})
		configs.Fields.Add(&core.TextField{
			Name: "value",
		})

		configs.AddIndex("idx_configs_key", true, "key", "")

		configs.ListRule = ptr("@request.auth.id != ''")
		configs.ViewRule = ptr("@request.auth.id != ''")
		configs.CreateRule = ptr("@request.auth.role = 'admin'")
		configs.UpdateRule = ptr("@request.auth.role = 'admin'")
		configs.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(configs); err != nil {
			return err
		}

		// Seed auto_approve setting
		c := core.NewRecord(configs)
		c.Set("key", "auto_approve_all")
		c.Set("value", "false")
		return app.Save(c)
	}, func(app core.App) error {
		c, _ := app.FindCollectionByNameOrId("configs")
		if c != nil {
			return app.Delete(c)
		}
		return nil
	})
}
