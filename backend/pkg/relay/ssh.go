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

// @pocketcoder-core: SSH Relayer. Coordinates public key distribution for the sandbox.
package relay

import (
	"fmt"
	"log"
	"os"
	"strings"

	"github.com/pocketbase/pocketbase/core"
)

func (r *RelayService) registerSSHKeyHooks() {
	// Sync SSH keys whenever they change
	r.app.OnRecordAfterCreateSuccess("ssh_keys").BindFunc(func(e *core.RecordEvent) error {
		log.Printf("🔑 [Relay] Syncing SSH keys due to creation: %s", e.Record.Id)
		return r.syncSSHKeys()
	})

	r.app.OnRecordAfterUpdateSuccess("ssh_keys").BindFunc(func(e *core.RecordEvent) error {
		log.Printf("🔑 [Relay] Syncing SSH keys due to update: %s", e.Record.Id)
		return r.syncSSHKeys()
	})

	r.app.OnRecordAfterDeleteSuccess("ssh_keys").BindFunc(func(e *core.RecordEvent) error {
		log.Printf("🔑 [Relay] Syncing SSH keys due to deletion: %s", e.Record.Id)
		return r.syncSSHKeys()
	})

	// Initial sync on startup
	log.Println("🔑 [Relay] Performing initial SSH key sync...")
	if err := r.syncSSHKeys(); err != nil {
		log.Printf("⚠️ [Relay] Initial SSH key sync failed: %v", err)
	}
}

func (r *RelayService) syncSSHKeys() error {
	// 1. Fetch all active keys
	records, err := r.app.FindRecordsByFilter(
		"ssh_keys",
		"is_active = true",
		"",
		0, 0,
	)
	if err != nil {
		return fmt.Errorf("failed to fetch active ssh keys: %w", err)
	}

	// 2. Build the authorized_keys content
	var sb strings.Builder
	for _, record := range records {
		key := record.GetString("public_key")
		if key != "" {
			sb.WriteString(key)
			sb.WriteString("\n")
		}
	}

	// 3. Write to the shared volume
	filePath := "/ssh_keys/authorized_keys"
	
	// Ensure directory exists (useful for local dev/testing)
	dir := "/ssh_keys"
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		// If we're not in the container with the volume, just log it.
		// In production, the volume is always there.
		log.Printf("⚠️ [Relay] SSH volume directory %s does not exist, skipping file write", dir)
		return nil
	}

	err = os.WriteFile(filePath, []byte(sb.String()), 0644)
	if err != nil {
		log.Printf("❌ [Relay] Failed to write SSH keys to %s: %v", filePath, err)
		return err
	}

	log.Printf("✅ [Relay] Synced %d SSH keys to %s", len(records), filePath)
	return nil
}
