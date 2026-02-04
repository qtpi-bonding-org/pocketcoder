package migrations

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
		// The rule (@request.body.role = role) ensures that if a non-admin is updating, 
		// the role being set MUST match the current role.
		users.UpdateRule = ptr(`
			(@request.auth.id = id && @request.body.role = role) || 
			@request.auth.role = 'admin'
		`)
		
		// Delete: Only Admin
		users.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(users); err != nil {
			return err
		}

		// 2. SETUP INTENTS COLLECTION (The Law)
		intents := core.NewCollection(core.CollectionTypeBase, "intents")
		intents.Name = "intents"

		// 1:1 Parity with OpenCode Permission.Info
		intents.Fields.Add(&core.TextField{Name: "opencode_id", Required: true})
		intents.Fields.Add(&core.TextField{Name: "type", Required: true})
		intents.Fields.Add(&core.TextField{Name: "message"})
		intents.Fields.Add(&core.JSONField{Name: "metadata"})
		intents.Fields.Add(&core.JSONField{Name: "pattern"})
		intents.Fields.Add(&core.TextField{Name: "session_id"})
		intents.Fields.Add(&core.TextField{Name: "message_id"})
		intents.Fields.Add(&core.TextField{Name: "call_id"})
		intents.Fields.Add(&core.NumberField{Name: "time_created"})

		// Authorization Logic Fields
		intents.Fields.Add(&core.TextField{Name: "reasoning"})
		intents.Fields.Add(&core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"draft", "authorized", "denied", "executing", "completed", "failed"},
		})
		intents.Fields.Add(&core.JSONField{Name: "output"})

		// -------------------------------------------------------------------------
		// INTENT PERMISSIONS (Authorization Workflow)
		// -------------------------------------------------------------------------
		
		// CREATE: Agents can only create DRAFT intents.
		// Using 'status' here refers to the value being created.
		intents.CreateRule = ptr("(@request.auth.role = 'agent' && status = 'draft') || @request.auth.role = 'admin'")
		
		// VIEW: Any authenticated user can see the logs.
		intents.ListRule = ptr("@request.auth.id != ''")
		intents.ViewRule = ptr("@request.auth.id != ''")
		
		// UPDATE (The State Machine):
		// Simplified for Genesis to avoid syntax errors with @request.data
		// 1. ADMIN/USER: Can update only if current status is 'draft'
		// 2. AGENT: Can update only if current status is 'authorized' (to move to executing/completed)
		intents.UpdateRule = ptr(`
			((@request.auth.role = 'user' || @request.auth.role = 'admin') && status = 'draft') || 
			(@request.auth.role = 'agent' && status = 'authorized')
		`)
		
		// DELETE: Strictly Admin only.
		intents.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(intents); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		i, _ := app.FindCollectionByNameOrId("intents")
		if i != nil { app.Delete(i) }
		return nil
	})
}
