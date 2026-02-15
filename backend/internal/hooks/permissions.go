/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/


// @pocketcoder-core: Permission Engine. Registers hooks for auditing and gating record creation.
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
