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
	"archive/tar"
	"bytes"
	"context"
	"io"
	"net/http"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/dockerapi"
	"github.com/qtpi-bonding-org/pocketcoder/backend/internal/operation"

	_ "github.com/qtpi-bonding-org/pocketcoder/backend/pb_migrations"
)

type fakeFile struct {
	isDir   bool
	content []byte
	modTime time.Time
}

type fakeContainerFS struct {
	containerName string
	files         map[string]fakeFile
}

func newFakeContainerFS(containerName string) *fakeContainerFS {
	return &fakeContainerFS{containerName: containerName, files: map[string]fakeFile{}}
}

func (f *fakeContainerFS) addFile(path, content string) {
	f.files[path] = fakeFile{content: []byte(content), modTime: time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)}
}

func (f *fakeContainerFS) addDir(path string) {
	f.files[path] = fakeFile{isDir: true}
}

func (f *fakeContainerFS) GetArchive(_ context.Context, containerName, path string) (io.ReadCloser, error) {
	if containerName != f.containerName {
		return nil, dockerapi.ErrContainerNotFound
	}
	file, ok := f.files[path]
	if !ok {
		return nil, dockerapi.ErrContainerNotFound
	}

	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	base := path[stringsLastIndexByte(path, '/')+1:]
	if file.isDir {
		// Docker's archive API for a directory emits every descendant
		// (recursively) with names relative to the directory's own base
		// name -- reproduce that shape from every fake entry nested under
		// this path.
		writeTarEntry(tw, base, fakeFile{isDir: true, modTime: time.Now()})
		for p, entry := range f.files {
			if p == path || len(p) <= len(path) || p[:len(path)+1] != path+"/" {
				continue
			}
			rel := base + p[len(path):]
			writeTarEntry(tw, rel, entry)
		}
	} else {
		writeTarEntry(tw, base, file)
	}
	if err := tw.Close(); err != nil {
		return nil, err
	}
	return io.NopCloser(&buf), nil
}

func writeTarEntry(tw *tar.Writer, name string, file fakeFile) {
	if file.isDir {
		_ = tw.WriteHeader(&tar.Header{Name: name + "/", Typeflag: tar.TypeDir, Mode: 0o755, ModTime: file.modTime})
		return
	}
	_ = tw.WriteHeader(&tar.Header{Name: name, Typeflag: tar.TypeReg, Mode: 0o644, Size: int64(len(file.content)), ModTime: file.modTime})
	_, _ = tw.Write(file.content)
}

func stringsLastIndexByte(s string, b byte) int {
	for i := len(s) - 1; i >= 0; i-- {
		if s[i] == b {
			return i
		}
	}
	return -1
}

func createTestHarness(t testing.TB, app core.App) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("harnesses")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("name", "Test Harness")
	rec.Set("cli_id", "test-harness-"+uuid.NewString()[:8])
	rec.Set("acp_transport", "websocket")
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
}

func createRunningHarnessInstance(t testing.TB, app core.App, userID, containerName string) *core.Record {
	t.Helper()
	coll, err := app.FindCollectionByNameOrId("harness_instances")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(coll)
	rec.Set("harness", createTestHarness(t, app).Id)
	rec.Set("user", userID)
	rec.Set("container_name", containerName)
	rec.Set("status", "running")
	if err := app.Save(rec); err != nil {
		t.Fatal(err)
	}
	return rec
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

func mountFileOperations(e *core.ServeEvent, app core.App, reader containerArchiveReader) {
	registry := operation.NewRegistry()
	AddFileOperations(registry, FileDeps{App: app, Reader: reader})
	operation.MountForTests(e, registry.Routes())
}

func TestResolveWorkspacePath_RejectsDotDot(t *testing.T) {
	_, ok := resolveWorkspacePath("../etc/passwd")
	if ok {
		t.Fatal("expected ok=false for a .. escape, got ok=true")
	}
}

func TestResolveWorkspacePath_RejectsAbsolute(t *testing.T) {
	_, ok := resolveWorkspacePath("/etc/passwd")
	if ok {
		t.Fatal("expected ok=false for an absolute path, got ok=true")
	}
}

func TestResolveWorkspacePath_AllowsNestedPath(t *testing.T) {
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
	// archive fetch is left to return its own NotFound error.
	cleanPath, ok := resolveWorkspacePath("does/not/exist.go")
	if !ok {
		t.Fatal("expected ok=true for a non-existent (but non-escaping) path")
	}
	if cleanPath != "does/not/exist.go" {
		t.Fatalf("cleanPath = %q, want %q", cleanPath, "does/not/exist.go")
	}
}

func TestBuildFileTreeFromTar_NestedDirectory(t *testing.T) {
	fs := newFakeContainerFS("c1")
	fs.addDir("/workspace")
	fs.addFile("/workspace/main.go", "package main")
	fs.addDir("/workspace/internal")
	fs.addFile("/workspace/internal/nested.go", "package internal")

	archive, err := fs.GetArchive(context.Background(), "c1", "/workspace")
	if err != nil {
		t.Fatal(err)
	}
	defer archive.Close()
	got, err := buildFileTreeFromTar(archive, "workspace")
	if err != nil {
		t.Fatal(err)
	}

	if len(got) != 2 {
		t.Fatalf("got %d top-level entries, want 2 (internal, main.go); got=%+v", len(got), got)
	}
	if got[0].Name != "internal" || !got[0].IsDir {
		t.Fatalf("entry[0] = %+v, want dir internal", got[0])
	}
	if len(got[0].Children) != 1 || got[0].Children[0].Name != "nested.go" {
		t.Fatalf("internal.Children = %+v, want 1 (nested.go)", got[0].Children)
	}
	if got[1].Name != "main.go" || got[1].IsDir || got[1].Size != int64(len("package main")) {
		t.Fatalf("entry[1] = %+v, want file main.go", got[1])
	}
}

func TestBuildFileTreeFromTar_EmptyDirectory(t *testing.T) {
	fs := newFakeContainerFS("c1")
	fs.addDir("/workspace")
	archive, err := fs.GetArchive(context.Background(), "c1", "/workspace")
	if err != nil {
		t.Fatal(err)
	}
	defer archive.Close()
	got, err := buildFileTreeFromTar(archive, "workspace")
	if err != nil {
		t.Fatal(err)
	}
	if len(got) != 0 {
		t.Fatalf("got %d entries, want 0 for an empty directory", len(got))
	}
}

func TestFilesTreeEndpoint_RequiresAuth(t *testing.T) {
	scenario := tests.ApiScenario{
		Name:            "files-tree without auth is rejected",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files-tree",
		ExpectedStatus:  401,
		ExpectedContent: []string{"requires valid record authorization token"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e, app, newFakeContainerFS("unused"))
		},
	}
	scenario.Test(t)
}

func TestFilesTreeEndpoint_ReturnsFullNestedTree(t *testing.T) {
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
			user := newFilesTestUser(t, app, "files-tree@example.com")
			containerName := "test-container-" + uuid.NewString()[:8]
			createRunningHarnessInstance(t, app, user.Id, containerName)

			fs := newFakeContainerFS(containerName)
			fs.addDir("/workspace")
			fs.addFile("/workspace/main.go", "package main")
			fs.addDir("/workspace/internal")
			fs.addFile("/workspace/internal/nested.go", "package internal")
			mountFileOperations(e, app, fs)

			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesTreeEndpoint_NoRunningHarnessIs404(t *testing.T) {
	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files-tree 404s when this user has no running harness",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files-tree",
		Headers:         headers,
		ExpectedStatus:  404,
		ExpectedContent: []string{"Workspace not available"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e, app, newFakeContainerFS("unused"))
			user := newFilesTestUser(t, app, "no-harness@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesTreeEndpoint_RejectsPathEscape(t *testing.T) {
	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files-tree rejects a .. path escape",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files-tree?path=..%2Fetc",
		Headers:         headers,
		ExpectedStatus:  403,
		ExpectedContent: []string{"escape attempt"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			user := newFilesTestUser(t, app, "tree-path-escape@example.com")
			createRunningHarnessInstance(t, app, user.Id, "test-container-escape")
			mountFileOperations(e, app, newFakeContainerFS("test-container-escape"))
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
	scenario := tests.ApiScenario{
		Name:            "files read without auth is rejected",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=main.go",
		ExpectedStatus:  401,
		ExpectedContent: []string{"requires valid record authorization token"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			mountFileOperations(e, app, newFakeContainerFS("unused"))
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_ReturnsFileContent(t *testing.T) {
	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read returns the requested file's content",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=hello.txt",
		Headers:         headers,
		ExpectedStatus:  200,
		ExpectedContent: []string{"hello workspace"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			user := newFilesTestUser(t, app, "files-read@example.com")
			containerName := "test-container-" + uuid.NewString()[:8]
			createRunningHarnessInstance(t, app, user.Id, containerName)
			fs := newFakeContainerFS(containerName)
			fs.addFile("/workspace/hello.txt", "hello workspace")
			mountFileOperations(e, app, fs)
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
	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read sets Content-Type based on the file extension",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=notes.txt",
		Headers:         headers,
		ExpectedStatus:  200,
		ExpectedContent: []string{"plain text notes"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			user := newFilesTestUser(t, app, "files-read-content-type@example.com")
			containerName := "test-container-" + uuid.NewString()[:8]
			createRunningHarnessInstance(t, app, user.Id, containerName)
			fs := newFakeContainerFS(containerName)
			fs.addFile("/workspace/notes.txt", "plain text notes")
			mountFileOperations(e, app, fs)
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
	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read 404s for a file that does not exist",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=does-not-exist.txt",
		Headers:         headers,
		ExpectedStatus:  404,
		ExpectedContent: []string{"File not found"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			user := newFilesTestUser(t, app, "files-read-missing@example.com")
			containerName := "test-container-" + uuid.NewString()[:8]
			createRunningHarnessInstance(t, app, user.Id, containerName)
			mountFileOperations(e, app, newFakeContainerFS(containerName))
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_RejectsPathEscape(t *testing.T) {
	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read rejects a .. path escape",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=..%2Fetc%2Fpasswd",
		Headers:         headers,
		ExpectedStatus:  403,
		ExpectedContent: []string{"escape attempt"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			user := newFilesTestUser(t, app, "read-path-escape@example.com")
			createRunningHarnessInstance(t, app, user.Id, "test-container-read-escape")
			mountFileOperations(e, app, newFakeContainerFS("test-container-read-escape"))
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_ScopedToOwnContainer(t *testing.T) {
	headers := map[string]string{}
	scenario := tests.ApiScenario{
		Name:            "files read only ever resolves to the authenticated user's own container",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/v1/files?path=secret.txt",
		Headers:         headers,
		ExpectedStatus:  404,
		ExpectedContent: []string{"File not found"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			other := newFilesTestUser(t, app, "other-user@example.com")
			otherContainer := "other-users-container"
			createRunningHarnessInstance(t, app, other.Id, otherContainer)
			otherFS := newFakeContainerFS(otherContainer)
			otherFS.addFile("/workspace/secret.txt", "someone else's secret")

			me := newFilesTestUser(t, app, "me@example.com")
			myContainer := "my-container"
			createRunningHarnessInstance(t, app, me.Id, myContainer)
			// No secret.txt in my own container -- a 404 here (not the
			// other user's real content) is the only correct outcome.

			mountFileOperations(e, app, otherFS)
			token, err := me.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}
