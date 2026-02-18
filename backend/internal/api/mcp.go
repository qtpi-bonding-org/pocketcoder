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
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// RegisterMcpApi registers the MCP server request endpoint.
func RegisterMcpApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.POST("/api/pocketcoder/mcp_request", func(re *core.RequestEvent) error {
		// 1. Require authentication
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}

		// 2. Check role: agent or admin only
		role := re.Auth.GetString("role")
		if role != "agent" && role != "admin" {
			return re.JSON(403, map[string]string{"error": "Insufficient permissions"})
		}

		// 3. Parse request body
		var input struct {
			ServerName string `json:"server_name"`
			Reason     string `json:"reason"`
			SessionID  string `json:"session_id"`
		}

		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}

		// Validate required fields
		if input.ServerName == "" {
			return re.JSON(400, map[string]string{"error": "server_name is required"})
		}

		// 4. Check for existing approved record with the same name
		mcpServers, err := app.FindCollectionByNameOrId("mcp_servers")
		if err != nil {
			log.Printf("❌ Failed to find mcp_servers collection: %v", err)
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}

		// Query for existing approved record with the same name
		existingRecords, err := app.FindRecordsByFilter(
			"mcp_servers",
			"name = {:name} && status = 'approved'",
			"",
			1,
			0,
			map[string]any{"name": input.ServerName},
		)
		if err != nil {
			log.Printf("❌ Failed to query existing MCP servers: %v", err)
			return re.JSON(500, map[string]string{"error": "Internal error"})
		}

		// If an approved record exists, return it
		if len(existingRecords) > 0 {
			existing := existingRecords[0]
			return re.JSON(200, map[string]any{
				"id":     existing.Id,
				"status": existing.GetString("status"),
			})
		}

		// 5. Create new mcp_servers record with status "pending"
		record := core.NewRecord(mcpServers)
		record.Set("name", input.ServerName)
		record.Set("status", "pending")
		record.Set("reason", input.Reason)
		record.Set("requested_by", input.SessionID)
		record.Set("catalog", "docker-mcp") // Default catalog

		if err := app.Save(record); err != nil {
			log.Printf("❌ Failed to create MCP server record: %v", err)
			return re.JSON(500, map[string]string{"error": "Failed to create record"})
		}

		// 6. Return record ID and status
		return re.JSON(200, map[string]any{
			"id":     record.Id,
			"status": "pending",
		})
	}).Bind(apis.RequireAuth())
}