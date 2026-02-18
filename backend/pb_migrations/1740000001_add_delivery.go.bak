package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("messages")
		if err != nil {
			return err
		}

		// Add delivery field if it doesn't exist
		if f := collection.Fields.GetByName("delivery"); f == nil {
			collection.Fields.Add(&core.SelectField{
				Name:      "delivery",
				MaxSelect: 1,
				Values:    []string{"draft", "pending", "sending", "sent", "failed"},
			})
		}

		return app.Save(collection)
	}, func(app core.App) error {
		return nil
	})
}
