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
