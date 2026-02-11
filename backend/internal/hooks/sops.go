package hooks

import (
	"crypto/sha256"
	"encoding/hex"
	"log"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterSopHooks manages the transition from proposal to sealed SOP
func RegisterSopHooks(app *pocketbase.PocketBase) {
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
func SealProposal(app *pocketbase.PocketBase, proposal *core.Record) error {
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
	record, _ := app.FindFirstRecordByFilter("sops", "name = {:name}", map[string]any{"name": name})
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
