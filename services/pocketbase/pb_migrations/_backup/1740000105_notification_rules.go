package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
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
		if err != nil {
			return err
		}

		// =========================================================================
		// NOTIFICATION RULES COLLECTION
		// Per-user opt-out for notification types. One record per user.
		// Missing keys default to enabled (opt-out model, not opt-in).
		//
		// Example rules JSON:
		//   {
		//     "permission": true,
		//     "task_complete": true,
		//     "task_error": true,
		//     "question": false,
		//     "mcp_request": false
		//   }
		// =========================================================================
		rules, _ := getOrCreateCollection("pc_notification_rules", "notification_rules", core.CollectionTypeBase)
		addFields(rules,
			&core.RelationField{Name: "user", Required: true, CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.JSONField{Name: "rules"},
		)

		// Only the owner can manage their notification rules
		rules.ListRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		rules.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		rules.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		rules.UpdateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		rules.DeleteRule = ptr("@request.auth.id != '' && user = @request.auth.id")

		// Unique index: one record per user
		rules.AddIndex("idx_notification_rules_user", true, "user", "")

		if err := app.Save(rules); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		return nil
	})
}
