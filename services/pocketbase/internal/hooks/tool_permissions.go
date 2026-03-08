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

// @pocketcoder-core: Tool Permission Hooks. Renders opencode.json permission + agent blocks and restarts OpenCode.
package hooks

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

const (
	openCodeConfigPath = "/workspace/.opencode/opencode.json"
)

type permEntry struct {
	tool    string
	pattern string
	action  string
}

// RegisterToolPermissionHooks registers hooks that re-render the OpenCode config
// whenever tool_permissions or ai_agents change.
func RegisterToolPermissionHooks(app core.App) {
	log.Println("⚙️ [ToolPerms] Registering tool permission hooks...")

	handleToolPermsChange := func(e *core.RecordEvent) error {
		log.Println("⚙️ [ToolPerms] Tool permissions changed, re-rendering opencode.json...")
		if err := renderOpenCodeConfig(app); err != nil {
			log.Printf("⚙️ [ToolPerms] Failed to render opencode.json: %v", err)
			return e.Next()
		}
		if err := restartContainer(openCodeContainer, 30*time.Second); err != nil {
			log.Printf("⚙️ [ToolPerms] Failed to restart OpenCode: %v", err)
		}
		return e.Next()
	}

	app.OnRecordAfterCreateSuccess("tool_permissions").BindFunc(handleToolPermsChange)
	app.OnRecordAfterUpdateSuccess("tool_permissions").BindFunc(handleToolPermsChange)
	app.OnRecordAfterDeleteSuccess("tool_permissions").BindFunc(handleToolPermsChange)

	// Also re-render when agent model or prompt changes
	app.OnRecordAfterUpdateSuccess("ai_agents").BindFunc(func(e *core.RecordEvent) error {
		log.Println("⚙️ [ToolPerms] Agent updated, re-rendering opencode.json...")
		if err := renderOpenCodeConfig(app); err != nil {
			log.Printf("⚙️ [ToolPerms] Failed to render opencode.json: %v", err)
			return e.Next()
		}
		if err := restartContainer(openCodeContainer, 30*time.Second); err != nil {
			log.Printf("⚙️ [ToolPerms] Failed to restart OpenCode: %v", err)
		}
		return e.Next()
	})

	// Initial render on startup
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		log.Println("⚙️ [ToolPerms] Performing initial opencode.json render...")
		if err := renderOpenCodeConfig(app); err != nil {
			log.Printf("⚙️ [ToolPerms] Initial opencode.json render failed: %v", err)
		} else {
			log.Println("⚙️ [ToolPerms] Initial opencode.json rendered successfully")
		}
		return e.Next()
	})
}

// renderOpenCodeConfig reads the existing opencode.json, patches the permission
// and agent blocks from PocketBase data, and writes it back.
func renderOpenCodeConfig(app core.App) error {
	// Read existing config
	configData, err := os.ReadFile(openCodeConfigPath)
	if err != nil {
		return fmt.Errorf("failed to read opencode.json: %w", err)
	}

	var config map[string]interface{}
	if err := json.Unmarshal(configData, &config); err != nil {
		return fmt.Errorf("failed to parse opencode.json: %w", err)
	}

	// Query all active tool_permissions
	allPerms, err := app.FindRecordsByFilter(
		"tool_permissions",
		"active = true",
		"",
		0, 0,
	)
	if err != nil {
		return fmt.Errorf("failed to query tool_permissions: %w", err)
	}

	// Separate global vs per-agent permissions
	var globalPerms []permEntry
	agentPermsMap := make(map[string][]permEntry) // agentId -> perms

	for _, rec := range allPerms {
		entry := permEntry{
			tool:    rec.GetString("tool"),
			pattern: rec.GetString("pattern"),
			action:  rec.GetString("action"),
		}
		agentId := rec.GetString("agent")
		if agentId == "" {
			globalPerms = append(globalPerms, entry)
		} else {
			agentPermsMap[agentId] = append(agentPermsMap[agentId], entry)
		}
	}

	// Build global permission block
	globalPermBlock := buildPermissionBlock(globalPerms)
	config["permission"] = globalPermBlock

	// Query all agents for model/prompt rendering
	agents, err := app.FindRecordsByFilter(
		"ai_agents",
		"1=1",
		"",
		0, 0,
	)
	if err != nil {
		return fmt.Errorf("failed to query ai_agents: %w", err)
	}

	// Get or create the agent block in config
	agentBlock, ok := config["agent"].(map[string]interface{})
	if !ok {
		agentBlock = make(map[string]interface{})
	}

	for _, agent := range agents {
		agentName := agent.GetString("name")
		if agentName == "" {
			continue
		}

		// Get existing agent config or create new one
		agentConfig, ok := agentBlock[agentName].(map[string]interface{})
		if !ok {
			agentConfig = make(map[string]interface{})
		}

		// Resolve model identifier via ai_models relation
		modelId := agent.GetString("model")
		if modelId != "" {
			modelRecord, err := app.FindRecordById("ai_models", modelId)
			if err == nil {
				agentConfig["model"] = modelRecord.GetString("identifier")
			}
		}

		// Resolve prompt body via ai_prompts relation
		promptId := agent.GetString("prompt")
		if promptId != "" {
			promptRecord, err := app.FindRecordById("ai_prompts", promptId)
			if err == nil {
				agentConfig["prompt"] = promptRecord.GetString("body")
			}
		}

		// Set agent metadata
		agentConfig["description"] = agent.GetString("description")
		agentConfig["mode"] = agent.GetString("mode")

		// Build per-agent permission block
		if perms, exists := agentPermsMap[agent.Id]; exists {
			agentConfig["permission"] = buildPermissionBlock(perms)
		}

		agentBlock[agentName] = agentConfig
	}

	config["agent"] = agentBlock

	// Write back
	rendered, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal opencode.json: %w", err)
	}

	if err := os.WriteFile(openCodeConfigPath, rendered, 0600); err != nil {
		return fmt.Errorf("failed to write opencode.json: %w", err)
	}

	log.Printf("⚙️ [ToolPerms] Rendered opencode.json at %s", time.Now().UTC().Format(time.RFC3339))
	return nil
}

// buildPermissionBlock converts a list of permission entries into the OpenCode
// permission format. Tools with only pattern="*" get flat format ("tool": "action").
// Tools with multiple patterns get nested format ("tool": {"pattern": "action", ...}).
func buildPermissionBlock(perms []permEntry) map[string]interface{} {
	// Group by tool
	toolPatterns := make(map[string][]permEntry)
	for _, p := range perms {
		toolPatterns[p.tool] = append(toolPatterns[p.tool], p)
	}

	result := make(map[string]interface{})
	for tool, entries := range toolPatterns {
		if len(entries) == 1 && entries[0].pattern == "*" {
			// Flat format: "tool": "action"
			result[tool] = entries[0].action
		} else {
			// Nested format: "tool": {"pattern": "action", ...}
			nested := make(map[string]interface{})
			for _, e := range entries {
				nested[e.pattern] = e.action
			}
			result[tool] = nested
		}
	}

	return result
}
