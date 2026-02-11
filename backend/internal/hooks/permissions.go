package hooks

import (
	"log"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterPermissionHooks registers hooks for the permissions collection.
func RegisterPermissionHooks(app *pocketbase.PocketBase) {
	// 1. CREATION: Generate Challenge, Default to Draft
	app.OnRecordCreate("permissions").BindFunc(func(e *core.RecordEvent) error {
		permission := e.Record.GetString("permission")

		// Generate Authority Challenge (for cryptographic verification if needed later)
		e.Record.Set("challenge", uuid.NewString())

		// Ensure initial status is draft if not already set by Authority
		if e.Record.GetString("status") == "" {
			e.Record.Set("status", "draft")
		}

		log.Printf("🛡️ [Permission Firewall] Gating: %s. Status: %s", permission, e.Record.GetString("status"))

		return e.Next()
	})
}
