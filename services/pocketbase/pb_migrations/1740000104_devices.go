package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// --- HELPERS ---
		getOrCreateCollection := func(id, name, typeStr string) (*core.Collection, error) {
			collection, _ := app.FindCollectionByNameOrId(name)
			if collection != nil {
				return collection, nil
			}
			c := core.NewCollection(typeStr, name)
			c.Id = id
			return c, nil
		}
		
		addFields := func(c *core.Collection, fields ...core.Field) {
			for _, f := range fields {
				if existing := c.Fields.GetByName(f.GetName()); existing == nil {
					c.Fields.Add(f)
				}
			}
		}

		users, err := app.FindCollectionByNameOrId("users")
		if err != nil { return err }

		// =========================================================================
		// DEVICES COLLECTION
		// =========================================================================
		devices, _ := getOrCreateCollection("pc_devices", "devices", core.CollectionTypeBase)
		addFields(devices,
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "name", Required: true},
			&core.TextField{Name: "push_token", Required: true},
			&core.SelectField{Name: "push_service", Required: true, MaxSelect: 1, Values: []string{"fcm", "unifiedpush"}},
			&core.BoolField{Name: "is_active"},
		)
		
		// Rules: Only the owner can see and manage their devices
		devices.ListRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.UpdateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		devices.DeleteRule = ptr("@request.auth.id != '' && user = @request.auth.id")

		if err := app.Save(devices); err != nil { return err }

		return nil
	}, func(app core.App) error {
		return nil
	})
}
