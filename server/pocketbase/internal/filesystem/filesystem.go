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
	"archive/tar"
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"path"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
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

var workspaceRoot = "/workspace"

// resolveWorkspacePath cleans pathParam and rejects any path that would
// escape workspaceRoot syntactically. Symlink escapes are the target
// container's own concern -- Docker's archive API resolves them against
// that container's real filesystem, not anything local to this process.
//
// A target that doesn't exist yet (or is a broken symlink) is allowed
// through: sanitization has already passed, so the archive fetch is left to
// report its own NotFound error.
func resolveWorkspacePath(pathParam string) (cleanPath string, ok bool) {
	cleanPath = filepath.Clean(pathParam)
	if strings.HasPrefix(cleanPath, "..") || strings.HasPrefix(cleanPath, "/") {
		return "", false
	}
	return cleanPath, true
}

// containerArchiveReader abstracts Docker's archive-read API so tests can
// fake a container's filesystem without a real Docker daemon.
type containerArchiveReader interface {
	GetArchive(ctx context.Context, containerName, path string) (io.ReadCloser, error)
}

type dockerArchiveReader struct{ client *dockerapi.Client }

func (d dockerArchiveReader) GetArchive(ctx context.Context, containerName, path string) (io.ReadCloser, error) {
	return d.client.GetArchive(ctx, containerName, path)
}

// Any of the user's running instances works: they share one workspace volume.
func resolveUserContainer(app core.App, userID string) (string, error) {
	instances, err := app.FindRecordsByFilter(
		"harness_instances", "user = {:user} && status = 'running'", "-updated", 1, 0,
		map[string]any{"user": userID},
	)
	if err != nil {
		return "", fmt.Errorf("find running harness instance: %w", err)
	}
	if len(instances) == 0 {
		return "", fmt.Errorf("no running harness instance for this user")
	}
	containerName := instances[0].GetString("container_name")
	if containerName == "" {
		return "", fmt.Errorf("running harness instance has no container name")
	}
	return containerName, nil
}

// order lets the final sort be deterministic regardless of the tar's own
// entry order.
type fileTreeNode struct {
	entry    FileTreeEntry
	children map[string]*fileTreeNode
	order    []string
}

func newFileTreeNode(name string) *fileTreeNode {
	return &fileTreeNode{entry: FileTreeEntry{Name: name}, children: map[string]*fileTreeNode{}}
}

// rootName is the requested directory's own base name -- Docker's archive
// API names every entry in the stream relative to it (e.g. requesting
// "/workspace/src" yields "src/main.go"), so it must be stripped here.
func buildFileTreeFromTar(r io.Reader, rootName string) ([]FileTreeEntry, error) {
	tr := tar.NewReader(r)
	root := newFileTreeNode("")
	rootPrefix := rootName + "/"
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, fmt.Errorf("read tar stream: %w", err)
		}
		name := strings.TrimSuffix(hdr.Name, "/")
		if name == rootName || name == "" {
			continue // the requested directory's own entry
		}
		rel := strings.TrimPrefix(name, rootPrefix)
		if rel == "" || rel == name {
			continue // outside rootPrefix -- shouldn't happen, skip defensively
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
			if hdr.Typeflag == tar.TypeDir || !isLast {
				child.entry.IsDir = true
			} else {
				child.entry.Size = hdr.Size
				child.entry.ModTime = hdr.ModTime.Format(time.RFC3339)
			}
			node = child
		}
	}
	return flattenFileTree(root), nil
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

func readFileFromContainer(archive io.Reader) ([]byte, error) {
	tr := tar.NewReader(archive)
	hdr, err := tr.Next()
	if err != nil {
		return nil, fmt.Errorf("read tar stream: %w", err)
	}
	if hdr.Typeflag == tar.TypeDir {
		return nil, fmt.Errorf("path is a directory")
	}
	return io.ReadAll(tr)
}

// FileDeps wires the workspace file endpoints to the requesting user's own
// running harness container -- each user has their own derived workspace
// volume, so there is no single local mount pocketbase itself can read.
type FileDeps struct {
	App    core.App
	Reader containerArchiveReader // nil -> real Docker archive API
}

func listWorkspaceFileTree(ctx context.Context, reader containerArchiveReader, app core.App, userID, pathParam string) (cleanPath string, entries []FileTreeEntry, err error) {
	cleanPath, ok := resolveWorkspacePath(pathParam)
	if !ok {
		return "", nil, errPathEscape
	}
	containerName, err := resolveUserContainer(app, userID)
	if err != nil {
		return "", nil, fmt.Errorf("%w: %v", errWorkspaceUnavailable, err)
	}
	containerPath := path.Join(workspaceRoot, cleanPath)
	archive, err := reader.GetArchive(ctx, containerName, containerPath)
	if err != nil {
		return "", nil, fmt.Errorf("%w: %v", errNotFound, err)
	}
	defer archive.Close()
	entries, err = buildFileTreeFromTar(archive, filepath.Base(containerPath))
	if err != nil {
		return "", nil, err
	}
	return cleanPath, entries, nil
}

var (
	errPathEscape           = errors.New("path escape attempt detected")
	errWorkspaceUnavailable = errors.New("workspace not available")
	errNotFound             = errors.New("not found")
)

// Always uses the real Docker archive API -- the strict-server dispatch
// path (operationapi/server.go) that calls this has no test-injected reader.
func ListWorkspaceFileTree(re *core.RequestEvent) (string, []FileTreeEntry, error) {
	if re.Auth == nil {
		return "", nil, re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
	}
	cleanPath, entries, err := listWorkspaceFileTree(
		re.Request.Context(), dockerArchiveReader{client: dockerapi.New()}, re.App, re.Auth.Id,
		re.Request.URL.Query().Get("path"),
	)
	if err != nil {
		return "", nil, fileTreeErrorResponse(re, err)
	}
	return cleanPath, entries, nil
}

func fileTreeErrorResponse(re *core.RequestEvent, err error) error {
	switch {
	case errors.Is(err, errPathEscape):
		return re.ForbiddenError("Path escape attempt detected.", nil)
	case errors.Is(err, errWorkspaceUnavailable):
		return re.NotFoundError("Workspace not available.", err)
	case errors.Is(err, errNotFound):
		return re.NotFoundError("Directory not found.", err)
	default:
		return re.InternalServerError("Sovereign storage failure.", err)
	}
}

func AddFileOperations(registry *operation.Registry, deps FileDeps) {
	reader := deps.Reader
	if reader == nil {
		reader = dockerArchiveReader{client: dockerapi.New()}
	}
	app := deps.App

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

		containerName, err := resolveUserContainer(app, re.Auth.Id)
		if err != nil {
			return re.NotFoundError("Workspace not available.", err)
		}

		archive, err := reader.GetArchive(re.Request.Context(), containerName, path.Join(workspaceRoot, cleanPath))
		if err != nil {
			return re.NotFoundError("File not found.", err)
		}
		defer archive.Close()
		data, err := readFileFromContainer(archive)
		if err != nil {
			return re.NotFoundError("File not found.", err)
		}

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

		_, err = re.Response.Write(data)
		return err
	}})

	registry.Add(operation.Route{OperationID: "listWorkspaceFileTree", Method: http.MethodGet, Path: "/api/pocketcoder/v1/files-tree", Auth: true, Action: func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}
		cleanPath, entries, err := listWorkspaceFileTree(
			re.Request.Context(), reader, app, re.Auth.Id, re.Request.URL.Query().Get("path"),
		)
		if err != nil {
			return fileTreeErrorResponse(re, err)
		}
		return re.JSON(200, map[string]any{
			"path":    cleanPath,
			"entries": entries,
		})
	}})
}
