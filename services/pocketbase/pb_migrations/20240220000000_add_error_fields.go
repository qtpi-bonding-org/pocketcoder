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

		// Add error_domain field (Select type with values "infrastructure" and "provider")
		errorDomain := &core.SelectField{
			Name:      "error_domain",
			MaxSelect: 1,
			Values:    []string{"infrastructure", "provider"},
		}
		if existing := collection.Fields.GetByName(errorDomain.GetName()); existing == nil {
			collection.Fields.Add(errorDomain)
		}

		// Add error_payload field (JSON type with 1MB max size)
		errorPayload := &core.JSONField{
			Name:    "error_payload",
			MaxSize: 1048576, // 1MB
		}
		if existing := collection.Fields.GetByName(errorPayload.GetName()); existing == nil {
			collection.Fields.Add(errorPayload)
		}

		return app.Save(collection)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("messages")
		if err != nil {
			return err
		}

		// Remove error_domain field
		collection.Fields.RemoveByName("error_domain")

		// Remove error_payload field
		collection.Fields.RemoveByName("error_payload")

		return app.Save(collection)
	})
}