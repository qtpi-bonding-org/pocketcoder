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


// @pocketcoder-core: SSH API. Handlers for public key registration and rotation.
package api

import (
	"fmt"
	"log"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
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
	}).Bind(apis.RequireAuth())
}
