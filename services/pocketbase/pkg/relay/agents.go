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

// @pocketcoder-core: Agent Relayer. Syncs agent state between OpenCode and PocketBase.
package relay

import (
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"
)

// deployAgent writes the agent configuration to the filesystem for OpenCode to consume.
func (r *RelayService) deployAgent(agent *core.Record) {
	name := agent.GetString("name")
	isInit := agent.GetBool("is_init")
	config := agent.GetString("config")

	if name == "" || config == "" {
		return
	}

	fileName := fmt.Sprintf("%s.md", name)
	
	// Determine target directory matching the Node relay logic
	targetDir := "/workspace/sandbox/caoc/agent_store"
	if isInit {
		targetDir = "/workspace/.opencode/agents"
	}

	// Ensure directory exists
	if err := os.MkdirAll(targetDir, 0755); err != nil {
		log.Printf("❌ [Relay/Go] Failed to create agent dir %s: %v", targetDir, err)
		return
	}

	filePath := filepath.Join(targetDir, fileName)
	if err := os.WriteFile(filePath, []byte(config), 0644); err != nil {
		log.Printf("❌ [Relay/Go] Failed to deploy agent %s: %v", name, err)
		return
	}

	log.Printf("🚀 [Relay/Go] Deployed Agent: %s -> %s", name, filePath)
}

// syncAllAgents performs an initial deployment of all agents in the registry.
func (r *RelayService) syncAllAgents() {
	records, err := r.app.FindRecordsByFilter("ai_agents", "1=1", "", 0, 0)
	if err != nil {
		log.Printf("⚠️ [Relay/Go] Initial agent sync failed: %v", err)
		return
	}

	for _, agent := range records {
		r.deployAgent(agent)
	}
}
