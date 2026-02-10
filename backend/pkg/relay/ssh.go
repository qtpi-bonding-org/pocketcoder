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
