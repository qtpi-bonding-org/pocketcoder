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
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

const (
	mcpConfigPath    = "/mcp_config/docker-mcp.yaml"
	mcpSecretsPath   = "/mcp_config/mcp.env"
	gatewayContainer = "pocketcoder-mcp-gateway"
)

// RegisterMcpHooks registers hooks for MCP server lifecycle management.
// When a user approves or revokes an MCP server in the Flutter UI, this hook
// re-renders the gateway config and restarts the MCP gateway container.
func RegisterMcpHooks(app core.App, openCodeURL string) {
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
			if err := restartContainer(gatewayContainer, 30*time.Second); err != nil {
				log.Printf("❌ [MCP] Failed to restart gateway: %v", err)
			}
			notifyPoco(app, openCodeURL, serverName, newStatus)
		case "denied":
			log.Printf("🔌 [MCP] Server '%s' was denied", serverName)
			notifyPoco(app, openCodeURL, serverName, newStatus)
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

	if err := os.WriteFile(mcpConfigPath, []byte(catalog.String()), 0600); err != nil {
		return fmt.Errorf("failed to write catalog to %s: %w", mcpConfigPath, err)
	}

	if err := os.WriteFile(mcpSecretsPath, []byte(secrets.String()), 0600); err != nil {
		return fmt.Errorf("failed to write secrets to %s: %w", mcpSecretsPath, err)
	}

	log.Printf("✅ [MCP] Rendered catalog and secrets for %d approved servers", len(uniqueServers))
	return nil
}

// notifyPoco sends a system message to Poco about MCP server status changes.
func notifyPoco(app core.App, openCodeURL string, serverName string, status string) {
	log.Printf("📢 [MCP] Notifying Poco about server '%s' status: %s", serverName, status)

	chats, err := app.FindRecordsByFilter(
		"chats",
		"ai_engine_session_id != '' && turn = 'assistant'",
		"-last_active",
		10, 0,
	)
	if err != nil {
		log.Printf("⚠️ [MCP] Failed to find chats for notification: %v", err)
		return
	}

	var message string
	switch status {
	case "approved":
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' is now available. Sandbox agents can connect to the gateway at http://mcp-gateway:8811/sse.", serverName)
	case "revoked":
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' has been revoked and is no longer available to sandbox agents.", serverName)
	case "denied":
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' request was denied by the user.", serverName)
	default:
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' status updated to '%s'.", serverName, status)
	}

	for _, chat := range chats {
		chatID := chat.Id
		sessionID := chat.GetString("ai_engine_session_id")
		if sessionID == "" {
			continue
		}

		url := fmt.Sprintf("%s/session/%s/prompt_async", openCodeURL, sessionID)
		payload := map[string]interface{}{
			"parts": []interface{}{
				map[string]interface{}{
					"type": "text",
					"text": message,
				},
			},
		}
		body, _ := json.Marshal(payload)

		client := &http.Client{Timeout: 10 * time.Second}
		resp, err := client.Post(url, "application/json", strings.NewReader(string(body)))
		if err != nil {
			log.Printf("⚠️ [MCP] Failed to notify Poco for chat %s: %v", chatID, err)
			continue
		}
		resp.Body.Close()

		log.Printf("✅ [MCP] Notification sent to Poco for chat %s", chatID)
	}
}
