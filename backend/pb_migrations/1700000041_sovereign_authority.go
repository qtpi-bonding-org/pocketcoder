package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. DELETE OLD WHITELISTS
		oldWhitelists, _ := app.FindCollectionByNameOrId("whitelists")
		if oldWhitelists != nil {
			if err := app.Delete(oldWhitelists); err != nil {
				return err
			}
		}

		// 2. SETUP whitelist_actions (Verbs)
		actions := core.NewCollection(core.CollectionTypeBase, "whitelist_actions")
		actions.Name = "whitelist_actions"

		actions.Fields.Add(&core.TextField{
			Name:     "permission",
			Required: true,
		})
		actions.Fields.Add(&core.SelectField{
			Name:      "kind",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"strict", "pattern"},
		})
		actions.Fields.Add(&core.TextField{
			Name: "value",
		})

		// Link to commands for strict bash matching
		commands, _ := app.FindCollectionByNameOrId("commands")
		if commands != nil {
			actions.Fields.Add(&core.RelationField{
				Name:         "command",
				CollectionId: commands.Id,
				MaxSelect:    1,
			})
		}

		actions.Fields.Add(&core.BoolField{Name: "active"})

		// PERMISSIONS
		actions.ListRule = ptr("@request.auth.id != ''")
		actions.ViewRule = ptr("@request.auth.id != ''")
		actions.CreateRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")
		actions.UpdateRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")
		actions.DeleteRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")

		if err := app.Save(actions); err != nil {
			return err
		}

		// 3. SETUP whitelist_targets (Nouns)
		targets := core.NewCollection(core.CollectionTypeBase, "whitelist_targets")
		targets.Name = "whitelist_targets"

		targets.Fields.Add(&core.TextField{
			Name:     "pattern",
			Required: true,
		})
		targets.Fields.Add(&core.BoolField{Name: "active"})

		// PERMISSIONS
		targets.ListRule = ptr("@request.auth.id != ''")
		targets.ViewRule = ptr("@request.auth.id != ''")
		targets.CreateRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")
		targets.UpdateRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")
		targets.DeleteRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")

		if err := app.Save(targets); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		// Cleanup
		if c, _ := app.FindCollectionByNameOrId("whitelist_actions"); c != nil {
			app.Delete(c)
		}
		if c, _ := app.FindCollectionByNameOrId("whitelist_targets"); c != nil {
			app.Delete(c)
		}
		return nil
	})
}
