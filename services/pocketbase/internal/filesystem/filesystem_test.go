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
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/tools/filesystem/blob"
)

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
