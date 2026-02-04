package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. SETUP WHITELISTS COLLECTION
		// "The Policy" - If a record exists here for a Command, it is Auto-Approved.
		whitelists := core.NewCollection(core.CollectionTypeBase, "whitelists")
		whitelists.Name = "whitelists"

		// Get the Commands collection ID for Relation
		commands, err := app.FindCollectionByNameOrId("commands")
		if err != nil {
			return err
		}

		whitelists.Fields.Add(&core.RelationField{
			Name:     "command",
			Required: true,
			CollectionId: commands.Id,
			MaxSelect: 1,
		})
		whitelists.Fields.Add(&core.BoolField{Name: "active"})

		// -------------------------------------------------------------------------
		// WHITELIST PERMISSIONS
		// -------------------------------------------------------------------------
		// Only Admins/Users can manage whitelists. Agents can only view them.
		whitelists.ListRule = ptr("@request.auth.id != ''")
		whitelists.ViewRule = ptr("@request.auth.id != ''")
		whitelists.CreateRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")
		whitelists.UpdateRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")
		whitelists.DeleteRule = ptr("@request.auth.role = 'admin' || @request.auth.role = 'user'")

		if err := app.Save(whitelists); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		w, _ := app.FindCollectionByNameOrId("whitelists")
		if w != nil { app.Delete(w) }
		return nil
	})
}
