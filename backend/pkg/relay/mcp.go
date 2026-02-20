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

// @pocketcoder-core: MCP Relayer. Handles MCP server lifecycle, config rendering, and gateway management.
package relay

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

const (
	mcpConfigPath     = "/mcp_config/docker-mcp.yaml"
	gatewayContainer  = "pocketcoder-mcp-gateway"
	dockerHost        = "tcp://docker-socket-proxy:2375"
)

// registerMcpHooks registers hooks for MCP server lifecycle management
func (r *RelayService) registerMcpHooks() {
	log.Println("🔌 [Relay/MCP] Registering MCP server hooks...")

	// Hook on mcp_servers record updates
	r.app.OnRecordAfterUpdateSuccess("mcp_servers").BindFunc(func(e *core.RecordEvent) error {
		record := e.Record
		newStatus := record.GetString("status")
		serverName := record.GetString("name")

		log.Printf("🔌 [Relay/MCP] MCP server '%s' status changed to '%s'", serverName, newStatus)

		switch newStatus {
		case "approved", "revoked":
			// Re-render config, restart gateway, notify Poco
			log.Printf("🔌 [Relay/MCP] Processing %s for server '%s'", newStatus, serverName)
			if err := r.renderMcpConfig(); err != nil {
				log.Printf("❌ [Relay/MCP] Failed to render MCP config: %v", err)
				return e.Next()
			}
			if err := r.restartGateway(); err != nil {
				log.Printf("❌ [Relay/MCP] Failed to restart gateway: %v", err)
				// Continue to notify even if restart fails
			}
			r.notifyPoco(serverName, newStatus)
		case "denied":
			// Just notify Poco of denial
			log.Printf("🔌 [Relay/MCP] Server '%s' was denied", serverName)
			r.notifyPoco(serverName, newStatus)
		default:
			log.Printf("🔌 [Relay/MCP] Ignoring status '%s' for server '%s'", newStatus, serverName)
		}

		return e.Next()
	})

	// Initial config render on startup
	log.Println("🔌 [Relay/MCP] Performing initial MCP config render...")
	if err := r.renderMcpConfig(); err != nil {
		log.Printf("⚠️ [Relay/MCP] Initial config render failed: %v", err)
	} else {
		log.Println("✅ [Relay/MCP] Initial MCP config rendered successfully")
	}
}

// renderMcpConfig queries approved MCP servers and writes docker-mcp.yaml to the
// shared mcp_config volume. This file serves as a custom catalog for the gateway.
//
// The gateway starts with --catalog pointing to this file. Subagents connect to
// the gateway SSE and use Dynamic MCP tools (mcp-find, mcp-add) to discover and
// add servers from this catalog on-demand. The gateway spins up containers
// automatically when a subagent calls mcp-add.
//
// Poco also reads this file (mounted read-only at /mcp_config) to know what
// servers are currently approved before requesting new ones.
//
// Format matches docker/mcp-gateway catalog expectations:
//
//   registry:
//     <name>:
//       title: <Name>
//       description: Approved by user for PocketCoder
//       type: server
//       image: mcp/<name>
func (r *RelayService) renderMcpConfig() error {
	// Query all approved MCP servers
	records, err := r.app.FindRecordsByFilter(
		"mcp_servers",
		"status = 'approved'",
		"",
		0, 0,
	)
	if err != nil {
		return fmt.Errorf("failed to query approved MCP servers: %w", err)
	}

	serverNames := make([]string, 0, len(records))
	for _, record := range records {
		serverNames = append(serverNames, record.GetString("name"))
	}

	// Ensure directory exists
	dir := "/mcp_config"
	if _, err := os.Stat(dir); os.IsNotExist(err) {
		log.Printf("⚠️ [Relay/MCP] MCP config directory %s does not exist, attempting to create", dir)
		if mkErr := os.MkdirAll(dir, 0755); mkErr != nil {
			return fmt.Errorf("failed to create MCP config directory: %w", mkErr)
		}
	}

	// Build docker-mcp.yaml as a gateway catalog
	// Format must match the flat registry schema verified in test-mcp-install sandbox.
	// Key details:
	//   - Top-level name/displayName required for catalog identity
	//   - longLived: false (CamelCase) ensures ephemeral containers (die after each tool result)
	//   - type: server is required for standard MCP server entries
	var catalog strings.Builder
	catalog.WriteString("# PocketCoder MCP Catalog (auto-generated)\n")
	catalog.WriteString(fmt.Sprintf("# Last rendered: %s\n", time.Now().UTC().Format(time.RFC3339)))
	catalog.WriteString(fmt.Sprintf("# Approved servers: %d\n", len(serverNames)))
	catalog.WriteString("name: docker-mcp\n")
	catalog.WriteString("displayName: PocketCoder Dynamic Catalog\n")
	catalog.WriteString("registry:\n")
	for _, name := range serverNames {
		catalog.WriteString(fmt.Sprintf("  %s:\n", name))
		catalog.WriteString(fmt.Sprintf("    title: %s\n", name))
		catalog.WriteString("    description: Approved by user for PocketCoder\n")
		catalog.WriteString("    type: server\n")
		catalog.WriteString(fmt.Sprintf("    image: mcp/%s\n", name))
		catalog.WriteString("    longLived: false\n")
	}

	if err := os.WriteFile(mcpConfigPath, []byte(catalog.String()), 0644); err != nil {
		return fmt.Errorf("failed to write catalog to %s: %w", mcpConfigPath, err)
	}

	log.Printf("✅ [Relay/MCP] Rendered MCP catalog with %d approved servers to %s", len(serverNames), mcpConfigPath)
	return nil
}

// restartGateway sends a restart command to the Docker gateway container via the Docker Socket Proxy
func (r *RelayService) restartGateway() error {
	log.Printf("🔄 [Relay/MCP] Restarting MCP gateway container '%s'...", gatewayContainer)

	// Get Docker host from environment or use default proxy endpoint
	host := os.Getenv("DOCKER_HOST")
	if host == "" {
		host = dockerHost
	}

	// Parse the host URL to extract the address
	proxyAddr := host
	if strings.HasPrefix(host, "tcp://") {
		proxyAddr = strings.TrimPrefix(host, "tcp://")
	}

	// Create HTTP client for TCP connection to proxy
	client := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
				// Always dial the proxy address, ignoring the addr parameter
				return net.Dial("tcp", proxyAddr)
			},
		},
		Timeout: 10 * time.Second,
	}

	// Docker API endpoint for container restart
	apiPath := fmt.Sprintf("http://%s/containers/%s/restart", proxyAddr, gatewayContainer)
	resp, err := client.Post(apiPath, "application/json", nil)
	if err != nil {
		return fmt.Errorf("failed to call Docker API via proxy: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == http.StatusNotFound {
		log.Printf("⚠️ [Relay/MCP] Gateway container '%s' not found, skipping restart", gatewayContainer)
		return nil
	}

	if resp.StatusCode >= 400 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("Docker API returned error %s: %s", resp.Status, string(body))
	}

	log.Printf("✅ [Relay/MCP] Gateway container '%s' restart command sent successfully via proxy", gatewayContainer)
	return nil
}

// notifyPoco sends a system message to Poco via the relay about MCP server status changes
func (r *RelayService) notifyPoco(serverName string, status string) {
	log.Printf("📢 [Relay/MCP] Notifying Poco about MCP server '%s' status: %s", serverName, status)

	// Find the chat associated with the main agent (Poco)
	// We look for a chat where ai_engine_session_id matches the main agent pattern
	// For now, we'll send to all active chats with the main agent
	chats, err := r.app.FindRecordsByFilter(
		"chats",
		"ai_engine_session_id != '' && turn = 'assistant'",
		"-last_active",
		10, 0,
	)
	if err != nil {
		log.Printf("⚠️ [Relay/MCP] Failed to find chats for notification: %v", err)
		return
	}

	// Build the notification message
	var message string
	switch status {
	case "approved":
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' is now available. Subagents can connect to the gateway at http://mcp-gateway:8811/sse.", serverName)
	case "revoked":
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' has been revoked and is no longer available to subagents.", serverName)
	case "denied":
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' request was denied by the user.", serverName)
	default:
		message = fmt.Sprintf("[SYSTEM] MCP server '%s' status updated to '%s'.", serverName, status)
	}

	// Send notification to each active chat
	for _, chat := range chats {
		chatID := chat.Id
		sessionID := chat.GetString("ai_engine_session_id")

		if sessionID == "" {
			continue
		}

		// Send via prompt_async to avoid blocking
		url := fmt.Sprintf("%s/session/%s/prompt_async", r.openCodeURL, sessionID)

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
			log.Printf("⚠️ [Relay/MCP] Failed to notify Poco for chat %s: %v", chatID, err)
			continue
		}
		resp.Body.Close()

		log.Printf("✅ [Relay/MCP] Notification sent to Poco for chat %s", chatID)
	}
}