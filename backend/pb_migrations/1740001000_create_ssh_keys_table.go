package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// Fetch users collection to get ID
		usersCollection, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		// Create ssh_keys collection
		sshKeys := core.NewCollection(core.CollectionTypeBase, "ssh_keys")
		sshKeys.Name = "ssh_keys"

		// Add fields
		sshKeys.Fields.Add(&core.RelationField{
			Name:         "user",
			Required:     true,
			CollectionId: usersCollection.Id,
			MaxSelect:    1,
		})
		sshKeys.Fields.Add(&core.TextField{
			Name:     "public_key",
			Required: true,
		})
		sshKeys.Fields.Add(&core.TextField{
			Name:     "device_name",
			Required: false,
		})
		sshKeys.Fields.Add(&core.TextField{
			Name:     "fingerprint",
			Required: true,
		})
		sshKeys.Fields.Add(&core.DateField{
			Name:     "last_used",
			Required: false,
		})
		sshKeys.Fields.Add(&core.BoolField{
			Name: "is_active",
		})

		// Add indexes
		sshKeys.AddIndex("idx_ssh_keys_user", false, "user", "")
		sshKeys.AddIndex("idx_ssh_keys_fingerprint", false, "fingerprint", "")
		sshKeys.AddIndex("idx_ssh_keys_active", false, "is_active", "")

		// Set rules - Allow authenticated users to list all keys (needed for relay sync and realtime subscriptions)
		// The relay needs to see all SSH keys to sync them
		sshKeys.ListRule = ptr("@request.auth.id != ''") // Any authenticated user can list
		sshKeys.ViewRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		sshKeys.CreateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		sshKeys.UpdateRule = ptr("@request.auth.id != '' && user = @request.auth.id")
		sshKeys.DeleteRule = ptr("@request.auth.id != '' && user = @request.auth.id")

		return app.Save(sshKeys)
	}, func(app core.App) error {
		collection, err := app.FindCollectionByNameOrId("ssh_keys")
		if err != nil {
			return err
		}
		return app.Delete(collection)
	})
}
