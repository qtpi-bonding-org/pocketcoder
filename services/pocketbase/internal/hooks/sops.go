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

// @pocketcoder-core: SOP Hooks. Seals approved proposals into the governance ledger.
package hooks

import (
	"crypto/sha256"
	"encoding/hex"
	"log"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

// RegisterSopHooks manages the transition from proposal to sealed SOP
func RegisterSopHooks(app core.App) {
	app.OnRecordAfterUpdateSuccess("proposals").BindFunc(func(e *core.RecordEvent) error {
		status := e.Record.GetString("status")
		
		// If the proposal is approved, trigger the sealing process
		if status == "approved" {
			log.Printf("🛡️ [SOP/Governance] Proposal '%s' APPROVED. Sealing into ledger...", e.Record.GetString("name"))
			if err := SealProposal(app, e.Record); err != nil {
				log.Printf("❌ [SOP/Governance] Failed to seal proposal: %v", err)
				return err
			}
		}
		
		return e.Next()
	})
}

// SealProposal takes a proposal record, hashes it, and promotes it to the sops ledger.
// This is the "Master of Signature" implementation where the backend handles integrity.
func SealProposal(app core.App, proposal *core.Record) error {
	name := proposal.GetString("name")
	content := proposal.GetString("content")
	description := proposal.GetString("description")

	// 1. Calculate the Sovereign Signature (SHA256)
	// This ensures that the actual executable content is cryptographically signed by the backend.
	hash := sha256.Sum256([]byte(content))
	signature := hex.EncodeToString(hash[:])

	sopCollection, err := app.FindCollectionByNameOrId("sops")
	if err != nil {
		return err
	}

	// 2. Look for existing record to update or create new
	// We use the name as a unique identifier for the SOP in the ledger.
	record, err := app.FindFirstRecordByFilter("sops", "name = {:name}", map[string]any{"name": name})
	if err != nil {
		log.Printf("⚠️ [SOP] Lookup for '%s' failed: %v (creating new)", name, err)
	}
	if record == nil {
		record = core.NewRecord(sopCollection)
		record.Set("name", name)
	}

	record.Set("description", description)
	record.Set("content", content)
	record.Set("signature", signature)
	record.Set("approved_at", time.Now().UTC())

	if err := app.Save(record); err != nil {
		log.Printf("❌ [SOP/Seal] Failed to manifest SOP %s: %v", name, err)
		return err
	}

	log.Printf("🛡️ [SOP/Seal] SOP '%s' Manifested & Signed: %s", name, signature)
	return nil
}
