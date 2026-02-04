package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. Get Collections
		permissions, err := app.FindCollectionByNameOrId("permissions")
		if err != nil {
			return err
		}

		executions, err := app.FindCollectionByNameOrId("executions")
		if err != nil {
			return err
		}

		usages, err := app.FindCollectionByNameOrId("usages")
		if err != nil {
			return err
		}

		// 2. Add Relation to Permissions
		permissions.Fields.Add(&core.RelationField{
			Name:         "usage",
			Required:     false, // Optional for flexibility, logic will ensure it
			CollectionId: usages.Id,
			MaxSelect:    1,
		})

		// 3. Add Relation to Executions
		executions.Fields.Add(&core.RelationField{
			Name:         "usage",
			Required:     false,
			CollectionId: usages.Id,
			MaxSelect:    1,
		})

		if err := app.Save(permissions); err != nil {
			return err
		}

		return app.Save(executions)
	}, func(app core.App) error {
		// Rollback
		p, _ := app.FindCollectionByNameOrId("permissions")
		if p != nil {
			p.Fields.RemoveByName("usage")
			app.Save(p)
		}

		e, _ := app.FindCollectionByNameOrId("executions")
		if e != nil {
			e.Fields.RemoveByName("usage")
			app.Save(e)
		}

		return nil
	})
}
