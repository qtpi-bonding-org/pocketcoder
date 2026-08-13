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

// @pocketcoder-core: MCP API. Handler for MCP server requests from Poco.
package api

import (
	"fmt"
	"log"
	"strings"

	"github.com/google/go-containerregistry/pkg/crane"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// resolveImageDigest pins a proposed image reference to a sha256 digest at
// request time, before a human ever sees/approves it -- so approval means
// "I reviewed this exact digest," not "I reviewed a tag that could point
// somewhere else by the time renderMcpConfig (hooks/mcp.go) renders it."
// docker-mcp v0.43+ also requires this: --verify-signatures (on by default)
// rejects mutable tags outright, so an unresolved tag would fail at the
// gateway regardless -- better to fail loudly here, before approval, than
// let a request quietly reach a state the gateway will refuse to run.
//
// Mirrors hooks/mcp.go's renderMcpConfig defaulting (empty image ->
// mcp/<name>, no tag/digest -> :latest) so a request's resolved image
// matches what would previously have been rendered.
func resolveImageDigest(name, image string) (string, error) {
	if image == "" {
		image = fmt.Sprintf("mcp/%s", name)
	}
	if strings.Contains(image, "@sha256:") {
		return image, nil // already pinned
	}
	if !strings.Contains(image, ":") {
		image = image + ":latest"
	}

	digest, err := crane.Digest(image)
	if err != nil {
		return "", fmt.Errorf("resolve digest for %s: %w", image, err)
	}

	repo := image
	if i := strings.LastIndex(image, ":"); i != -1 {
		repo = image[:i]
	}
	return repo + "@" + digest, nil
}

// RegisterMcpApi registers the MCP server request endpoint.
func RegisterMcpApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.POST("/api/pocketcoder/mcp/request", func(re *core.RequestEvent) error {
		// 1. Require authentication
		if re.Auth == nil {
			return pocketCoderError(re, 401, "Authentication required")
		}

		// 2. Check role: agent or admin only
		role := re.Auth.GetString("role")
		if role != "agent" && role != "admin" {
			return pocketCoderError(re, 403, "Insufficient permissions")
		}

		// 3. Parse request body
		var input struct {
			ServerName   string         `json:"server_name"`
			Reason       string         `json:"reason"`
			SessionID    string         `json:"session_id"`
			Image        string         `json:"image"`
			ConfigSchema map[string]any `json:"config_schema"`
		}

		if err := re.BindBody(&input); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}

		// Validate required fields
		if input.ServerName == "" {
			return pocketCoderError(re, 400, "server_name is required")
		}

		// 4. Check for existing approved record with the same name
		mcpServers, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil {
			log.Printf("❌ [MCP] Failed to find mcp_servers collection: %v", err)
			return pocketCoderError(re, 500, "Internal error")
		}

		// Query for existing record with the same name that is active or pending
		// We avoid duplicates of both approved and pending servers.
		existingRecords, err := app.FindRecordsByFilter(
			"mcp_servers",
			"name = {:name} && status != 'denied' && status != 'revoked'",
			"",
			1,
			0,
			map[string]any{"name": input.ServerName},
		)
		if err != nil {
			log.Printf("❌ [MCP] Failed to query existing MCP servers: %v", err)
			return pocketCoderError(re, 500, "Internal error")
		}

		resolvedImage, err := resolveImageDigest(input.ServerName, input.Image)
		if err != nil {
			log.Printf("❌ [MCP] Failed to resolve image digest for %s: %v", input.ServerName, err)
			return pocketCoderError(re, 422, "Could not resolve image to a digest: "+err.Error())
		}

		// If a record exists (either approved or pending), sync the latest researched metadata
		if len(existingRecords) > 0 {
			existing := existingRecords[0]

			// Always update these fields to ensure we have the latest research data
			// (Reason, Image, ConfigSchema, etc.)
			existing.Set("reason", input.Reason)
			existing.Set("image", resolvedImage)
			existing.Set("config_schema", input.ConfigSchema)
			existing.Set("requested_by", input.SessionID)

			if err := app.Save(existing); err != nil {
				log.Printf("❌ [MCP] Failed to update existing MCP server record: %v", err)
			}

			return re.JSON(200, map[string]any{
				"id":     existing.Id,
				"status": existing.GetString("status"),
				"synced": true,
			})
		}

		// 5. Create new mcp_servers record with status "pending"
		record := core.NewRecord(mcpServers)
		record.Set("name", input.ServerName)
		record.Set("status", "pending")
		record.Set("reason", input.Reason)
		record.Set("requested_by", input.SessionID)
		record.Set("catalog", "docker-mcp") // Default catalog
		record.Set("image", resolvedImage)
		record.Set("config_schema", input.ConfigSchema)

		if err := app.Save(record); err != nil {
			log.Printf("❌ [MCP] Failed to create MCP server record: %v", err)
			return pocketCoderError(re, 500, "Failed to create record")
		}

		// 6. Return record ID and status
		return re.JSON(200, map[string]any{
			"id":     record.Id,
			"status": "pending",
		})
	}).Bind(apis.RequireAuth())
}
