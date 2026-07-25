# File Browser Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only file browser: a new PocketBase directory-listing endpoint, and new Flutter screens to browse the shared workspace and view a file's contents, entered from a `FILES` button on the chat screen.

**Architecture:** Backend adds a second route alongside the existing single-file endpoint in `filesystem.go`, reusing its auth/sanitization pattern and PocketBase's own `filesystem.System.List()` primitive. Flutter adds a repository/cubit/screen stack mirroring the existing `Skills` and `Auth` feature slices exactly, plus a lightweight file-viewer screen with no cubit (a one-shot fetch, not stateful navigation).

**Tech Stack:** Go (PocketBase custom route), Flutter (freezed, cubit_ui_flow's `AppCubit`, `injectable`/`get_it`, `go_router`, `http` package, `mocktail` for tests).

## Global Constraints

- Never use the `!` operator in Dart (root/client `CLAUDE.md`) — use `?.`/`??`/`requireNonNull`.
- Every repository method wrapped in `tryMethod` with a typed `DomainException` subclass (client `CLAUDE.md`).
- Cubits extend `AppCubit<T>` from `cubit_ui_flow`, state implements `IUiFlowState`, use `tryOperation`, must explicitly set `status: UiFlowStatus.success` (client `CLAUDE.md`).
- Localization: dot-notation source keys map to camelCase ARB keys (e.g. `files.title` → `filesTitle`); never hardcode user-facing strings (client `CLAUDE.md`) — except where this plan explicitly follows an existing inline-string precedent (see Task 7).
- This is a single-repo feature — everything lives in `/Users/aicoder/Documents/pocketcoder` (backend: `services/pocketbase/`, Flutter: `client/packages/pocketcoder_flutter/`). No cross-repo dependency.
- TDD: write the failing test first for every new function/cubit/widget behavior in this plan (`test-driven-development` skill).

---

### Task 1: Backend — directory-listing route

**Files:**
- Modify: `services/pocketbase/internal/filesystem/filesystem.go`
- Create: `services/pocketbase/internal/filesystem/filesystem_test.go`

**Interfaces:**
- Produces: `func groupImmediateChildren(prefix string, objects []*blob.ListObject) []fileEntry` — pure function, used only by the new route handler in this file. `type fileEntry struct { Name string; IsDir bool; Size int64; ModTime string }` (JSON tags `name`/`isDir`/`size`/`modTime`).
- Produces: `GET /api/pocketcoder/files-list/{path...}` route, registered inside the existing `RegisterFilesApi` function, response body `{"path": string, "entries": [fileEntry, ...]}`.

The current full file (for context — this is what you're extending):

```go
// @pocketcoder-core: Files API. Secure endpoint for accessing workspace files.
package filesystem

import (
	"io"
	"path/filepath"
	"strings"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
)

// RegisterFilesApi provides a secure window into the /workspace using the PB Filesystem abstraction.
func RegisterFilesApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.GET("/api/pocketcoder/files/{path...}", func(re *core.RequestEvent) error {
		// 1. Auth Gate
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}

		// 2. Resolve Path
		pathParam := re.Request.PathValue("path")
		if pathParam == "" {
			return re.BadRequestError("Empty path.", nil)
		}

		// Sanitization
		cleanPath := filepath.Clean(pathParam)
		if strings.HasPrefix(cleanPath, "..") || strings.HasPrefix(cleanPath, "/") {
			return re.ForbiddenError("Path escape attempt detected.", nil)
		}

		// 3. Initialize Filesystem Abstraction (S3-Ready)
		// For now we point it at the local /workspace volume
		fsys, err := filesystem.NewLocal("/workspace")
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
		if strings.HasSuffix(cleanPath, ".html") { re.Response.Header().Set("Content-Type", "text/html") }
		if strings.HasSuffix(cleanPath, ".png") { re.Response.Header().Set("Content-Type", "image/png") }
		if strings.HasSuffix(cleanPath, ".txt") { re.Response.Header().Set("Content-Type", "text/plain") }

		_, err = io.Copy(re.Response, r)
		return err
	}).Bind(apis.RequireAuth())
}
```

- [ ] **Step 1: Write the failing test for `groupImmediateChildren`**

Create `services/pocketbase/internal/filesystem/filesystem_test.go`:

```go
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -run TestGroupImmediateChildren -v`
Expected: FAIL with `undefined: groupImmediateChildren` (compile error — the function doesn't exist yet).

- [ ] **Step 3: Implement `groupImmediateChildren` and the new route**

Replace the full contents of `services/pocketbase/internal/filesystem/filesystem.go` with:

```go
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
		if _, exists := seen[name]; exists {
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
	e.Router.GET("/api/pocketcoder/files/{path...}", func(re *core.RequestEvent) error {
		// 1. Auth Gate
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}

		// 2. Resolve Path
		pathParam := re.Request.PathValue("path")
		if pathParam == "" {
			return re.BadRequestError("Empty path.", nil)
		}

		// Sanitization
		cleanPath := filepath.Clean(pathParam)
		if strings.HasPrefix(cleanPath, "..") || strings.HasPrefix(cleanPath, "/") {
			return re.ForbiddenError("Path escape attempt detected.", nil)
		}

		// 3. Initialize Filesystem Abstraction (S3-Ready)
		// For now we point it at the local /workspace volume
		fsys, err := filesystem.NewLocal("/workspace")
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
		if strings.HasSuffix(cleanPath, ".html") { re.Response.Header().Set("Content-Type", "text/html") }
		if strings.HasSuffix(cleanPath, ".png") { re.Response.Header().Set("Content-Type", "image/png") }
		if strings.HasSuffix(cleanPath, ".txt") { re.Response.Header().Set("Content-Type", "text/plain") }

		_, err = io.Copy(re.Response, r)
		return err
	}).Bind(apis.RequireAuth())

	e.Router.GET("/api/pocketcoder/files-list/{path...}", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.ForbiddenError("Direct access to fragments is forbidden for shadows.", nil)
		}

		pathParam := re.Request.PathValue("path")
		cleanPath := "."
		if pathParam != "" {
			cleanPath = filepath.Clean(pathParam)
			if strings.HasPrefix(cleanPath, "..") || strings.HasPrefix(cleanPath, "/") {
				return re.ForbiddenError("Path escape attempt detected.", nil)
			}
		}

		fsys, err := filesystem.NewLocal("/workspace")
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -run TestGroupImmediateChildren -v`
Expected: PASS (all 4 subtests).

- [ ] **Step 5: Verify the package builds and vets clean**

Run: `cd services/pocketbase && go build ./... && go vet ./...`
Expected: no output, exit code 0.

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/filesystem/filesystem.go services/pocketbase/internal/filesystem/filesystem_test.go
git commit -m "feat(backend): add directory-listing endpoint for the file browser"
```

**Note on route-level testing:** this codebase has no existing precedent for full HTTP-level (`httptest`/`ApiScenario`) tests of custom PocketCoder routes — every existing test in `internal/api/` and `internal/hooks/` tests an extracted pure/logic function via `tests.NewTestApp()`, not the route wiring itself (confirmed: `internal/api/schedules_test.go`'s `resolveOwnedSchedule`, `internal/api/skills_test.go`'s `buildCreateSkillParams`). The sibling single-file endpoint (`GET /api/pocketcoder/files/{path...}`) also has zero tests of any kind. This task follows the established convention: `groupImmediateChildren` (the one piece with real logic) is fully unit-tested; the route handler's auth-gate and path-sanitization are copy-pasted verbatim from the already-shipped, identically-unstructured sibling route, so they carry the same (currently zero) test coverage as existing code, not a regression.

---

### Task 2: Flutter — `ApiEndpoints` constant + `FileEntry` model

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart`
- Create: `client/packages/pocketcoder_flutter/lib/domain/models/file_entry.dart`

**Interfaces:**
- Produces: `ApiEndpoints.filesList(String path) -> String`
- Produces: `FileEntry` freezed class — `{required String name, required bool isDir, required int size, required String modTime}`, with `FileEntry.fromJson(Map<String, dynamic>)`.

This is a hand-written model, not generator output — `scripts/generate_models.py` reads only `assets/pb_schema.json` (PocketBase collection definitions) and has no concept of custom REST endpoint responses (same reason `lib/domain/models/skill.dart` is hand-written for the `skills/list` endpoint).

- [ ] **Step 1: Add the endpoint constant**

In `lib/infrastructure/core/api_endpoints.dart`, add after the existing `files(path)` method (the `// FILE ENDPOINTS` section):

```dart
  /// GET /api/pocketcoder/files-list/{path}
  /// Lists the immediate children of a workspace directory.
  static String filesList(String path) => '/api/pocketcoder/files-list/$path';
```

Add `'/api/pocketcoder/files-list/{path}'` to the `dynamicEndpoints` list (alongside the existing `'/api/pocketcoder/files/{path}'` entry).

- [ ] **Step 2: Create the `FileEntry` model**

Create `lib/domain/models/file_entry.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_entry.freezed.dart';
part 'file_entry.g.dart';

/// One immediate child of a listed workspace directory. NOT PocketBase-backed
/// — built from JSON returned by GET /api/pocketcoder/files-list/{path}
/// (services/pocketbase/internal/filesystem/filesystem.go), the same category
/// of hand-written, non-collection model as [Skill].
@freezed
abstract class FileEntry with _$FileEntry {
  const factory FileEntry({
    required String name,
    required bool isDir,
    required int size,
    required String modTime,
  }) = _FileEntry;

  factory FileEntry.fromJson(Map<String, dynamic> json) =>
      _$FileEntryFromJson(json);
}
```

- [ ] **Step 3: Generate freezed/json_serializable code**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: completes successfully, creates `lib/domain/models/file_entry.freezed.dart` and `lib/domain/models/file_entry.g.dart`.

- [ ] **Step 4: Verify it compiles**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/domain/models/file_entry.dart lib/infrastructure/core/api_endpoints.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/infrastructure/core/api_endpoints.dart lib/domain/models/file_entry.dart lib/domain/models/file_entry.freezed.dart lib/domain/models/file_entry.g.dart
git commit -m "feat(flutter): add FileEntry model and files-list endpoint constant"
```

---

### Task 3: Flutter — `FilesException` + `IFilesRepository`/`FilesRepository`

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`
- Create: `client/packages/pocketcoder_flutter/lib/domain/files/i_files_repository.dart`
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/files/files_repository.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/files/files_repository_test.dart`

**Interfaces:**
- Consumes: `FileEntry` (Task 2), `ApiEndpoints.filesList` (Task 2), `ApiEndpoints.files` (existing, `lib/infrastructure/core/api_endpoints.dart:35`).
- Produces: `abstract class IFilesRepository { Future<List<FileEntry>> listFiles(String path); Future<List<int>> readFile(String path); }`, implemented by `@LazySingleton(as: IFilesRepository) class FilesRepository`. `FilesException extends DomainException`.

`readFile` cannot use `_pb.send` (built for JSON, not raw bytes) — it follows `AgentStreamClient`'s exact DI/token pattern (`lib/infrastructure/agent/agent_stream_client.dart:55-59`): inject both `PocketBase` and `http.Client` via the constructor (not `http.get` as a static call) so tests can supply a fake client, read the URL from `_pb.baseURL` (capital URL — confirmed property name), and set the `Authorization` header to the **raw** `_pb.authStore.token` value with **no `Bearer ` prefix** — `agent_stream_client.dart:88-90`'s comment confirms this is deliberate: "c1 only checks the raw token value, so we mirror what PocketBase's own client does internally."

- [ ] **Step 1: Write the failing repository tests**

Create `test/infrastructure/files/files_repository_test.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/files/files_repository.dart';

class MockPocketBase extends Mock implements PocketBase {}

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late FilesRepository repo;
  late MockPocketBase pb;
  late MockHttpClient httpClient;
  late MockAuthStore authStore;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    pb = MockPocketBase();
    httpClient = MockHttpClient();
    authStore = MockAuthStore();
    when(() => pb.baseURL).thenReturn('http://pb.local:8090');
    when(() => pb.authStore).thenReturn(authStore);
    when(() => authStore.token).thenReturn('raw-token-value');
    repo = FilesRepository(pb, httpClient);
  });

  group('FilesRepository.listFiles', () {
    test('GETs files-list and maps entries', () async {
      when(() => pb.send<dynamic>(
            '/api/pocketcoder/files-list/src',
            method: any(named: 'method'),
          )).thenAnswer((_) async => {
            'path': 'src',
            'entries': [
              {'name': 'main.go', 'isDir': false, 'size': 100, 'modTime': '2026-07-25T10:00:00Z'},
              {'name': 'internal', 'isDir': true, 'size': 0, 'modTime': ''},
            ],
          });

      final result = await repo.listFiles('src');

      expect(result, hasLength(2));
      expect(result[0].name, 'main.go');
      expect(result[1].isDir, isTrue);
      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/files-list/src',
            method: 'GET',
          )).called(1);
    });

    test('wraps failures in FilesException', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method')))
          .thenThrow(Exception('boom'));

      await expectLater(
        () => repo.listFiles('src'),
        throwsA(isA<FilesException>()),
      );
    });
  });

  group('FilesRepository.readFile', () {
    test('GETs the raw file endpoint with the auth token header, no Bearer prefix', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response.bytes([1, 2, 3], 200),
      );

      final result = await repo.readFile('main.go');

      expect(result, [1, 2, 3]);
      final captured = verify(() => httpClient.get(captureAny(), headers: captureAny(named: 'headers')))
          .captured;
      final uri = captured[0] as Uri;
      final headers = captured[1] as Map<String, String>;
      expect(uri.toString(), 'http://pb.local:8090/api/pocketcoder/files/main.go');
      expect(headers['Authorization'], 'raw-token-value');
    });

    test('wraps failures in FilesException', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers')))
          .thenThrow(Exception('network down'));

      await expectLater(
        () => repo.readFile('main.go'),
        throwsA(isA<FilesException>()),
      );
    });
  });
}

class MockAuthStore extends Mock implements AuthStore {}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/files/files_repository_test.dart`
Expected: FAIL — `files_repository.dart` doesn't exist yet (compile error).

- [ ] **Step 3: Add `FilesException`**

In `lib/domain/exceptions.dart`, add after the existing `SkillsException` class (line 87-89):

```dart
/// Files-related exceptions.
class FilesException extends DomainException {
  FilesException(super.message, [super.cause]);
}
```

- [ ] **Step 4: Write `IFilesRepository`**

Create `lib/domain/files/i_files_repository.dart`:

```dart
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';

abstract class IFilesRepository {
  Future<List<FileEntry>> listFiles(String path);
  Future<List<int>> readFile(String path);
}
```

- [ ] **Step 5: Implement `FilesRepository`**

Create `lib/infrastructure/files/files_repository.dart`:

```dart
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';

@LazySingleton(as: IFilesRepository)
class FilesRepository implements IFilesRepository {
  final PocketBase _pb;
  final http.Client _http;

  FilesRepository(this._pb, this._http);

  @override
  Future<List<FileEntry>> listFiles(String path) async {
    return tryMethod(
      () async {
        final response = await _pb.send<dynamic>(
          ApiEndpoints.filesList(path),
          method: 'GET',
        );
        final entries = (response as Map<String, dynamic>)['entries'] as List;
        return entries
            .map((e) => FileEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      },
      FilesException.new,
      'listFiles',
    );
  }

  @override
  Future<List<int>> readFile(String path) async {
    return tryMethod(
      () async {
        final uri = Uri.parse('${_pb.baseURL}${ApiEndpoints.files(path)}');
        final response = await _http.get(
          uri,
          headers: {'Authorization': _pb.authStore.token},
        );
        return response.bodyBytes;
      },
      FilesException.new,
      'readFile',
    );
  }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/files/files_repository_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Verify no analyzer regressions**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/domain/exceptions.dart lib/domain/files/i_files_repository.dart lib/infrastructure/files/files_repository.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/domain/exceptions.dart lib/domain/files/i_files_repository.dart lib/infrastructure/files/files_repository.dart test/infrastructure/files/files_repository_test.dart
git commit -m "feat(flutter): add FilesRepository for listing and reading workspace files"
```

---

### Task 4: Flutter — `FileBrowserState`/`FileBrowserCubit`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/application/files/file_browser_state.dart`
- Create: `client/packages/pocketcoder_flutter/lib/application/files/file_browser_cubit.dart`
- Test: `client/packages/pocketcoder_flutter/test/application/files/file_browser_cubit_test.dart`

**Interfaces:**
- Consumes: `IFilesRepository` (Task 3), `FileEntry` (Task 2).
- Produces: `FileBrowserState { UiFlowStatus status, String path, List<FileEntry> entries, Object? error }`. `FileBrowserCubit extends AppCubit<FileBrowserState>` with `Future<void> open(String path)`, `Future<void> navigateInto(String name)`, `Future<void> navigateUp()`.

Modeled on `AuthState`/`AuthCubit` (`lib/application/system/auth_cubit.dart`) — a single non-union `IUiFlowState`, since there's one loading/loaded/error shape here, not several distinct named states (unlike `SkillsState`'s sealed union).

- [ ] **Step 1: Write the failing cubit tests**

Create `test/application/files/file_browser_cubit_test.dart`:

```dart
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';

class MockFilesRepository extends Mock implements IFilesRepository {}

void main() {
  late MockFilesRepository repo;
  FileBrowserCubit? lastCubit;

  FileBrowserCubit buildCubit() {
    final cubit = FileBrowserCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockFilesRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('FileBrowserCubit.open', () {
    test('lists entries and sets path/status on success', () async {
      when(() => repo.listFiles('src')).thenAnswer((_) async => const [
            FileEntry(name: 'main.go', isDir: false, size: 10, modTime: ''),
          ]);
      final cubit = buildCubit();

      await cubit.open('src');

      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.path, 'src');
      expect(cubit.state.entries, hasLength(1));
    });

    test('sets failure status when repository throws', () async {
      when(() => repo.listFiles('src')).thenThrow(Exception('boom'));
      final cubit = buildCubit();

      await cubit.open('src');

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isNotNull);
    });
  });

  group('FileBrowserCubit.navigateInto', () {
    test('appends the name to the current path and opens it', () async {
      when(() => repo.listFiles('src')).thenAnswer((_) async => const []);
      when(() => repo.listFiles('src/internal')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('src');
      await cubit.navigateInto('internal');

      expect(cubit.state.path, 'src/internal');
      verify(() => repo.listFiles('src/internal')).called(1);
    });

    test('does not prefix with a slash when the current path is empty', () async {
      when(() => repo.listFiles('')).thenAnswer((_) async => const []);
      when(() => repo.listFiles('src')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('');
      await cubit.navigateInto('src');

      expect(cubit.state.path, 'src');
    });
  });

  group('FileBrowserCubit.navigateUp', () {
    test('strips the last path segment and reopens', () async {
      when(() => repo.listFiles('src/internal')).thenAnswer((_) async => const []);
      when(() => repo.listFiles('src')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('src/internal');
      await cubit.navigateUp();

      expect(cubit.state.path, 'src');
      verify(() => repo.listFiles('src')).called(1);
    });

    test('is a no-op at the root path', () async {
      when(() => repo.listFiles('')).thenAnswer((_) async => const []);
      final cubit = buildCubit();

      await cubit.open('');
      await cubit.navigateUp();

      expect(cubit.state.path, '');
      verify(() => repo.listFiles('')).called(1);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/files/file_browser_cubit_test.dart`
Expected: FAIL — `file_browser_cubit.dart` doesn't exist yet (compile error).

- [ ] **Step 3: Write `FileBrowserState`**

Create `lib/application/files/file_browser_state.dart`:

```dart
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';

part 'file_browser_state.freezed.dart';

@freezed
sealed class FileBrowserState with _$FileBrowserState implements IUiFlowState {
  const FileBrowserState._();

  const factory FileBrowserState({
    @Default(UiFlowStatus.idle) UiFlowStatus status,
    @Default('') String path,
    @Default([]) List<FileEntry> entries,
    Object? error,
  }) = _FileBrowserState;

  factory FileBrowserState.initial() => const FileBrowserState();

  @override
  bool get isIdle => status == UiFlowStatus.idle;
  @override
  bool get isLoading => status == UiFlowStatus.loading;
  @override
  bool get isSuccess => status == UiFlowStatus.success;
  @override
  bool get isFailure => status == UiFlowStatus.failure;
  @override
  bool get hasError => error != null;
}
```

- [ ] **Step 4: Write `FileBrowserCubit`**

Create `lib/application/files/file_browser_cubit.dart`:

```dart
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';

@injectable
class FileBrowserCubit extends AppCubit<FileBrowserState> {
  final IFilesRepository _repository;

  FileBrowserCubit(this._repository) : super(FileBrowserState.initial());

  Future<void> open(String path) async {
    return tryOperation(() async {
      final entries = await _repository.listFiles(path);
      return createSuccessState().copyWith(path: path, entries: entries);
    });
  }

  Future<void> navigateInto(String name) async {
    final next = state.path.isEmpty ? name : '${state.path}/$name';
    await open(next);
  }

  Future<void> navigateUp() async {
    if (state.path.isEmpty) return;
    final segments = state.path.split('/')..removeLast();
    await open(segments.join('/'));
  }
}
```

- [ ] **Step 5: Generate freezed code**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: completes successfully, creates `lib/application/files/file_browser_state.freezed.dart`.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/files/file_browser_cubit_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 7: Commit**

```bash
git add lib/application/files/file_browser_state.dart lib/application/files/file_browser_state.freezed.dart lib/application/files/file_browser_cubit.dart test/application/files/file_browser_cubit_test.dart
git commit -m "feat(flutter): add FileBrowserCubit for directory navigation state"
```

---

### Task 5: Flutter — `FileBrowserScreen`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/files/file_browser_screen.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/files/file_browser_screen_test.dart`

**Interfaces:**
- Consumes: `FileBrowserCubit`/`FileBrowserState` (Task 4), `FileEntry` (Task 2), `PocketCoderShell`/`NavPillar` (`lib/presentation/core/widgets/pocketcoder_shell.dart`), `UiFlowListener` (`lib/presentation/core/widgets/ui_flow_listener.dart`), `TerminalText`/`TerminalLoadingIndicator` (`lib/presentation/core/widgets/`).
- Produces: `class FileBrowserScreen extends StatelessWidget` — takes `onOpenFile` only (opens at the workspace root; navigation happens via cubit calls, not route params). Tapping a directory row calls `context.read<FileBrowserCubit>().navigateInto(entry.name)`. Tapping a file row calls a `void Function(BuildContext, String path) onOpenFile` callback param (kept as a constructor param, not a direct `AppNavigation.toFileViewer` call, so this widget test doesn't need a real `GoRouter` — Task 6/7 wires the real navigation callback in `app_router.dart`).

**Deviation from spec §3.2:** the spec describes `FileBrowserScreen` as mirroring `SkillsScreen`'s structure by owning its own `BlocProvider(create: (_) => getIt<FileBrowserCubit>()..open(''))` internally (`lib/presentation/skills/skills_screen.dart:25-30`). This task instead has `FileBrowserScreen` expect an ancestor-provided `FileBrowserCubit` (via `context.read`), with the `BlocProvider` moved to Task 7's `app_router.dart` route registration. This is a deliberate choice, not an oversight: `FileViewerScreen` (Task 6) already needs `getIt<IFilesRepository>()` resolved at the route's `pageBuilder` rather than inside the widget (for the same widget-testability reason — see Task 6's Interfaces note), so keeping both new screens' DI wiring in one place (`app_router.dart`) is more consistent than splitting it (one screen self-provisions, the other doesn't). Functionally equivalent either way — `getIt<FileBrowserCubit>()..open('')` runs exactly once per navigation to `AppRoutes.files` regardless of which file owns the `BlocProvider` call.

- [ ] **Step 1: Write the failing widget test**

Create `test/presentation/files/file_browser_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/files/file_browser_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockFileBrowserCubit extends Mock implements FileBrowserCubit {}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  late MockFileBrowserCubit cubit;

  setUp(() {
    cubit = MockFileBrowserCubit();
  });

  Widget buildTestable({void Function(BuildContext, String)? onOpenFile}) {
    return _wrap(
      BlocProvider<FileBrowserCubit>.value(
        value: cubit,
        child: FileBrowserScreen(onOpenFile: onOpenFile ?? (_, __) {}),
      ),
    );
  }

  testWidgets('renders entries as tappable rows', (tester) async {
    when(() => cubit.state).thenReturn(const FileBrowserState(
      status: UiFlowStatus.success,
      path: '',
      entries: [
        FileEntry(name: 'main.go', isDir: false, size: 10, modTime: ''),
        FileEntry(name: 'internal', isDir: true, size: 0, modTime: ''),
      ],
    ));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('main.go'), findsOneWidget);
    expect(find.text('internal'), findsOneWidget);
  });

  testWidgets('tapping a directory row calls navigateInto', (tester) async {
    when(() => cubit.state).thenReturn(const FileBrowserState(
      status: UiFlowStatus.success,
      entries: [FileEntry(name: 'internal', isDir: true, size: 0, modTime: '')],
    ));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.navigateInto(any())).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('internal'));
    await tester.pumpAndSettle();

    verify(() => cubit.navigateInto('internal')).called(1);
  });

  testWidgets('tapping a file row invokes onOpenFile with the full path', (tester) async {
    when(() => cubit.state).thenReturn(const FileBrowserState(
      status: UiFlowStatus.success,
      path: 'src',
      entries: [FileEntry(name: 'main.go', isDir: false, size: 10, modTime: '')],
    ));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    String? openedPath;

    await tester.pumpWidget(buildTestable(onOpenFile: (_, path) => openedPath = path));
    await tester.pumpAndSettle();

    await tester.tap(find.text('main.go'));
    await tester.pumpAndSettle();

    expect(openedPath, 'src/main.go');
  });

  testWidgets('shows an empty-state message when entries is empty', (tester) async {
    when(() => cubit.state).thenReturn(const FileBrowserState(status: UiFlowStatus.success));
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    expect(find.text('NO FILES'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/files/file_browser_screen_test.dart`
Expected: FAIL — `file_browser_screen.dart` doesn't exist yet (compile error).

- [ ] **Step 3: Add the new ARB keys used by this screen**

In `lib/l10n/app_en.arb`, add (alphabetically near the other `files*`-prefixed keys, creating that group — none exist yet except the already-present, currently-unused `chatFilesAction`):

```json
  "filesTitle": "FILES",
  "filesEmpty": "NO FILES",
```

Run: `cd client/packages/pocketcoder_flutter && flutter gen-l10n`
Expected: regenerates `lib/l10n/app_localizations*.dart` and `lib/l10n/l10n_key_resolver.g.dart` with `context.l10n.filesTitle` / `context.l10n.filesEmpty` available.

- [ ] **Step 4: Implement `FileBrowserScreen`**

Create `lib/presentation/files/file_browser_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';
import 'package:pocketcoder_flutter/application/files/file_browser_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/file_entry.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';

/// Browses the shared workspace, one directory at a time.
///
/// [onOpenFile] is a callback rather than a direct `AppNavigation` call so
/// this widget stays testable without a real [GoRouter] — `app_router.dart`
/// wires the real navigation.
class FileBrowserScreen extends StatelessWidget {
  final void Function(BuildContext context, String path) onOpenFile;

  const FileBrowserScreen({super.key, required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return UiFlowListener<FileBrowserCubit, FileBrowserState>(
      child: _FileBrowserView(onOpenFile: onOpenFile),
    );
  }
}

class _FileBrowserView extends StatelessWidget {
  final void Function(BuildContext context, String path) onOpenFile;

  const _FileBrowserView({required this.onOpenFile});

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.filesTitle,
      activePillar: NavPillar.chats,
      showBack: true,
      body: BlocBuilder<FileBrowserCubit, FileBrowserState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: TerminalLoadingIndicator());
          }
          if (state.entries.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(AppSizes.space * 4),
                child: TerminalText(context.l10n.filesEmpty, alpha: 0.5),
              ),
            );
          }
          return ListView(
            children: [
              Padding(
                padding: EdgeInsets.all(AppSizes.space),
                child: TerminalText.mini('/${state.path}', alpha: 0.6),
              ),
              ...state.entries.map((entry) => _entryRow(context, state, entry)),
            ],
          );
        },
      ),
    );
  }

  Widget _entryRow(BuildContext context, FileBrowserState state, FileEntry entry) {
    return ListTile(
      leading: Icon(entry.isDir ? Icons.folder : Icons.insert_drive_file),
      title: TerminalText(entry.name),
      onTap: () {
        if (entry.isDir) {
          context.read<FileBrowserCubit>().navigateInto(entry.name);
        } else {
          final fullPath = state.path.isEmpty ? entry.name : '${state.path}/${entry.name}';
          onOpenFile(context, fullPath);
        }
      },
    );
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/files/file_browser_screen_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/l10n_key_resolver.g.dart lib/presentation/files/file_browser_screen.dart test/presentation/files/file_browser_screen_test.dart
git commit -m "feat(flutter): add FileBrowserScreen"
```

---

### Task 6: Flutter — `FileViewerScreen`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/files/file_viewer_screen.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/files/file_viewer_screen_test.dart`

**Interfaces:**
- Consumes: `IFilesRepository` (Task 3), `TerminalLoadingIndicator`/`TerminalText`.
- Produces: `class FileViewerScreen extends StatefulWidget { final String path; final IFilesRepository repository; const FileViewerScreen({required this.path, required this.repository}); }` — `repository` is a constructor param (not a `getIt` lookup inside `build`), matching this plan's testability approach in Task 5; `app_router.dart` (Task 7) supplies `getIt<IFilesRepository>()` at the route's `pageBuilder`.

No cubit — this is a one-shot fetch-and-render with no further user interaction, unlike `FileBrowserScreen`'s navigation state.

- [ ] **Step 1: Write the failing widget test**

Create `test/presentation/files/file_viewer_screen_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/files/file_viewer_screen.dart';

class MockFilesRepository extends Mock implements IFilesRepository {}

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  late MockFilesRepository repo;

  setUp(() {
    repo = MockFilesRepository();
  });

  testWidgets('renders text content as selectable text', (tester) async {
    when(() => repo.readFile('README.md'))
        .thenAnswer((_) async => utf8.encode('hello world'));

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'README.md', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('renders a .png path as an image', (tester) async {
    // 1x1 transparent PNG.
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    );
    when(() => repo.readFile('logo.png')).thenAnswer((_) async => pngBytes);

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'logo.png', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('renders an unsupported-type message for non-UTF8 binary', (tester) async {
    // Invalid UTF-8 byte sequence, and not an image extension.
    when(() => repo.readFile('data.bin'))
        .thenAnswer((_) async => Uint8List.fromList([0xFF, 0xFE, 0xFD]));

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'data.bin', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.text("CAN'T PREVIEW THIS FILE TYPE"), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/files/file_viewer_screen_test.dart`
Expected: FAIL — `file_viewer_screen.dart` doesn't exist yet (compile error).

- [ ] **Step 3: Implement `FileViewerScreen`**

Create `lib/presentation/files/file_viewer_screen.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';

const _imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.webp'];

class FileViewerScreen extends StatefulWidget {
  final String path;
  final IFilesRepository repository;

  const FileViewerScreen({super.key, required this.path, required this.repository});

  @override
  State<FileViewerScreen> createState() => _FileViewerScreenState();
}

class _FileViewerScreenState extends State<FileViewerScreen> {
  bool _loading = true;
  Uint8List? _bytes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.repository.readFile(widget.path);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  bool get _isImage {
    final lower = widget.path.toLowerCase();
    return _imageExtensions.any(lower.endsWith);
  }

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: widget.path,
      activePillar: NavPillar.chats,
      showBack: true,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: TerminalLoadingIndicator());
    }
    final error = _error;
    if (error != null) {
      return Center(
        child: TerminalText('ERROR: $error', alpha: 0.8),
      );
    }
    final bytes = _bytes;
    if (bytes == null) {
      return const SizedBox.shrink();
    }
    if (_isImage) {
      return Center(child: Image.memory(bytes));
    }
    try {
      final text = utf8.decode(bytes);
      return SingleChildScrollView(
        padding: EdgeInsets.all(AppSizes.space * 2),
        child: SelectableText(
          text,
          style: TextStyle(
            fontFamily: AppFonts.bodyFamily,
            fontSize: AppSizes.fontMini,
            package: 'pocketcoder_flutter',
          ),
        ),
      );
    } on FormatException {
      return Center(
        child: TerminalText("CAN'T PREVIEW THIS FILE TYPE", alpha: 0.5),
      );
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/files/file_viewer_screen_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/files/file_viewer_screen.dart test/presentation/files/file_viewer_screen_test.dart
git commit -m "feat(flutter): add FileViewerScreen with text/image/binary-fallback rendering"
```

---

### Task 7: Flutter — routing + chat screen entry point

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/app_router.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/chat/chat_screen.dart`

**Interfaces:**
- Consumes: `FileBrowserScreen` (Task 5), `FileViewerScreen` (Task 6), `IFilesRepository`/`getIt` (Task 3), `FileBrowserCubit`/`getIt` (Task 4).
- Produces: registered `AppRoutes.files` route; new `AppRoutes.fileViewer`/`RouteNames.fileViewer`; `AppNavigation.toFileViewer(BuildContext, String path)`.

- [ ] **Step 1: Register the `FileBrowserScreen` route and add the `fileViewer` route**

In `lib/app_router.dart`, add the import (alongside the other `presentation/*` screen imports at the top):

```dart
import 'package:pocketcoder_flutter/presentation/files/file_browser_screen.dart';
import 'package:pocketcoder_flutter/presentation/files/file_viewer_screen.dart';
```

Also add, since `FileViewerScreen` needs it at the route's `pageBuilder`:

```dart
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/domain/files/i_files_repository.dart';
```

In the `routes:` list, add two new `GoRoute`s after the `// ── DEPLOY pillar ──` block's `AppRoutes.deploy` route and before `..._additionalRoutes`:

```dart
      // ── FILES ──
      GoRoute(
        path: AppRoutes.files,
        name: RouteNames.files,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: BlocProvider(
            create: (_) => getIt<FileBrowserCubit>()..open(''),
            child: FileBrowserScreen(
              onOpenFile: (context, path) =>
                  AppNavigation.toFileViewer(context, path),
            ),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.fileViewer,
        name: RouteNames.fileViewer,
        pageBuilder: (context, state) {
          final path = state.uri.queryParameters['path'] ?? '';
          return TerminalTransition.buildPage(
            context: context,
            state: state,
            child: FileViewerScreen(path: path, repository: getIt<IFilesRepository>()),
          );
        },
      ),
```

(`BlocProvider` needs `import 'package:flutter_bloc/flutter_bloc.dart';` and `import 'package:pocketcoder_flutter/application/files/file_browser_cubit.dart';` added to the import block too.)

In the `AppRoutes` class, add next to the existing `files`/`terminal` constants (line 226-227):

```dart
  static const String fileViewer = '/files/view';
```

In the `RouteNames` class, add next to the existing `files`/`terminal` constants (line 266-267):

```dart
  static const String fileViewer = 'fileViewer';
```

- [ ] **Step 2: Add `toFileViewer` navigation helper**

In `AppNavigation`, add next to the existing `toFiles` (line 310-311), following the exact `pushNamed(..., queryParameters: {...})` precedent already used by `toDeploymentDetails` (line 324-328):

```dart
  static void toFileViewer(BuildContext context, String path) =>
      context.pushNamed(
        RouteNames.fileViewer,
        queryParameters: {'path': path},
      );
```

- [ ] **Step 3: Verify the router compiles**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/app_router.dart`
Expected: `No issues found!`

- [ ] **Step 4: Add the `FILES` button to `ChatScreen`**

In `lib/presentation/chat/chat_screen.dart`, the current `extraHeaderActions` block (lines 129-135) is:

```dart
          extraHeaderActions: [
            if (isRunning)
              TerminalAction(
                label: 'CANCEL',
                onTap: () => context.read<ChatCubit>().cancel(),
              ),
          ],
```

Replace with:

```dart
          extraHeaderActions: [
            TerminalAction(
              label: context.l10n.chatFilesAction,
              onTap: () => AppNavigation.toFiles(context),
            ),
            if (isRunning)
              TerminalAction(
                label: 'CANCEL',
                onTap: () => context.read<ChatCubit>().cancel(),
              ),
          ],
```

This uses `context.l10n.chatFilesAction`, an ARB key that **already exists** (`lib/l10n/app_en.arb`, value `"FILES"`) but is currently unused anywhere in the app — no new ARB key needed for this button's label. `chat_screen.dart` does **not** currently import `app_router.dart` (confirmed: no `AppNavigation`/`AppRoutes`/`app_router` reference anywhere in the file today) — add `import 'package:pocketcoder_flutter/app_router.dart';` to the import block alongside the other imports at the top of the file.

- [ ] **Step 5: Verify the chat screen compiles**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/presentation/chat/chat_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Manual smoke check (documented, not automatable in this environment)**

This plan's automated tests cover the cubit/repository/widget layers in isolation; there is no automated way in this environment to drive a real `GoRouter` navigation end-to-end against a live PocketBase + Goose session. Before considering this task done, manually verify once against a running `docker compose --profile agent up -d` stack: open a chat, tap `FILES`, confirm the workspace root lists real files, navigate into a subdirectory and back up, open a text file and an image file, and confirm a binary file shows the fallback message.

- [ ] **Step 7: Commit**

```bash
git add lib/app_router.dart lib/presentation/chat/chat_screen.dart
git commit -m "feat(flutter): register file browser routes and add FILES entry point to chat screen"
```

---

### Task 8: Final verification

**Files:** none (verification only).

- [ ] **Step 1: Backend — build, vet, test**

Run: `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: build and vet produce no output; test summary shows `ok` for every package (including the new `internal/filesystem` package), no failures.

- [ ] **Step 2: Flutter — regenerate all codegen**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: completes successfully with no conflicting-output prompts left unresolved (all `--delete-conflicting-outputs` auto-handled).

- [ ] **Step 3: Flutter — analyze**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze`
Expected: `No issues found!` (or only pre-existing issues unrelated to this feature — if any appear in files this plan touched, fix them before proceeding).

- [ ] **Step 4: Flutter — full test suite**

Run: `cd client/packages/pocketcoder_flutter && flutter test`
Expected: all tests pass, including every new test file from Tasks 3-6, with no regressions in existing suites.

- [ ] **Step 5: Commit (only if Steps 1-4 required fixes)**

If any step above required a fix, stage and commit it:

```bash
git add -A
git commit -m "fix: address final verification issues for file browser feature"
```

If no fixes were needed, skip this step — Tasks 1-7 are already fully committed.

## Self-Review

**1. Spec coverage:**
- §3.1 (backend route + `groupImmediateChildren`) → Task 1. ✓
- §3.2 endpoint constant, `FileEntry` model → Task 2. ✓
- §3.2 `IFilesRepository`/`FilesRepository`, `FilesException` → Task 3. ✓
- §3.2 `FileBrowserState`/`FileBrowserCubit` → Task 4. ✓
- §3.2 `FileBrowserScreen` → Task 5. ✓
- §3.2 `FileViewerScreen` → Task 6. ✓
- §3.2 routing, `toFileViewer`, chat screen entry point, ARB keys → Task 7. Note: this plan corrects two spec details after re-verifying current source during plan-writing: (a) the FILES button reuses the already-existing, currently-unused `chatFilesAction` ARB key rather than the spec's proposed new `chat.files_button` key; (b) `readFile`'s `Authorization` header uses the raw token with no `Bearer ` prefix (confirmed via `agent_stream_client.dart:88-90`'s explicit comment on this), not `Bearer $token` as an earlier draft assumed.
- §4 data flow (browsing + viewing) → exercised end-to-end by Tasks 4-7 collectively; Task 7 Step 6 documents the one gap (no automated live-session smoke test possible in this environment).
- §5 error handling (empty dir, path escape, binary fallback, network failure) → empty dir/binary fallback covered by Task 6 tests; path escape reuses the existing sibling route's untested-but-identical logic (Task 1 note); network failure on `readFile` covered by Task 6's inline-error rendering path (`_error` state) and Task 3's `FilesException`-wrapping test.
- §6 testing → Tasks 1, 3, 4, 5, 6 each carry their own TDD test; Task 1's note explains the deliberate, precedent-matching scope decision on route-level HTTP testing.
- §7 out of scope → no task adds upload/delete/rename/search/per-chat-scoping/syntax-highlighting; confirmed absent from every task above.

**2. Placeholder scan:** no `TBD`/`TODO`/"add error handling" placeholders — every step has complete, concrete code or an exact command with expected output.

**3. Type consistency:** `FileEntry(name, isDir, size, modTime)` (Task 2) is used identically in Task 3's repository, Task 4's cubit/state, and Task 5's screen — no field renames across tasks. `IFilesRepository.listFiles(String) -> Future<List<FileEntry>>` / `readFile(String) -> Future<List<int>>` (Task 3) match the calls made in Task 4 (`listFiles`) and Task 6 (`readFile`) exactly. `FileBrowserCubit.open/navigateInto/navigateUp` (Task 4) match the calls made in Task 5's widget and Task 7's route wiring (`..open('')`). `FileBrowserScreen({required onOpenFile})` (Task 5) matches Task 7's route wiring, which supplies `onOpenFile: (context, path) => AppNavigation.toFileViewer(context, path)`. `FileViewerScreen({required path, required repository})` (Task 6) matches Task 7's route wiring, which supplies `repository: getIt<IFilesRepository>()`.
