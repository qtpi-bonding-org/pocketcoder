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
	"errors"
	"net/http"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/mcpserver"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type McpDeps struct{ ResolveImage mcpserver.ImageResolver }

func AddMcpOperations(app core.App, registry *operation.Registry, deps McpDeps) {
	resolveImage := deps.ResolveImage
	if resolveImage == nil {
		resolveImage = mcpserver.ResolveImageDigest
	}
	registry.Add(operation.Route{OperationID: "executeMcpRequest", Method: http.MethodPost, Path: "/api/pocketcoder/v1/mcp/request", Auth: true, Action: func(re *core.RequestEvent) error {
		if err := requireRole(re, "agent", "admin"); err != nil {
			return err
		}
		var req mcpserver.Request
		if err := re.BindBody(&req); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		if req.ServerName == "" {
			return pocketCoderError(re, 400, "server_name is required")
		}
		result, err := mcpserver.RequestServer(re.Request.Context(), app, resolveImage, req)
		if err != nil {
			var rse *mcpserver.RequestServerError
			if errors.As(err, &rse) {
				switch rse.Kind {
				case mcpserver.ErrKindInvalidRequest:
					return pocketCoderError(re, 400, rse.Error())
				case mcpserver.ErrKindImageResolution:
					return pocketCoderError(re, 422, "Could not resolve image to a digest: "+rse.Error())
				case mcpserver.ErrKindSaveSync:
					return pocketCoderError(re, 500, "Failed to sync record")
				case mcpserver.ErrKindSaveCreate:
					return pocketCoderError(re, 500, "Failed to create record")
				}
			}
			return pocketCoderError(re, 500, "Internal error")
		}
		response := map[string]any{"id": result.ID, "status": result.Status}
		if result.Synced {
			response["synced"] = true
		}
		return re.JSON(200, response)
	}})
}
