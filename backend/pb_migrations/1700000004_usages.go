package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// -------------------------------------------------------------------------
		// USAGES COLLECTION (Sovereign Usage Ledger)
		// -------------------------------------------------------------------------
		// Tracks tokens, costs, and statuses per-step.
		
		usages := core.NewCollection(core.CollectionTypeBase, "usages")
		usages.Name = "usages"

		usages.Fields.Add(&core.TextField{
			Name: "message_id",
		}) // Correlation with OpenCode message

		usages.Fields.Add(&core.TextField{
			Name: "part_id",
		}) // Correlation with OpenCode part (step-finish)

		usages.Fields.Add(&core.TextField{
			Name: "model",
		})

		// Tokens
		usages.Fields.Add(&core.NumberField{
			Name: "tokens_prompt",
		})
		usages.Fields.Add(&core.NumberField{
			Name: "tokens_completion",
		})
		usages.Fields.Add(&core.NumberField{
			Name: "tokens_reasoning",
		})
		usages.Fields.Add(&core.NumberField{
			Name: "tokens_cache_read",
		})
		usages.Fields.Add(&core.NumberField{
			Name: "tokens_cache_write",
		})

		usages.Fields.Add(&core.NumberField{
			Name: "cost",
		})

		usages.Fields.Add(&core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"in-progress", "completed", "error"},
		})

		// Indexes
		usages.AddIndex("idx_usages_message_id", false, "message_id", "")
		usages.AddIndex("idx_usages_part_id", false, "part_id", "")

		// PERMISSIONS
		usages.ListRule = ptr("@request.auth.id != ''")
		usages.ViewRule = ptr("@request.auth.id != ''")
		usages.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		usages.UpdateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		usages.DeleteRule = ptr("@request.auth.role = 'admin'")

		return app.Save(usages)
	}, func(app core.App) error {
		c, _ := app.FindCollectionByNameOrId("usages")
		if c != nil {
			return app.Delete(c)
		}
		return nil
	})
}
