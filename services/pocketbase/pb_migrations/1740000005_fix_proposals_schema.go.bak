package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		proposals, err := app.FindCollectionByNameOrId("proposals")
		if err != nil {
			return err
		}

		// Ensure 'status' field exists
		if proposals.Fields.GetByName("status") == nil {
			proposals.Fields.Add(&core.SelectField{
				Name:     "status",
				Required: true,
				Values:   []string{"draft", "approved"},
			})
		}

		// Ensure 'authored_by' field exists
		if proposals.Fields.GetByName("authored_by") == nil {
			proposals.Fields.Add(&core.SelectField{
				Name:     "authored_by",
				Required: true,
				Values:   []string{"human", "poco"},
			})
		}

		return app.Save(proposals)
	}, func(app core.App) error {
		return nil
	})
}
