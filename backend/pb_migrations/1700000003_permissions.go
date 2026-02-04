package pb_migrations

import (
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/migrations"
)

func init() {
	migrations.Register(func(app core.App) error {
		// -------------------------------------------------------------------------
		// PERMISSIONS COLLECTION (1:1 with OpenCode PermissionNext.Request)
		// -------------------------------------------------------------------------
		// This tracks permission requests from the Plugin.
		// Fields match OpenCode's schema exactly.
		
		permissions := core.NewCollection(core.CollectionTypeBase, "permissions")
		permissions.Name = "permissions"

		// Core OpenCode fields (from PermissionNext.Request)
		permissions.Fields.Add(&core.TextField{
			Name:     "opencode_id",
			Required: true,
		}) // Maps to Request.id (Identifier.schema("permission"))

		permissions.Fields.Add(&core.TextField{
			Name:     "session_id",
			Required: true,
		}) // Maps to Request.sessionID

		permissions.Fields.Add(&core.TextField{
			Name:     "permission",
			Required: true,
		}) // Maps to Request.permission (e.g., "bash", "edit", "read")

		permissions.Fields.Add(&core.JSONField{
			Name: "patterns",
		}) // Maps to Request.patterns (string array)

		permissions.Fields.Add(&core.JSONField{
			Name: "metadata",
		}) // Maps to Request.metadata (record<string, any>)

		permissions.Fields.Add(&core.JSONField{
			Name: "always",
		}) // Maps to Request.always (string array for "always allow" patterns)

		// Tool context (optional, from Request.tool)
		permissions.Fields.Add(&core.TextField{
			Name: "message_id",
		}) // Maps to Request.tool.messageID

		permissions.Fields.Add(&core.TextField{
			Name: "call_id",
		}) // Maps to Request.tool.callID

		// PocketCoder-specific fields
		permissions.Fields.Add(&core.SelectField{
			Name:      "status",
			Required:  true,
			MaxSelect: 1,
			Values:    []string{"draft", "authorized", "denied"},
		})

		permissions.Fields.Add(&core.TextField{
			Name: "source",
		}) // Always "opencode-plugin"

		permissions.Fields.Add(&core.TextField{
			Name: "message",
		}) // Human-readable description (from legacy Permission.Info.message)

		// Indexes
		permissions.AddIndex("idx_permissions_opencode_id", true, "opencode_id", "")
		permissions.AddIndex("idx_permissions_session_id", false, "session_id", "")

		// PERMISSIONS
		permissions.ListRule = ptr("@request.auth.id != ''")
		permissions.ViewRule = ptr("@request.auth.id != ''")
		permissions.CreateRule = ptr("@request.auth.role = 'agent' || @request.auth.role = 'admin'")
		
		// UPDATE: User/Admin can authorize/deny drafts
		permissions.UpdateRule = ptr(`
			((@request.auth.role = 'user' || @request.auth.role = 'admin') && status = 'draft')
		`)
		
		permissions.DeleteRule = ptr("@request.auth.role = 'admin'")

		if err := app.Save(permissions); err != nil {
			return err
		}

		// -------------------------------------------------------------------------
		// UPDATE EXECUTIONS COLLECTION
		// -------------------------------------------------------------------------
		// Remove OpenCode-specific fields (moved to permissions)
		// Keep execution-specific fields (results, outputs, exit codes)
		
		executions, err := app.FindCollectionByNameOrId("executions")
		if err != nil {
			return err
		}

		// Add relation to permissions
		executions.Fields.Add(&core.RelationField{
			Name:         "permission",
			Required:     false, // Optional because legacy executions won't have it
			CollectionId: permissions.Id,
			MaxSelect:    1,
		})

		// Note: We're NOT removing the OpenCode fields yet for backward compatibility
		// They will be deprecated in favor of the permission relation
		// Future migration can clean them up once all systems use the new flow

		if err := app.Save(executions); err != nil {
			return err
		}

		return nil
	}, func(app core.App) error {
		// Rollback
		p, _ := app.FindCollectionByNameOrId("permissions")
		if p != nil {
			app.Delete(p)
		}
		
		// Remove permission relation from executions
		e, _ := app.FindCollectionByNameOrId("executions")
		if e != nil {
			e.Fields.RemoveByName("permission")
			app.Save(e)
		}
		
		return nil
	})
}
