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

// Package mcpserver contains the MCP server request use case.
package mcpserver

import (
	"context"
	"fmt"
	"strings"

	"github.com/google/go-containerregistry/pkg/crane"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
)

type ImageResolver func(context.Context, string, string) (string, error)

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

func normalizeImageRef(name, image string) string {
	if image == "" {
		image = fmt.Sprintf("mcp/%s", name)
	}
	if !strings.Contains(image, "@sha256:") && !strings.Contains(image, ":") {
		image += ":latest"
	}
	return image
}

func ResolveImageDigest(ctx context.Context, name, image string) (string, error) {
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

type RequestServerErrorKind int

const (
	ErrKindInternal RequestServerErrorKind = iota
	ErrKindInvalidRequest
	ErrKindImageResolution
	ErrKindSaveSync
	ErrKindSaveCreate
)

type RequestServerError struct {
	Kind RequestServerErrorKind
	Err  error
}

func (e *RequestServerError) Error() string { return e.Err.Error() }
func (e *RequestServerError) Unwrap() error { return e.Err }
func requestServerError(kind RequestServerErrorKind, format string, args ...any) error {
	return &RequestServerError{Kind: kind, Err: fmt.Errorf(format, args...)}
}

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
