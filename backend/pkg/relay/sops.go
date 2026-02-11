package relay

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
)

func (r *RelayService) registerSopHooks() {
	// 1. Proposals: Bi-directional Collaborative Sync
	syncProposal := func(e *core.RecordEvent) error {
		go r.deployProposal(e.Record)
		return e.Next()
	}
	r.app.OnRecordAfterCreateSuccess("proposals").BindFunc(syncProposal)
	r.app.OnRecordAfterUpdateSuccess("proposals").BindFunc(syncProposal)

	// 2. Sealed SOPs: Uni-directional Materializer
	syncSOP := func(e *core.RecordEvent) error {
		go r.deploySealedSop(e.Record)
		return e.Next()
	}
	r.app.OnRecordAfterCreateSuccess("sops").BindFunc(syncSOP)
	r.app.OnRecordAfterUpdateSuccess("sops").BindFunc(syncSOP)

	// Initial Sync
	go r.syncAllProposals()
	go r.syncAllSops()
}

// deployProposal writes drafts to the .opencode/proposals directory
func (r *RelayService) deployProposal(proposal *core.Record) {
	name := proposal.GetString("name")
	content := proposal.GetString("content")

	targetDir := "/workspace/.opencode/proposals"
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return
	}

	filePath := filepath.Join(targetDir, fmt.Sprintf("%s.md", name))
	os.WriteFile(filePath, []byte(content), 0644)
}

// deploySealedSop writes final SOPs to the native .opencode/skills mount
func (r *RelayService) deploySealedSop(sop *core.Record) {
	name := sop.GetString("name")
	content := sop.GetString("content")

	targetDir := filepath.Join("/workspace/.opencode/skills", name)
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		return
	}

	filePath := filepath.Join(targetDir, "SKILL.md")
	os.WriteFile(filePath, []byte(content), 0644)
    log.Printf("📜 [Relay/SOP] Materialized Sovereign SOP: %s", name)
}

func (r *RelayService) syncAllProposals() {
	records, _ := r.app.FindRecordsByFilter("proposals", "1=1", "", 0, 0)
	for _, rec := range records {
		r.deployProposal(rec)
	}
}

func (r *RelayService) syncAllSops() {
	records, _ := r.app.FindRecordsByFilter("sops", "1=1", "", 0, 0)
	for _, rec := range records {
		r.deploySealedSop(rec)
	}
}
