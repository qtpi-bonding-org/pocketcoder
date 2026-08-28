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

package filesystem

import (
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem/blob"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"

	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

func mountFileOperations(e *core.ServeEvent) {
	registry := operation.NewRegistry()
	AddFileOperations(registry)
	operation.MountForTests(e, registry.Routes())
}

func withTestWorkspaceRoot(t *testing.T, dir string) {
	t.Helper()
	original := workspaceRoot
	workspaceRoot = dir
	t.Cleanup(func() { workspaceRoot = original })
}

func TestResolveWorkspacePath_RejectsDotDot(t *testing.T) {
	withTestWorkspaceRoot(t, t.TempDir())

	_, ok := resolveWorkspacePath("../etc/passwd")
	if ok {
		t.Fatal("expected ok=false for a .. escape, got ok=true")
	}
}

func TestResolveWorkspacePath_RejectsAbsolute(t *testing.T) {
	withTestWorkspaceRoot(t, t.TempDir())

	_, ok := resolveWorkspacePath("/etc/passwd")
	if ok {
		t.Fatal("expected ok=false for an absolute path, got ok=true")
	}
}

func TestResolveWorkspacePath_AllowsNestedPath(t *testing.T) {
	dir := t.TempDir()
	withTestWorkspaceRoot(t, dir)
	if err := os.Mkdir(filepath.Join(dir, "src"), 0o755); err != nil {
		t.Fatal(err)
	}

	cleanPath, ok := resolveWorkspacePath("src")
	if !ok {
		t.Fatal("expected ok=true for a legitimate nested path")
	}
	if cleanPath != "src" {
		t.Fatalf("cleanPath = %q, want %q", cleanPath, "src")
	}
}

func TestResolveWorkspacePath_AllowsNonExistentPath(t *testing.T) {
	// A path that doesn't exist yet must still pass sanitization so the
	// normal fs.GetReader/List call can return its own NotFound error.
	withTestWorkspaceRoot(t, t.TempDir())

	cleanPath, ok := resolveWorkspacePath("does/not/exist.go")
	if !ok {
		t.Fatal("expected ok=true for a non-existent (but non-escaping) path")
	}
	if cleanPath != "does/not/exist.go" {
		t.Fatalf("cleanPath = %q, want %q", cleanPath, "does/not/exist.go")
	}
}

func TestResolveWorkspacePath_RejectsSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.txt"), []byte("top secret"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "escape")); err != nil {
		t.Fatal(err)
	}
	withTestWorkspaceRoot(t, root)

	_, ok := resolveWorkspacePath("escape/secret.txt")
	if ok {
		t.Fatal("expected ok=false for a path through a symlink that escapes workspaceRoot")
	}
}

func TestResolveWorkspacePath_AllowsSymlinkWithinRoot(t *testing.T) {
	root := t.TempDir()
	if err := os.Mkdir(filepath.Join(root, "real"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(root, "real", "a.go"), []byte("package main"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(root, "real"), filepath.Join(root, "alias")); err != nil {
		t.Fatal(err)
	}
	withTestWorkspaceRoot(t, root)

	_, ok := resolveWorkspacePath("alias/a.go")
	if !ok {
		t.Fatal("expected ok=true for a symlink whose target stays inside workspaceRoot")
	}
}

func TestBuildFileTree_RootPrefix(t *testing.T) {
	mod := time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)
	objects := []*blob.ListObject{
		{Key: "main.go", Size: 1203, ModTime: mod},
		{Key: "internal/filesystem/filesystem.go", Size: 900, ModTime: mod},
		{Key: "internal/filesystem/filesystem_test.go", Size: 500, ModTime: mod},
		{Key: "internal/hooks/mcp.go", Size: 300, ModTime: mod},
		{Key: "go.mod", Size: 50, ModTime: mod},
	}

	got := buildFileTree("", objects)

	if len(got) != 3 {
		t.Fatalf("got %d top-level entries, want 3 (go.mod, internal, main.go); got=%+v", len(got), got)
	}
	if got[0].Name != "go.mod" || got[0].IsDir || got[0].Size != 50 {
		t.Fatalf("entry[0] = %+v, want file go.mod size 50", got[0])
	}
	if got[1].Name != "internal" || !got[1].IsDir {
		t.Fatalf("entry[1] = %+v, want dir internal", got[1])
	}
	if len(got[1].Children) != 2 {
		t.Fatalf("internal.Children = %+v, want 2 (filesystem, hooks)", got[1].Children)
	}
	if got[1].Children[0].Name != "filesystem" || !got[1].Children[0].IsDir {
		t.Fatalf("internal.Children[0] = %+v, want dir filesystem", got[1].Children[0])
	}
	if len(got[1].Children[0].Children) != 2 {
		t.Fatalf("internal/filesystem.Children = %+v, want 2 files", got[1].Children[0].Children)
	}
	if got[1].Children[0].Children[0].Name != "filesystem.go" || got[1].Children[0].Children[0].Size != 900 {
		t.Fatalf("internal/filesystem.Children[0] = %+v, want file filesystem.go size 900", got[1].Children[0].Children[0])
	}
	if got[1].Children[1].Name != "hooks" || !got[1].Children[1].IsDir {
		t.Fatalf("internal.Children[1] = %+v, want dir hooks", got[1].Children[1])
	}
	if got[2].Name != "main.go" || got[2].IsDir || got[2].Size != 1203 {
		t.Fatalf("entry[2] = %+v, want file main.go size 1203", got[2])
	}
}

func TestBuildFileTree_EmptyInput(t *testing.T) {
	got := buildFileTree("", nil)
	if len(got) != 0 {
		t.Fatalf("got %d entries, want 0 for empty input", len(got))
	}
}

func TestBuildFileTree_ConflictResolvesToDirRegardlessOfOrder(t *testing.T) {
	mod := time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)

	fileFirst := []*blob.ListObject{
		{Key: "src", Size: 5, ModTime: mod},
		{Key: "src/a.go", Size: 10, ModTime: mod},
	}
	got := buildFileTree("", fileFirst)
	if len(got) != 1 || got[0].Name != "src" || !got[0].IsDir {
		t.Fatalf("file-first order: got %+v, want single dir entry named src", got)
	}
	if got[0].Size != 0 || len(got[0].Children) != 1 {
		t.Fatalf("file-first order: got %+v, want dir with 1 child, size 0", got[0])
	}

	dirFirst := []*blob.ListObject{
		{Key: "src/a.go", Size: 10, ModTime: mod},
		{Key: "src", Size: 5, ModTime: mod},
	}
	got = buildFileTree("", dirFirst)
	if len(got) != 1 || got[0].Name != "src" || !got[0].IsDir || len(got[0].Children) != 1 {
		t.Fatalf("dir-first order: got %+v, want single dir entry named src with 1 child", got)
	}
}

func TestBuildFileTree_NestedPrefix(t *testing.T) {
	mod := time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)
	objects := []*blob.ListObject{
		{Key: "internal/filesystem/filesystem.go", Size: 900, ModTime: mod},
		{Key: "internal/hooks/mcp.go", Size: 300, ModTime: mod},
	}

	got := buildFileTree("internal/", objects)

	if len(got) != 2 {
		t.Fatalf("got %d entries, want 2 (filesystem, hooks); got=%+v", len(got), got)
	}
	if got[0].Name != "filesystem" || !got[0].IsDir || len(got[0].Children) != 1 {
		t.Fatalf("entry[0] = %+v, want dir filesystem with 1 child", got[0])
	}
	if got[0].Children[0].Name != "filesystem.go" {
		t.Fatalf("entry[0].Children[0] = %+v, want filesystem.go", got[0].Children[0])
	}
}

func newFilesTestUser(t testing.TB, app core.App, email string) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("_pb_users_auth_")
	if err != nil {
		t.Fatal(err)
	}
	u := core.NewRecord(col)
	u.SetEmail(email)
	u.SetPassword("password123")
	if err := app.Save(u); err != nil {
		t.Fatal(err)
	}
	return u
}

func TestFilesTreeEndpoint_RequiresAuth(t *testing.T) {
	withTestWorkspaceRoot(t, t.TempDir())

	scenario := tests.ApiScenario{
		Name:            "files-tree without auth is rejected",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files-tree",
		ExpectedStatus:  401,
		ExpectedContent: []string{"requires valid record authorization token"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
		},
	}
	scenario.Test(t)
}

func TestFilesTreeEndpoint_ReturnsFullNestedTree(t *testing.T) {
	dir := t.TempDir()
	withTestWorkspaceRoot(t, dir)
	if err := os.WriteFile(filepath.Join(dir, "main.go"), []byte("package main"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(dir, "internal"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "internal", "nested.go"), []byte("package internal"), 0o644); err != nil {
		t.Fatal(err)
	}

	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:           "files-tree returns the full recursive tree as JSON",
		Method:         http.MethodGet,
		URL:            "/api/pocketcoder/v1/files-tree",
		Headers:        headers,
		ExpectedStatus: 200,
		ExpectedContent: []string{
			`"name":"main.go"`,
			`"name":"internal"`,
			`"isDir":true`,
			`"name":"nested.go"`,
		},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
			user := newFilesTestUser(t, app, "files-tree@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesTreeEndpoint_RejectsSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.txt"), []byte("top secret"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "escape")); err != nil {
		t.Fatal(err)
	}
	withTestWorkspaceRoot(t, root)

	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files-tree rejects a symlink that escapes the workspace root",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files-tree?path=escape",
		Headers:         headers,
		ExpectedStatus:  403,
		ExpectedContent: []string{"escape attempt"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
			user := newFilesTestUser(t, app, "tree-symlink-escape@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_RequiresAuth(t *testing.T) {
	withTestWorkspaceRoot(t, t.TempDir())

	scenario := tests.ApiScenario{
		Name:            "files read without auth is rejected",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=main.go",
		ExpectedStatus:  401,
		ExpectedContent: []string{"requires valid record authorization token"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_ReturnsFileContent(t *testing.T) {
	dir := t.TempDir()
	withTestWorkspaceRoot(t, dir)
	if err := os.WriteFile(filepath.Join(dir, "hello.txt"), []byte("hello workspace"), 0o644); err != nil {
		t.Fatal(err)
	}

	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read returns the requested file's content",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=hello.txt",
		Headers:         headers,
		ExpectedStatus:  200,
		ExpectedContent: []string{"hello workspace"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
			user := newFilesTestUser(t, app, "files-read@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_SetsContentTypeByExtension(t *testing.T) {
	dir := t.TempDir()
	withTestWorkspaceRoot(t, dir)
	if err := os.WriteFile(filepath.Join(dir, "notes.txt"), []byte("plain text notes"), 0o644); err != nil {
		t.Fatal(err)
	}

	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read sets Content-Type based on the file extension",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=notes.txt",
		Headers:         headers,
		ExpectedStatus:  200,
		ExpectedContent: []string{"plain text notes"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
			user := newFilesTestUser(t, app, "files-read-content-type@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
		AfterTestFunc: func(t testing.TB, _ *tests.TestApp, res *http.Response) {
			if got := res.Header.Get("Content-Type"); got != "text/plain" {
				t.Fatalf("Content-Type = %q, want %q", got, "text/plain")
			}
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_ReturnsNotFoundForMissingFile(t *testing.T) {
	withTestWorkspaceRoot(t, t.TempDir())

	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read 404s for a file that does not exist",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=does-not-exist.txt",
		Headers:         headers,
		ExpectedStatus:  404,
		ExpectedContent: []string{"File not found"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
			user := newFilesTestUser(t, app, "files-read-missing@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_RejectsSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.txt"), []byte("top secret"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "escape")); err != nil {
		t.Fatal(err)
	}
	withTestWorkspaceRoot(t, root)

	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read rejects a symlink that escapes the workspace root",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=escape%2Fsecret.txt",
		Headers:         headers,
		ExpectedStatus:  403,
		ExpectedContent: []string{"escape attempt"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e)
			user := newFilesTestUser(t, app, "read-symlink-escape@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}
