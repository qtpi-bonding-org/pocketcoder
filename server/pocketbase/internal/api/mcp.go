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
	"github.com/pocketbase/pocketbase/apis"
	"log"
	"net/http"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/mcpserver"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

type McpDeps struct{ ResolveImage mcpserver.ImageResolver }

func ExecuteMcpRequest(app core.App, resolveImage mcpserver.ImageResolver, re *core.RequestEvent) (mcpserver.Result, error) {
	if err := requireRole(re, "agent", "admin"); err != nil {
		return mcpserver.Result{}, err
	}
	var req mcpserver.Request
	if err := re.BindBody(&req); err != nil {
		return mcpserver.Result{}, re.BadRequestError("Invalid request body", nil)
	}
	if req.ServerName == "" {
		return mcpserver.Result{}, re.BadRequestError("server_name is required", nil)
	}
	result, err := mcpserver.RequestServer(re.Request.Context(), app, resolveImage, req)
	if err != nil {
		log.Printf("[MCP] request server failed: %v", err)
		var rse *mcpserver.RequestServerError
		if errors.As(err, &rse) {
			switch rse.Kind {
			case mcpserver.ErrKindInvalidRequest:
				return mcpserver.Result{}, re.BadRequestError(rse.Error(), nil)
			case mcpserver.ErrKindImageResolution:
				return mcpserver.Result{}, apis.NewApiError(422, "Could not resolve image to a digest: "+rse.Error(), nil)
			case mcpserver.ErrKindSaveSync, mcpserver.ErrKindSaveCreate:
				return mcpserver.Result{}, re.InternalServerError("Failed to save record", nil)
			}
		}
		return mcpserver.Result{}, re.InternalServerError("Internal error", nil)
	}
	return result, nil
}

func AddMcpOperations(app core.App, registry *operation.Registry, deps McpDeps) {
	resolveImage := deps.ResolveImage
	if resolveImage == nil {
		resolveImage = mcpserver.ResolveImageDigest
	}
	registry.Add(operation.Route{OperationID: "executeMcpRequest", Method: http.MethodPost, Path: "/api/pocketcoder/v1/mcp/request", Auth: true, Action: func(re *core.RequestEvent) error {
		result, err := ExecuteMcpRequest(app, resolveImage, re)
		if err != nil {
			return err
		}
		response := map[string]any{"id": result.ID, "status": result.Status}
		if result.Synced {
			response["synced"] = true
		}
		return re.JSON(200, response)
	}})
}
