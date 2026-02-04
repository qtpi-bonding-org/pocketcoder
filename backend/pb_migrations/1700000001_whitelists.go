package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// 1. SETUP WHITELISTS COLLECTION
		whitelists := core.NewCollection(core.CollectionTypeBase, "whitelists")
		whitelists.Name = "whitelists"

		whitelists.Fields.Add(&core.SelectField{
			Name:      "type",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"terminal", "filesystem", "browser", "other"},
		})
		whitelists.Fields.Add(&core.TextField{Name: "pattern", Required: true})
		whitelists.Fields.Add(&core.TextField{Name: "reason"})
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

		// 2. ADD DEFAULT WHITELISTS
		// We can seed some basic "safe" patterns
		defaultPatterns := []map[string]interface{}{
			{"type": "terminal", "pattern": "git status*", "reason": "Safe read-only git command", "active": true},
			{"type": "terminal", "pattern": "ls *", "reason": "List directory contents", "active": true},
			{"type": "terminal", "pattern": "pwd", "reason": "Print working directory", "active": true},
		}

		for _, p := range defaultPatterns {
			record := core.NewRecord(whitelists)
			record.Set("type", p["type"])
			record.Set("pattern", p["pattern"])
			record.Set("reason", p["reason"])
			record.Set("active", p["active"])
			if err := app.Save(record); err != nil {
				return err
			}
		}

		return nil
	}, func(app core.App) error {
		w, _ := app.FindCollectionByNameOrId("whitelists")
		if w != nil { app.Delete(w) }
		return nil
	})
}
