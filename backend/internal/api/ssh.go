package api

import (
	"fmt"
	"log"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterSSHApi registers the SSH public key sync endpoint.
func RegisterSSHApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	// 🔑 SSH PUBLIC KEYS SYNC ENDPOINT
	// Returns all authorized public keys as a newline-separated list
	e.Router.GET("/api/pocketcoder/ssh_keys", func(re *core.RequestEvent) error {
		// Fetch all active SSH keys from the ssh_keys collection
		sshKeys, err := app.FindRecordsByFilter("ssh_keys", "is_active = TRUE", "", 1000, 0, nil)
		if err != nil {
			log.Printf("❌ Failed to fetch SSH keys: %v", err)
			return re.String(500, fmt.Sprintf("Failed to fetch SSH keys: %v", err))
		}

		var keys []string
		for _, record := range sshKeys {
			key := record.GetString("public_key")
			if key != "" {
				keys = append(keys, key)
			}
		}

		return re.String(200, strings.Join(keys, "\n"))
	})
}
