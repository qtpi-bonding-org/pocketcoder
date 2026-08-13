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

// @pocketcoder-core: Files API. Secure endpoint for accessing workspace files.
package filesystem

import (
	"io"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
	"github.com/pocketbase/pocketbase/tools/filesystem/blob"
)

// fileEntry is one immediate child of a listed directory.
type fileEntry struct {
	Name    string `json:"name"`
	IsDir   bool   `json:"isDir"`
	Size    int64  `json:"size"`
	ModTime string `json:"modTime"`
}

// workspaceRoot is the directory the file endpoints serve. It's a package
// variable (not a const) so tests can point it at a temp directory.
var workspaceRoot = "/workspace"

// resolveWorkspacePath cleans pathParam and rejects any path that would
// resolve — after following symlinks — outside workspaceRoot. It returns
// the cleaned path (relative to workspaceRoot, safe to hand to
// fsys.GetReader/List) and ok=false if the path should be rejected.
//
// A target that doesn't exist yet (or is a broken symlink) is allowed
// through: sanitization has already passed, so the normal
// fs.GetReader/List call is left to report its own NotFound error.
func resolveWorkspacePath(pathParam string) (cleanPath string, ok bool) {
	cleanPath = filepath.Clean(pathParam)
	if strings.HasPrefix(cleanPath, "..") || strings.HasPrefix(cleanPath, "/") {
		return "", false
	}

	resolvedRoot, err := filepath.EvalSymlinks(workspaceRoot)
	if err != nil {
		return "", false
	}

	target := filepath.Join(workspaceRoot, cleanPath)
	resolvedTarget, err := filepath.EvalSymlinks(target)
	if err != nil {
		return cleanPath, true
	}
	if resolvedTarget != resolvedRoot && !strings.HasPrefix(resolvedTarget, resolvedRoot+string(filepath.Separator)) {
		return "", false
	}
	return cleanPath, true
}

// groupImmediateChildren collapses a flat, recursive listing (as returned by
// filesystem.System.List, which never sets blob.ListOptions.Delimiter and so
// never populates ListObject.IsDir) into immediate-children-only entries
// relative to prefix. Deeper descendants of a subdirectory are deduped into
// a single directory entry.
func groupImmediateChildren(prefix string, objects []*blob.ListObject) []fileEntry {
	seen := map[string]fileEntry{}
	order := []string{}
	for _, obj := range objects {
		rel := strings.TrimPrefix(obj.Key, prefix)
		if rel == "" {
			continue
		}
		parts := strings.SplitN(rel, "/", 2)
		name := parts[0]
		isDir := len(parts) > 1

		if existing, exists := seen[name]; exists {
			if isDir && !existing.IsDir {
				existing.IsDir = true
				existing.Size = 0
				existing.ModTime = ""
				seen[name] = existing
			}
			continue
		}

		entry := fileEntry{Name: name, IsDir: isDir}
		if !isDir {
			entry.Size = obj.Size
			entry.ModTime = obj.ModTime.Format(time.RFC3339)
		}
		seen[name] = entry
		order = append(order, name)
	}
	sort.Strings(order)
	result := make([]fileEntry, 0, len(order))
	for _, name := range order {
		result = append(result, seen[name])
	}
	return result
}

// RegisterFilesApi provides a secure window into the /workspace using the PB Filesystem abstraction.
func RegisterFilesApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.GET("/api/pocketcoder/files", func(re *core.RequestEvent) error {
		// 1. Auth Gate
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}

		// 2. Resolve Path
		pathParam := re.Request.URL.Query().Get("path")
		if pathParam == "" {
			return re.BadRequestError("Empty path.", nil)
		}

		cleanPath, ok := resolveWorkspacePath(pathParam)
		if !ok {
			return re.ForbiddenError("Path escape attempt detected.", nil)
		}

		// 3. Initialize Filesystem Abstraction (S3-Ready)
		// For now we point it at the local workspaceRoot volume
		fsys, err := filesystem.NewLocal(workspaceRoot)
		if err != nil {
			return re.InternalServerError("Sovereign storage failure.", err)
		}
		defer fsys.Close()

		// 4. Stream File
		r, err := fsys.GetReader(cleanPath)
		if err != nil {
			return re.NotFoundError("File not found.", err)
		}
		defer r.Close()

		// Sniff Content Type if possible, or default to octet-stream
		// Actually, http.ServeContent or similar might be better, but GetReader logic is manual
		// We'll set a default and let the client handle it for now, or use a basic extension check.
		re.Response.Header().Set("Content-Type", "application/octet-stream")
		if strings.HasSuffix(cleanPath, ".html") {
			re.Response.Header().Set("Content-Type", "text/html")
		}
		if strings.HasSuffix(cleanPath, ".png") {
			re.Response.Header().Set("Content-Type", "image/png")
		}
		if strings.HasSuffix(cleanPath, ".txt") {
			re.Response.Header().Set("Content-Type", "text/plain")
		}

		_, err = io.Copy(re.Response, r)
		return err
	}).Bind(apis.RequireAuth())

	e.Router.GET("/api/pocketcoder/files-list", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}

		pathParam := re.Request.URL.Query().Get("path")
		cleanPath, ok := resolveWorkspacePath(pathParam)
		if !ok {
			return re.ForbiddenError("Path escape attempt detected.", nil)
		}

		fsys, err := filesystem.NewLocal(workspaceRoot)
		if err != nil {
			return re.InternalServerError("Sovereign storage failure.", err)
		}
		defer fsys.Close()

		prefix := cleanPath
		if prefix == "." {
			prefix = ""
		} else {
			prefix += "/"
		}

		objects, err := fsys.List(prefix)
		if err != nil {
			return re.NotFoundError("Directory not found.", err)
		}

		entries := groupImmediateChildren(prefix, objects)

		return re.JSON(200, map[string]any{
			"path":    cleanPath,
			"entries": entries,
		})
	}).Bind(apis.RequireAuth())
}
