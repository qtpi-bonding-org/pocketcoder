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
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/google/go-containerregistry/pkg/crane"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

// ImageResolver resolves an MCP server image to an immutable digest.
type ImageResolver func(context.Context, string, string) (string, error)

// Store is the persistence surface required by RequestServer.
type Store interface {
	FindCollectionByNameOrId(nameOrId string) (*core.Collection, error)
	FindRecordsByFilter(collectionModelOrIdentifier any, filter, sort string, limit, offset int, params ...dbx.Params) ([]*core.Record, error)
	Save(core.Model) error
}

type Request struct {
	ServerName   string         `json:"server_name"`
	Reason       string         `json:"reason"`
	SessionID    string         `json:"session_id"`
	Image        string         `json:"image"`
	ConfigSchema map[string]any `json:"config_schema"`
}

type Result struct {
	ID     string
	Status string
	Synced bool
}

type McpDeps struct {
	ResolveImage ImageResolver
}

// normalizeImageRef applies the MCP image defaults without contacting a registry.
func normalizeImageRef(name, image string) string {
	if image == "" {
		image = fmt.Sprintf("mcp/%s", name)
	}
	if !strings.Contains(image, "@sha256:") && !strings.Contains(image, ":") {
		image += ":latest"
	}
	return image
}

func resolveImageDigest(name, image string) (string, error) {
	image = normalizeImageRef(name, image)
	if strings.Contains(image, "@sha256:") {
		return image, nil
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

// RequestServerErrorKind categorizes a RequestServer failure so callers (the
// HTTP handler) can map it to a status code without pattern-matching error
// text.
type RequestServerErrorKind int

const (
	// ErrKindInternal covers store lookups unrelated to caller input.
	ErrKindInternal RequestServerErrorKind = iota
	// ErrKindInvalidRequest covers bad caller input, e.g. a missing server_name.
	ErrKindInvalidRequest
	// ErrKindImageResolution covers a failed ImageResolver call.
	ErrKindImageResolution
	// ErrKindSaveSync covers a failed Store.Save on the sync-existing-record path.
	ErrKindSaveSync
	// ErrKindSaveCreate covers a failed Store.Save on the create-new-record path.
	ErrKindSaveCreate
)

// RequestServerError wraps a RequestServer failure with its kind.
type RequestServerError struct {
	Kind RequestServerErrorKind
	Err  error
}

func (e *RequestServerError) Error() string { return e.Err.Error() }
func (e *RequestServerError) Unwrap() error { return e.Err }

func requestServerError(kind RequestServerErrorKind, format string, args ...any) error {
	return &RequestServerError{Kind: kind, Err: fmt.Errorf(format, args...)}
}

// RequestServer records a new MCP request or synchronizes the existing request
// with the same active name. It deliberately delegates image defaulting to the
// supplied resolver, so callers can provide resolvers with different policies.
func RequestServer(ctx context.Context, store Store, resolve ImageResolver, req Request) (Result, error) {
	if req.ServerName == "" {
		return Result{}, requestServerError(ErrKindInvalidRequest, "server_name is required")
	}
	collection, err := store.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		return Result{}, requestServerError(ErrKindInternal, "find mcp_servers collection: %w", err)
	}
	existing, err := store.FindRecordsByFilter("mcp_servers", "name = {:name} && status != 'denied' && status != 'revoked'", "", 1, 0, map[string]any{"name": req.ServerName})
	if err != nil {
		return Result{}, requestServerError(ErrKindInternal, "find existing MCP servers: %w", err)
	}
	resolved, err := resolve(ctx, req.ServerName, req.Image)
	if err != nil {
		return Result{}, requestServerError(ErrKindImageResolution, "resolve image digest: %w", err)
	}
	if len(existing) > 0 {
		record := existing[0]
		record.Set("reason", req.Reason)
		record.Set("image", resolved)
		record.Set("config_schema", req.ConfigSchema)
		record.Set("requested_by", req.SessionID)
		if err := store.Save(record); err != nil {
			return Result{}, requestServerError(ErrKindSaveSync, "sync MCP server record: %w", err)
		}
		return Result{ID: record.Id, Status: record.GetString("status"), Synced: true}, nil
	}
	record := core.NewRecord(collection)
	record.Set("name", req.ServerName)
	record.Set("status", "pending")
	record.Set("reason", req.Reason)
	record.Set("requested_by", req.SessionID)
	record.Set("catalog", "docker-mcp")
	record.Set("image", resolved)
	record.Set("config_schema", req.ConfigSchema)
	if err := store.Save(record); err != nil {
		return Result{}, requestServerError(ErrKindSaveCreate, "create MCP server record: %w", err)
	}
	return Result{ID: record.Id, Status: "pending"}, nil
}

func AddMcpOperations(app core.App, registry *operation.Registry, deps McpDeps) {
	resolveImage := deps.ResolveImage
	if resolveImage == nil {
		resolveImage = func(ctx context.Context, name, image string) (string, error) { return resolveImageDigest(name, image) }
	}
	registry.Add(operation.Route{OperationID: "executeMcpRequest", Method: http.MethodPost, Path: "/api/pocketcoder/v1/mcp/request", Auth: true, Action: func(re *core.RequestEvent) error {
		if err := requireRole(re, "agent", "admin"); err != nil {
			return err
		}
		var req Request
		if err := re.BindBody(&req); err != nil {
			return pocketCoderError(re, 400, "Invalid request body")
		}
		if req.ServerName == "" {
			return pocketCoderError(re, 400, "server_name is required")
		}
		result, err := RequestServer(re.Request.Context(), app, resolveImage, req)
		if err != nil {
			var rse *RequestServerError
			if errors.As(err, &rse) {
				switch rse.Kind {
				case ErrKindInvalidRequest:
					return pocketCoderError(re, 400, rse.Error())
				case ErrKindImageResolution:
					return pocketCoderError(re, 422, "Could not resolve image to a digest: "+rse.Error())
				case ErrKindSaveSync:
					return pocketCoderError(re, 500, "Failed to sync record")
				case ErrKindSaveCreate:
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
