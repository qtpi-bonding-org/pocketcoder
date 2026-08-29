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
	"net/http"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
	"github.com/pocketbase/pocketbase/tools/filesystem/blob"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"
)

// FileTreeEntry is one node of a full recursive directory tree. Size/ModTime
// are only meaningful for files; Children is only populated for directories.
type FileTreeEntry struct {
	Name     string          `json:"name"`
	IsDir    bool            `json:"isDir"`
	Size     int64           `json:"size,omitempty"`
	ModTime  string          `json:"modTime,omitempty"`
	Children []FileTreeEntry `json:"children,omitempty"`
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

// listObjectsForPath resolves the request's ?path= query param against
// workspaceRoot (rejecting any escape attempt) and returns the full flat,
// recursive object listing under it, for ListWorkspaceFileTree to nest into
// a full tree.
func listObjectsForPath(re *core.RequestEvent) (cleanPath, prefix string, objects []*blob.ListObject, err error) {
	if re.Auth == nil {
		return "", "", nil, re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
	}
	pathParam := re.Request.URL.Query().Get("path")
	cleanPath, ok := resolveWorkspacePath(pathParam)
	if !ok {
		return "", "", nil, re.ForbiddenError("Path escape attempt detected.", nil)
	}
	fsys, ferr := filesystem.NewLocal(workspaceRoot)
	if ferr != nil {
		return "", "", nil, re.InternalServerError("Sovereign storage failure.", ferr)
	}
	defer fsys.Close()
	prefix = cleanPath
	if prefix == "." {
		prefix = ""
	} else {
		prefix += "/"
	}
	objects, lerr := fsys.List(prefix)
	if lerr != nil {
		return "", "", nil, re.NotFoundError("Directory not found.", lerr)
	}
	return cleanPath, prefix, objects, nil
}

func ListWorkspaceFileTree(re *core.RequestEvent) (string, []FileTreeEntry, error) {
	cleanPath, prefix, objects, err := listObjectsForPath(re)
	if err != nil {
		return "", nil, err
	}
	return cleanPath, buildFileTree(prefix, objects), nil
}

// fileTreeNode is buildFileTree's scratch structure -- a directory's children
// keyed by name, plus insertion order so the final sort is deterministic
// regardless of how the flat object list from fsys.List was ordered.
type fileTreeNode struct {
	entry    FileTreeEntry
	children map[string]*fileTreeNode
	order    []string
}

func newFileTreeNode(name string) *fileTreeNode {
	return &fileTreeNode{entry: FileTreeEntry{Name: name}, children: map[string]*fileTreeNode{}}
}

// buildFileTree nests a flat, recursive listing (as returned by
// filesystem.System.List) into a full directory tree relative to prefix.
// Mirrors groupImmediateChildren's conflict resolution: a path that appears
// both as its own object key and as an ancestor of deeper keys (e.g. "src"
// and "src/a.go" both present) always resolves to a directory, regardless of
// which one was seen first.
func buildFileTree(prefix string, objects []*blob.ListObject) []FileTreeEntry {
	root := newFileTreeNode("")
	for _, obj := range objects {
		rel := strings.TrimPrefix(obj.Key, prefix)
		if rel == "" {
			continue
		}
		parts := strings.Split(rel, "/")
		node := root
		for i, part := range parts {
			child, exists := node.children[part]
			if !exists {
				child = newFileTreeNode(part)
				node.children[part] = child
				node.order = append(node.order, part)
			}
			isLast := i == len(parts)-1
			if isLast {
				if !child.entry.IsDir {
					child.entry.Size = obj.Size
					child.entry.ModTime = obj.ModTime.Format(time.RFC3339)
				}
			} else {
				child.entry.IsDir = true
				child.entry.Size = 0
				child.entry.ModTime = ""
			}
			node = child
		}
	}
	return flattenFileTree(root)
}

func flattenFileTree(node *fileTreeNode) []FileTreeEntry {
	sort.Strings(node.order)
	result := make([]FileTreeEntry, 0, len(node.order))
	for _, name := range node.order {
		child := node.children[name]
		entry := child.entry
		if entry.IsDir {
			entry.Children = flattenFileTree(child)
		}
		result = append(result, entry)
	}
	return result
}

func AddFileOperations(registry *operation.Registry) {
	registry.Add(operation.Route{OperationID: "getWorkspaceFile", Method: http.MethodGet, Path: "/api/pocketcoder/v1/files", Auth: true, Direct: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}

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
	}})

	registry.Add(operation.Route{OperationID: "listWorkspaceFileTree", Method: http.MethodGet, Path: "/api/pocketcoder/v1/files-tree", Auth: true, Action: func(re *core.RequestEvent) error {
		cleanPath, entries, err := ListWorkspaceFileTree(re)
		if err != nil {
			return err
		}

		return re.JSON(200, map[string]any{
			"path":    cleanPath,
			"entries": entries,
		})
	}})
}
