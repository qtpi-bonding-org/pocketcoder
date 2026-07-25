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
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/tools/filesystem/blob"
)

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

func TestGroupImmediateChildren_RootPrefix(t *testing.T) {
	mod := time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)
	objects := []*blob.ListObject{
		{Key: "main.go", Size: 1203, ModTime: mod},
		{Key: "internal/filesystem/filesystem.go", Size: 900, ModTime: mod},
		{Key: "internal/filesystem/filesystem_test.go", Size: 500, ModTime: mod},
		{Key: "go.mod", Size: 50, ModTime: mod},
	}

	got := groupImmediateChildren("", objects)

	if len(got) != 3 {
		t.Fatalf("got %d entries, want 3 (main.go, internal, go.mod); got=%+v", len(got), got)
	}
	// Sorted alphabetically: go.mod, internal, main.go
	if got[0].Name != "go.mod" || got[0].IsDir {
		t.Fatalf("entry[0] = %+v, want file go.mod", got[0])
	}
	if got[1].Name != "internal" || !got[1].IsDir {
		t.Fatalf("entry[1] = %+v, want dir internal", got[1])
	}
	if got[1].Size != 0 {
		t.Fatalf("directory entry Size = %d, want 0", got[1].Size)
	}
	if got[2].Name != "main.go" || got[2].IsDir || got[2].Size != 1203 {
		t.Fatalf("entry[2] = %+v, want file main.go size 1203", got[2])
	}
}

func TestGroupImmediateChildren_NestedPrefix(t *testing.T) {
	mod := time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)
	objects := []*blob.ListObject{
		{Key: "internal/filesystem/filesystem.go", Size: 900, ModTime: mod},
		{Key: "internal/filesystem/filesystem_test.go", Size: 500, ModTime: mod},
		{Key: "internal/hooks/mcp.go", Size: 300, ModTime: mod},
	}

	got := groupImmediateChildren("internal/", objects)

	if len(got) != 2 {
		t.Fatalf("got %d entries, want 2 (filesystem, hooks); got=%+v", len(got), got)
	}
	if got[0].Name != "filesystem" || !got[0].IsDir {
		t.Fatalf("entry[0] = %+v, want dir filesystem", got[0])
	}
	if got[1].Name != "hooks" || !got[1].IsDir {
		t.Fatalf("entry[1] = %+v, want dir hooks", got[1])
	}
}

func TestGroupImmediateChildren_EmptyInput(t *testing.T) {
	got := groupImmediateChildren("", nil)
	if len(got) != 0 {
		t.Fatalf("got %d entries, want 0 for empty input", len(got))
	}
}

func TestGroupImmediateChildren_DedupesDirectory(t *testing.T) {
	mod := time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)
	objects := []*blob.ListObject{
		{Key: "src/a.go", Size: 10, ModTime: mod},
		{Key: "src/b.go", Size: 20, ModTime: mod},
		{Key: "src/nested/c.go", Size: 30, ModTime: mod},
	}

	got := groupImmediateChildren("", objects)

	if len(got) != 1 {
		t.Fatalf("got %d entries, want 1 (src, deduped across 3 descendants); got=%+v", len(got), got)
	}
	if got[0].Name != "src" || !got[0].IsDir {
		t.Fatalf("entry[0] = %+v, want dir src", got[0])
	}
}
