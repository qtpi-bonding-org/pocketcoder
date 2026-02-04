package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func ptr[T any](v T) *T {
	return &v
}

func init() {
	migrations.Register(func(app core.App) error {
		// 1. SETUP USERS COLLECTION (Roles & Auth)
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		// Add Role support (admin, user, agent, guest)
		users.Fields.Add(&core.SelectField{
			Name:      "role",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"admin", "user", "agent", "guest"},
		})

		// Support for WebAuthn Passkey components
		users.Fields.Add(&core.TextField{Name: "webauthn_id"})
		users.Fields.Add(&core.JSONField{Name: "webauthn_credentials"})
		
		// -------------------------------------------------------------------------
		// USER PERMISSIONS (Role-Based Access Control)
		// -------------------------------------------------------------------------
		
		// List/View: Only self or Admin
		users.ListRule = ptr("@request.auth.id = id || @request.auth.role = 'admin'")
		users.ViewRule = ptr("@request.auth.id = id || @request.auth.role = 'admin'")
		
		// Create: Only Admin
		users.CreateRule = ptr("@request.auth.role = 'admin'")
		
		// Update: Self (cannot change role) or Admin
		users.UpdateRule = ptr(`
			(@request.auth.id = id && @request.body.role = role) || 
			@request.auth.role = 'admin'
		`)
		
		// Delete: Only Admin
		users.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(users); err != nil {
			return err
		}

		// 2. SETUP COMMANDS COLLECTION (Definitions)
		// This stores the unique command strings and their hashes.
		commands := core.NewCollection(core.CollectionTypeBase, "commands")
		commands.Name = "commands"

		commands.Fields.Add(&core.TextField{Name: "hash", Required: true}) // SHA256
		commands.Fields.Add(&core.TextField{Name: "command", Required: true})
		
		// Add Unique Index on Hash
		commands.AddIndex("idx_commands_hash", true, "hash", "")

		// PERMISSIONS:
		// Agent can create (when proposing new command).
		// Everyone can read.
		commands.ListRule = ptr("@request.auth.id != ''")
		commands.ViewRule = ptr("@request.auth.id != ''")
		commands.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		commands.UpdateRule = ptr("@request.auth.role = 'admin'") // Only admin can edit definitions manually
		commands.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(commands); err != nil {
			return err
		}

		// 3. SETUP EXECUTIONS COLLECTION (Instances)
		// This stores the actual run history.
		executions := core.NewCollection(core.CollectionTypeBase, "executions")
		executions.Name = "executions"

		executions.Fields.Add(&core.RelationField{
			Name:     "command",
			Required: false,
			CollectionId: commands.Id,
			MaxSelect: 1,
		})
		executions.Fields.Add(&core.TextField{Name: "cwd"})
		executions.Fields.Add(&core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"draft", "authorized", "denied", "executing", "completed", "failed"},
		})
		executions.Fields.Add(&core.TextField{Name: "source"})
		executions.Fields.Add(&core.JSONField{Name: "outputs"})
		executions.Fields.Add(&core.NumberField{Name: "exit_code"})
		executions.Fields.Add(&core.JSONField{Name: "metadata"}) // OpenCode metadata
		executions.Fields.Add(&core.TextField{Name: "opencode_id"})
		executions.Fields.Add(&core.TextField{Name: "type"})
		executions.Fields.Add(&core.JSONField{Name: "patterns"})
		executions.Fields.Add(&core.TextField{Name: "session_id"})
		executions.Fields.Add(&core.TextField{Name: "message_id"})
		executions.Fields.Add(&core.TextField{Name: "call_id"})
		executions.Fields.Add(&core.TextField{Name: "message"})   // Maps to OpenCode.Info.message

		// PERMISSIONS:
		// Agent Creates.
		// Admin/User Updates (Signs).
		// Agent Updates (Reports result).
		executions.ListRule = ptr("@request.auth.id != ''")
		executions.ViewRule = ptr("@request.auth.id != ''")
		executions.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		
		// UPDATE:
		// 1. User/Admin can sign DRAFTS.
		// 2. Agent can update AUTHORIZED -> EXECUTING -> COMPLETED/FAILED.
		executions.UpdateRule = ptr(`
			((@request.auth.role = 'user' || @request.auth.role = 'admin') && status = 'draft') || 
			(@request.auth.role = 'agent' && (status = 'authorized' || status = 'executing'))
		`)
		
		executions.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(executions); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		// Cleanup
		if c, _ := app.FindCollectionByNameOrId("executions"); c != nil { app.Delete(c) }
		if c, _ := app.FindCollectionByNameOrId("commands"); c != nil { app.Delete(c) }
		return nil
	})
}
