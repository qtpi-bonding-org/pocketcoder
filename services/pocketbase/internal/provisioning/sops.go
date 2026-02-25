package provisioning

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// ProvisionSops syncs filesystem SOPs into the 'proposals' collection.
// They must still be manually 'Sealed' in the ledger to be usable by Poco.
func ProvisionSops(app *pocketbase.PocketBase) {
	provisioningDir := "/workspace/.opencode/proposals"
	
	if _, err := os.Stat(provisioningDir); os.IsNotExist(err) {
		return
	}

	files, err := os.ReadDir(provisioningDir)
	if err != nil {
		log.Printf("❌ [Provisioning] Failed to read SOP directory: %v", err)
		return
	}

	for _, file := range files {
		if !file.IsDir() && strings.HasSuffix(file.Name(), ".md") {
			processSopProposal(app, filepath.Join(provisioningDir, file.Name()))
		}
	}
}

func processSopProposal(app *pocketbase.PocketBase, path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return
	}

	content := string(data)
	name, description := extractMetadata(content)

	if name == "" {
		name = strings.TrimSuffix(filepath.Base(path), ".md")
	}

	collection, _ := app.FindCollectionByNameOrId("proposals")
	
	existing, _ := app.FindFirstRecordByFilter("proposals", "name = {:name}", map[string]any{"name": name})

	if existing != nil {
		if existing.GetString("content") != content {
			existing.Set("content", content)
			existing.Set("description", description)
			app.Save(existing)
			log.Printf("🔄 [Provisioning] Updated Proposal: %s", name)
		}
	} else {
		record := core.NewRecord(collection)
		record.Set("name", name)
		record.Set("description", description)
		record.Set("content", content)
		record.Set("authored_by", "human")
		record.Set("status", "draft")
		app.Save(record)
		log.Printf("📥 [Provisioning] Ingested Human Proposal: %s", name)
	}
}

// Simple metadata extractor for YAML frontmatter
func extractMetadata(content string) (name, description string) {
	lines := strings.Split(content, "\n")
	if len(lines) < 2 || !strings.HasPrefix(lines[0], "---") {
		return "", ""
	}

	inFrontmatter := false
	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if trimmed == "---" {
			if !inFrontmatter {
				inFrontmatter = true
				continue
			} else {
				break
			}
		}

		if inFrontmatter {
			parts := strings.SplitN(trimmed, ":", 2)
			if len(parts) == 2 {
				key := strings.TrimSpace(parts[0])
				val := strings.TrimSpace(parts[1])
				if key == "name" {
					name = val
				} else if key == "description" {
					description = val
				}
			}
		}
	}
	return name, description
}
