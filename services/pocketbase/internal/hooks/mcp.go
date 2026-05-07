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

// @pocketcoder-core: MCP Hooks. Handles MCP server lifecycle, config rendering, and gateway restart.
package hooks

import (
	"fmt"
	"log"
	"os"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

const (
	mcpConfigPath  = "/mcp_config/docker-mcp.yaml"
	mcpSecretsPath = "/mcp_config/mcp.env"
)

// RegisterMcpHooks registers hooks for MCP server lifecycle management.
// When a user approves or revokes an MCP server in the Flutter UI, this hook
// re-renders the gateway config and restarts the MCP gateway container.
// The interface receives status updates via PocketBase realtime subscriptions.
func RegisterMcpHooks(app core.App) {
	log.Println("🔌 [MCP] Registering MCP server hooks...")

	app.OnRecordAfterUpdateSuccess("mcp_servers").BindFunc(func(e *core.RecordEvent) error {
		record := e.Record
		newStatus := record.GetString("status")
		serverName := record.GetString("name")

		log.Printf("🔌 [MCP] Server '%s' status changed to '%s'", serverName, newStatus)

		switch newStatus {
		case "approved", "revoked":
			log.Printf("🔌 [MCP] Processing %s for server '%s'", newStatus, serverName)
			if err := renderMcpConfig(app); err != nil {
				log.Printf("❌ [MCP] Failed to render config: %v", err)
				return e.Next()
			}
			if err := restartContainer(GatewayContainer, 30*time.Second); err != nil {
				log.Printf("❌ [MCP] Failed to restart gateway: %v", err)
			}
		case "denied":
			log.Printf("🔌 [MCP] Server '%s' was denied", serverName)
		}

		return e.Next()
	})

	// Initial config render after the app is fully started (DB must be ready)
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		log.Println("🔌 [MCP] Performing initial config render...")
		if err := renderMcpConfig(app); err != nil {
			log.Printf("⚠️ [MCP] Initial config render failed: %v", err)
		} else {
			log.Println("✅ [MCP] Initial config rendered successfully")
		}
		return e.Next()
	})
}

// renderMcpConfig queries approved MCP servers and writes docker-mcp.yaml and mcp.env
// to the shared /mcp_config volume. The gateway reads these on startup.
func renderMcpConfig(app core.App) error {
	records, err := app.FindRecordsByFilter(
		"mcp_servers",
		"status = 'approved'",
		"",
		0, 0,
	)
	if err != nil {
		return fmt.Errorf("failed to query approved MCP servers: %w", err)
	}

	dir := "/mcp_config"
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		if mkErr := os.MkdirAll(dir, 0755); mkErr != nil {
			return fmt.Errorf("failed to create MCP config directory: %w", mkErr)
		}
	}

	var catalog strings.Builder
	catalog.WriteString("# PocketCoder MCP Catalog (auto-generated)\n")
	catalog.WriteString(fmt.Sprintf("# Last rendered: %s\n", time.Now().UTC().Format(time.RFC3339)))
	catalog.WriteString(fmt.Sprintf("# Approved servers: %d\n", len(records)))
	catalog.WriteString("name: docker-mcp\n")
	catalog.WriteString("displayName: PocketCoder Dynamic Catalog\n")
	catalog.WriteString("registry:\n")

	var secrets strings.Builder
	secrets.WriteString("# PocketCoder MCP Secrets (auto-generated)\n")
	secrets.WriteString(fmt.Sprintf("# Last rendered: %s\n", time.Now().UTC().Format(time.RFC3339)))
	secrets.WriteString(fmt.Sprintf("# Approved servers: %d\n", len(records)))

	// Deduplicate by name, keep latest
	uniqueServers := make(map[string]*core.Record)
	for _, record := range records {
		name := record.GetString("name")
		if existing, ok := uniqueServers[name]; !ok || record.GetDateTime("updated").Time().After(existing.GetDateTime("updated").Time()) {
			uniqueServers[name] = record
		}
	}

	for _, record := range uniqueServers {
		name := record.GetString("name")
		image := record.GetString("image")

		if image == "" {
			image = fmt.Sprintf("mcp/%s", name)
		}
		if !strings.Contains(image, ":") && !strings.Contains(image, "@") {
			image = image + ":latest"
		}

		catalog.WriteString(fmt.Sprintf("  %s:\n", name))
		catalog.WriteString(fmt.Sprintf("    title: %s\n", name))
		catalog.WriteString("    description: Approved by user for PocketCoder\n")
		catalog.WriteString("    type: server\n")
		catalog.WriteString(fmt.Sprintf("    image: %s\n", image))
		catalog.WriteString("    longLived: false\n")

		configMap := make(map[string]any)
		if err := record.UnmarshalJSONField("config", &configMap); err == nil && len(configMap) > 0 {
			catalog.WriteString("    secrets:\n")
			for k, v := range configMap {
				secrets.WriteString(fmt.Sprintf("%s=%v\n", k, v))
				catalog.WriteString(fmt.Sprintf("      - name: %s\n        env: %s\n", k, k))
			}
		}
	}

	// Atomic writes: write to temp files first, then rename
	tmpCatalog := mcpConfigPath + ".tmp"
	if err := os.WriteFile(tmpCatalog, []byte(catalog.String()), 0600); err != nil {
		return fmt.Errorf("failed to write catalog to %s: %w", tmpCatalog, err)
	}

	tmpSecrets := mcpSecretsPath + ".tmp"
	if err := os.WriteFile(tmpSecrets, []byte(secrets.String()), 0600); err != nil {
		os.Remove(tmpCatalog)
		return fmt.Errorf("failed to write secrets to %s: %w", tmpSecrets, err)
	}

	if err := os.Rename(tmpCatalog, mcpConfigPath); err != nil {
		os.Remove(tmpCatalog)
		os.Remove(tmpSecrets)
		return fmt.Errorf("failed to rename catalog: %w", err)
	}
	if err := os.Rename(tmpSecrets, mcpSecretsPath); err != nil {
		os.Remove(tmpSecrets)
		return fmt.Errorf("failed to rename secrets: %w", err)
	}

	log.Printf("✅ [MCP] Rendered catalog and secrets for %d approved servers", len(uniqueServers))
	return nil
}

