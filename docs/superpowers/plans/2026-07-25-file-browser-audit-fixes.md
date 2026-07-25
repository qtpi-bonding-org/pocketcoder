# File Browser Audit Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the 5 real bugs (2 backend, 3 Flutter) found by the 2026-07-25 code-only audit of the file browser feature — a symlink-traversal vulnerability, a listing-order bug, a missing test gap, and two Flutter `readFile()` bugs (silent error-body-as-content, malformed auth header) plus a large-file OOM risk.

**Architecture:** No new subsystems. All fixes are localized to the two files the audit flagged: `services/pocketbase/internal/filesystem/filesystem.go` (+ its test file) on the backend, and `files_repository.dart` / `file_viewer_screen.dart` on the Flutter client. The backend fix introduces one new package-level helper (`resolveWorkspacePath`) and one new package variable (`workspaceRoot`, overridable in tests) so symlink resolution can be tested against a real temp directory instead of the hardcoded `/workspace`.

**Tech Stack:** Go 1.x / PocketBase v0.36.1 (backend), Flutter/Dart with mocktail + flutter_test (client). No new dependencies.

## Global Constraints

- Never use `!` (force-unwrap) in Dart — use `?.`, `??`, or `requireNonNull` (client/CLAUDE.md).
- Every Flutter repository method stays wrapped in `tryMethod`; exceptions stay typed (`FilesException`) per client/CLAUDE.md's Repository/Service Pattern.
- Never hardcode user-facing strings in Flutter — use `context.l10n` + ARB keys (client/CLAUDE.md Localization).
- TDD throughout: write the failing test, watch it fail for the right reason, write minimal code, watch it pass.
- Audit source of truth: `audit/2026-07-25-file-browser-diff-summaries/01-backend-files-endpoint.md` and `.../02-flutter-file-browser.md` (gitignored, local-only — read them for full context, but this plan is self-contained).

---

## Task 1: Backend — reject symlinks that escape the workspace root

**Files:**
- Modify: `services/pocketbase/internal/filesystem/filesystem.go`
- Test: `services/pocketbase/internal/filesystem/filesystem_test.go`

**Interfaces:**
- Produces: `var workspaceRoot = "/workspace"` (package-level, overridable in tests) and `func resolveWorkspacePath(pathParam string) (cleanPath string, ok bool)` — cleans and validates `pathParam`, returns `ok=false` if it would escape `workspaceRoot` (via `..`, a leading `/`, or a symlink). Task 3's HTTP-level tests reuse `workspaceRoot`.

### Context

Both routes in `filesystem.go` currently do:
```go
cleanPath := filepath.Clean(pathParam)
if strings.HasPrefix(cleanPath, "..") || strings.HasPrefix(cleanPath, "/") {
    return re.ForbiddenError("Path escape attempt detected.", nil)
}
fsys, err := filesystem.NewLocal("/workspace")
```
This blocks `..`-based traversal but not symlinks: if `/workspace/escape` is a symlink to somewhere outside `/workspace`, `fsys.GetReader("escape")` / `fsys.List("escape/")` follow it and serve files outside the intended root.

- [ ] **Step 1: Write the failing test for `resolveWorkspacePath`**

Add to `services/pocketbase/internal/filesystem/filesystem_test.go` (new imports: `os`, `path/filepath`):

```go
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -run TestResolveWorkspacePath -v`
Expected: FAIL — `undefined: resolveWorkspacePath` / `undefined: workspaceRoot` (compile error, since neither exists yet).

- [ ] **Step 3: Implement `workspaceRoot` and `resolveWorkspacePath`, wire both routes to use them**

In `services/pocketbase/internal/filesystem/filesystem.go`, add the import and the new declarations right after the existing `fileEntry` struct (before `groupImmediateChildren`):

```go
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
```

Then replace the sanitization + `filesystem.NewLocal("/workspace")` block in the **first route** (`/api/pocketcoder/files/{path...}`):

```go
			// 2. Resolve Path
			pathParam := re.Request.PathValue("path")
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
```

And the **second route** (`/api/pocketcoder/files-list/{path...}`):

```go
			pathParam := re.Request.PathValue("path")
			cleanPath, ok := resolveWorkspacePath(pathParam)
			if !ok {
				return re.ForbiddenError("Path escape attempt detected.", nil)
			}

			fsys, err := filesystem.NewLocal(workspaceRoot)
```

(`filepath.Clean("")` already returns `"."`, so `resolveWorkspacePath("")` returns `cleanPath="."` — the old `if pathParam != ""` special-case is no longer needed and is dropped.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -run TestResolveWorkspacePath -v`
Expected: PASS (all 6 new tests green).

- [ ] **Step 5: Run the full filesystem package test suite to check for regressions**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -v`
Expected: PASS (existing `TestGroupImmediateChildren_*` tests still green).

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/filesystem/filesystem.go services/pocketbase/internal/filesystem/filesystem_test.go
git commit -m "fix(backend): reject symlinks that escape the workspace root in file endpoints"
```

---

## Task 2: Backend — fix listing-order-dependent file/directory conflict in `groupImmediateChildren`

**Files:**
- Modify: `services/pocketbase/internal/filesystem/filesystem.go`
- Test: `services/pocketbase/internal/filesystem/filesystem_test.go`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: no new exported names — `groupImmediateChildren`'s existing signature (`func groupImmediateChildren(prefix string, objects []*blob.ListObject) []fileEntry`) is unchanged, only its internal conflict resolution changes.

### Context

`groupImmediateChildren` dedupes by first-occurrence: if the flat listing contains both `"src"` (as its own key) and `"src/a.go"` (implying `src` is a directory), whichever is processed first wins — so a reversed listing order can incorrectly mark a directory as a file.

- [ ] **Step 1: Write the failing test**

Add to `services/pocketbase/internal/filesystem/filesystem_test.go`:

```go
func TestGroupImmediateChildren_ConflictResolvesToDirRegardlessOfOrder(t *testing.T) {
	mod := time.Date(2026, 7, 25, 10, 0, 0, 0, time.UTC)

	fileFirst := []*blob.ListObject{
		{Key: "src", Size: 5, ModTime: mod},
		{Key: "src/a.go", Size: 10, ModTime: mod},
	}
	got := groupImmediateChildren("", fileFirst)
	if len(got) != 1 || got[0].Name != "src" || !got[0].IsDir {
		t.Fatalf("file-first order: got %+v, want single dir entry named src", got)
	}
	if got[0].Size != 0 {
		t.Fatalf("file-first order: directory entry Size = %d, want 0", got[0].Size)
	}

	dirFirst := []*blob.ListObject{
		{Key: "src/a.go", Size: 10, ModTime: mod},
		{Key: "src", Size: 5, ModTime: mod},
	}
	got = groupImmediateChildren("", dirFirst)
	if len(got) != 1 || got[0].Name != "src" || !got[0].IsDir {
		t.Fatalf("dir-first order: got %+v, want single dir entry named src", got)
	}
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -run TestGroupImmediateChildren_ConflictResolvesToDirRegardlessOfOrder -v`
Expected: FAIL on the `fileFirst` case — `got[0].IsDir` is `false` because `"src"` was recorded first and `"src/a.go"` was silently skipped as a duplicate.

- [ ] **Step 3: Fix the dedup logic to promote to directory on any conflicting signal**

Replace the loop body of `groupImmediateChildren` in `services/pocketbase/internal/filesystem/filesystem.go`:

```go
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -run TestGroupImmediateChildren_ConflictResolvesToDirRegardlessOfOrder -v`
Expected: PASS.

- [ ] **Step 5: Run the full filesystem package test suite to check for regressions**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -v`
Expected: PASS (all tests, including Task 1's, still green).

- [ ] **Step 6: Commit**

```bash
git add services/pocketbase/internal/filesystem/filesystem.go services/pocketbase/internal/filesystem/filesystem_test.go
git commit -m "fix(backend): resolve file/dir conflicts in groupImmediateChildren regardless of listing order"
```

---

## Task 3: Backend — add HTTP-level route tests (auth gate, symlink rejection, happy path)

**Files:**
- Test: `services/pocketbase/internal/filesystem/filesystem_test.go`

**Interfaces:**
- Consumes: `workspaceRoot` and `resolveWorkspacePath` from Task 1 (must be committed first — this task is a pure test addition, no production code changes).

### Context

The existing test file only unit-tests `groupImmediateChildren`; neither HTTP route (`RegisterFilesApi`'s auth gate, path sanitization, or symlink rejection) is exercised end-to-end. PocketBase ships `github.com/pocketbase/pocketbase/tests.ApiScenario` for exactly this — it spins up a real `TestApp`, triggers `OnServe` (so `RegisterFilesApi` can register its routes via a `BeforeTestFunc`), and dispatches a real `httptest` request through the router.

`RegisterFilesApi(app *pocketbase.PocketBase, e *core.ServeEvent)`'s `app` parameter is never read inside the function body (only `e.Router.GET(...)` is used), so it's safe to pass `nil` for it in tests — no adapter needed between `*tests.TestApp` and `*pocketbase.PocketBase`.

Auth: `.Bind(apis.RequireAuth())` rejects an unauthenticated request with **401** (not 403 — `apis.RequireAuth()`'s internal check runs before the handler's own `re.Auth == nil` branch ever executes, and it calls `e.UnauthorizedError(...)`). A valid token comes from `user.NewAuthToken()` on a `core.Record` created against the `_pb_users_auth_` collection — this exact pattern is already used in `services/pocketbase/internal/api/schedules_test.go`'s `newTestUser` helper.

- [ ] **Step 1: Write the new test file additions (these are the tests — there's no separate "watch it fail" production code to write first, since this task adds no production code; instead verify each test fails for the right reason against the *current* — Task 1/2-fixed — code before it's correct, per Step 2)**

Add to `services/pocketbase/internal/filesystem/filesystem_test.go` (new imports: `net/http`, `github.com/pocketbase/pocketbase/core`, `github.com/pocketbase/pocketbase/tests`, blank-import `_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"`):

```go
import (
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem/blob"

	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func newFilesTestUser(t *testing.T, app core.App, email string) *core.Record {
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

func TestFilesListEndpoint_RequiresAuth(t *testing.T) {
	withTestWorkspaceRoot(t, t.TempDir())

	scenario := tests.ApiScenario{
		Name:            "files-list without auth is rejected",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/files-list/",
		ExpectedStatus:  401,
		ExpectedContent: []string{"requires valid record authorization token"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterFilesApi(nil, e)
		},
	}
	scenario.Test(t)
}

func TestFilesReadEndpoint_RequiresAuth(t *testing.T) {
	withTestWorkspaceRoot(t, t.TempDir())

	scenario := tests.ApiScenario{
		Name:            "files read without auth is rejected",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/files/main.go",
		ExpectedStatus:  401,
		ExpectedContent: []string{"requires valid record authorization token"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterFilesApi(nil, e)
		},
	}
	scenario.Test(t)
}

func TestFilesListEndpoint_ReturnsImmediateChildren(t *testing.T) {
	dir := t.TempDir()
	withTestWorkspaceRoot(t, dir)
	if err := os.WriteFile(filepath.Join(dir, "main.go"), []byte("package main"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(filepath.Join(dir, "internal"), 0o755); err != nil {
		t.Fatal(err)
	}

	scenario := tests.ApiScenario{
		Name:            "files-list returns immediate children as JSON",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/files-list/",
		Headers:         map[string]string{},
		ExpectedStatus:  200,
		ExpectedContent: []string{`"name":"main.go"`, `"name":"internal"`, `"isDir":true`},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterFilesApi(nil, e)
			user := newFilesTestUser(t, app, "files-list@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			scenario.Headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}

func TestFilesListEndpoint_RejectsSymlinkEscape(t *testing.T) {
	root := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.txt"), []byte("top secret"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(root, "escape")); err != nil {
		t.Fatal(err)
	}
	withTestWorkspaceRoot(t, root)

	scenario := tests.ApiScenario{
		Name:            "files-list rejects a symlink that escapes the workspace root",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/files-list/escape",
		Headers:         map[string]string{},
		ExpectedStatus:  403,
		ExpectedContent: []string{"escape attempt"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterFilesApi(nil, e)
			user := newFilesTestUser(t, app, "symlink-escape@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			scenario.Headers["Authorization"] = token
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

	scenario := tests.ApiScenario{
		Name:            "files read rejects a symlink that escapes the workspace root",
		Method:          http.MethodGet,
		URL:             "/api/pocketcoder/files/escape/secret.txt",
		Headers:         map[string]string{},
		ExpectedStatus:  403,
		ExpectedContent: []string{"escape attempt"},
		BeforeTestFunc: func(t testing.TB, app *tests.TestApp, e *core.ServeEvent) {
			RegisterFilesApi(nil, e)
			user := newFilesTestUser(t, app, "read-symlink-escape@example.com")
			token, err := user.NewAuthToken()
			if err != nil {
				t.Fatal(err)
			}
			scenario.Headers["Authorization"] = token
		},
	}
	scenario.Test(t)
}
```

(Note: `withTestWorkspaceRoot` was already added in Task 1, so it is not redefined here.)

- [ ] **Step 2: Run the new tests**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -run 'TestFilesListEndpoint|TestFilesReadEndpoint' -v`
Expected: PASS on all 5 — since Task 1 and Task 2's production fixes are already in place, these HTTP-level tests confirm the fix end-to-end rather than catching a regression. (If Task 1 is skipped or reverted, `TestFilesListEndpoint_RejectsSymlinkEscape` and `TestFilesReadEndpoint_RejectsSymlinkEscape` are the ones that would fail — that's the point of this task.)

- [ ] **Step 3: Run the full filesystem package test suite**

Run: `cd services/pocketbase && go test ./internal/filesystem/... -v`
Expected: PASS (all tests from Tasks 1-3 green).

- [ ] **Step 4: Commit**

```bash
git add services/pocketbase/internal/filesystem/filesystem_test.go
git commit -m "test(backend): add HTTP-level route tests for files/files-list auth gate and symlink rejection"
```

---

## Task 4: Flutter — `readFile()` checks HTTP status and rejects a missing auth token

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/files/files_repository.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/files/files_repository_test.dart`

**Interfaces:**
- Consumes: nothing from Tasks 1-3 (independent Flutter-side fix).
- Produces: `FilesException.httpError(int statusCode)` and `FilesException.noAuthToken()` factory constructors, callable by later Flutter code (none needed by this plan, but they follow the same factory pattern as `RepositoryException` in the same file).

### Context

`FilesRepository.readFile()` currently does:
```dart
final response = await _http.get(
  uri,
  headers: {'Authorization': _pb.authStore.token},
);
return response.bodyBytes;
```
Two bugs: (1) it never checks `response.statusCode`, so a 401/403/404/500 error body is returned and rendered as if it were the file's actual content; (2) `_pb.authStore.token` is a **non-nullable** `String` in the `pocketbase` package (`pubspec.yaml` pins `pocketbase: ^0.23.2`; `AuthStore.token` defaults to `""` when unauthenticated, it is never Dart `null` — verified by reading `pocketbase-0.23.3/lib/src/auth_store.dart`). So the real bug is an **empty-string** token, not a null one: `_pb.authStore.token` is used unchecked, so an unauthenticated/expired session sends the literal empty header `Authorization: ` instead of failing with a clear error. (`requireNonNull` doesn't apply here since there's nothing nullable to guard — this is a plain `isEmpty` check.)

- [ ] **Step 1: Write the failing tests**

Add to `client/packages/pocketcoder_flutter/test/infrastructure/files/files_repository_test.dart`, inside the existing `group('FilesRepository.readFile', ...)` block:

```dart
    test('throws FilesException on a non-2xx status instead of returning the error body', () async {
      when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
        (_) async => http.Response('Forbidden', 403),
      );

      await expectLater(
        () => repo.readFile('main.go'),
        throwsA(isA<FilesException>()),
      );
    });

    test('throws FilesException without making a request when the auth token is empty', () async {
      when(() => authStore.token).thenReturn('');

      await expectLater(
        () => repo.readFile('main.go'),
        throwsA(isA<FilesException>()),
      );
      verifyNever(() => httpClient.get(any(), headers: any(named: 'headers')));
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/files/files_repository_test.dart`
Expected: FAIL — the "non-2xx status" test fails because `repo.readFile('main.go')` resolves with `[70, 111, 114, 98, 105, 100, 100, 101, 110]` (the bytes of `"Forbidden"`) instead of throwing; the "empty auth token" test fails because the call proceeds straight to the mocked `httpClient.get` (which isn't stubbed for this test, so it throws a mocktail `MissingStubError` — still not the expected `FilesException`), so both `expectLater` and `verifyNever` fail.

- [ ] **Step 3: Add the exception factories**

In `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`, replace the existing `FilesException` class:

```dart
/// Files-related exceptions.
class FilesException extends DomainException {
  FilesException(super.message, [super.cause]);

  factory FilesException.httpError(int statusCode) =>
      FilesException('Request failed with status $statusCode');
  factory FilesException.noAuthToken() =>
      FilesException('No auth token available');
}
```

- [ ] **Step 4: Fix `readFile()`**

In `client/packages/pocketcoder_flutter/lib/infrastructure/files/files_repository.dart`, replace `readFile()` (no new imports needed — `tryMethod` is already imported):

```dart
  @override
  Future<List<int>> readFile(String path) async {
    return tryMethod(
      () async {
        final token = _pb.authStore.token;
        if (token.isEmpty) {
          throw FilesException.noAuthToken();
        }
        final uri = Uri.parse('${_pb.baseURL}${ApiEndpoints.files(path)}');
        final response = await _http.get(uri, headers: {'Authorization': token});
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw FilesException.httpError(response.statusCode);
        }
        return response.bodyBytes;
      },
      FilesException.new,
      'readFile',
    );
  }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/files/files_repository_test.dart`
Expected: PASS (all tests in the file, including the two new ones and the three pre-existing ones).

- [ ] **Step 6: Run the full Flutter test suite to check for regressions**

Run: `cd client/packages/pocketcoder_flutter && flutter test`
Expected: PASS (no other file references the old `FilesException` shape or the removed unchecked-token behavior).

- [ ] **Step 7: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/infrastructure/files/files_repository.dart client/packages/pocketcoder_flutter/lib/domain/exceptions.dart client/packages/pocketcoder_flutter/test/infrastructure/files/files_repository_test.dart
git commit -m "fix(flutter): reject non-2xx responses and null auth tokens in FilesRepository.readFile"
```

---

## Task 5: Flutter — guard against OOM on large files in the viewer, and localize its fallback strings

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/files/file_viewer_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`
- Test: `client/packages/pocketcoder_flutter/test/presentation/files/file_viewer_screen_test.dart`

**Interfaces:**
- Consumes: nothing from Tasks 1-4.
- Produces: no new interfaces — internal widget behavior change plus two new ARB keys (`filesTooLargeToPreview`, `filesCantPreviewType`) consumed only within this file.

### Context

`_buildBody` currently calls `utf8.decode(bytes)` on the full byte array with no size check, so a very large file can exhaust memory before the `on FormatException` binary-fallback branch is ever reached (that branch only catches invalid-UTF-8, not size). Two of its user-facing strings (`"CAN'T PREVIEW THIS FILE TYPE"` and `'ERROR: $error'`) are hardcoded instead of using `context.l10n`, per client/CLAUDE.md's localization rule — this task folds in a fix for the first (a genuinely static string) while leaving the second (`'ERROR: $error'`) as-is, since it interpolates a runtime exception object rather than being a pure static string, and templating the *label* portion (`"ERROR: "`) without a matching test assertion elsewhere is not exercised by the audit — out of scope here.

- [ ] **Step 1: Write the failing test**

Add to `client/packages/pocketcoder_flutter/test/presentation/files/file_viewer_screen_test.dart`:

```dart
  testWidgets('shows a too-large message instead of decoding a huge file', (tester) async {
    final hugeBytes = Uint8List(11 * 1024 * 1024); // 11 MB, over the 10 MB cap
    when(() => repo.readFile('huge.log')).thenAnswer((_) async => hugeBytes);

    await tester.pumpWidget(
        _wrap(FileViewerScreen(path: 'huge.log', repository: repo)));
    await tester.pumpAndSettle();

    expect(find.textContaining('TOO LARGE'), findsOneWidget);
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/files/file_viewer_screen_test.dart`
Expected: FAIL — no widget contains text matching `'TOO LARGE'`; instead the 11 MB zero-filled byte array successfully UTF-8-decodes (all null bytes are valid UTF-8) and renders as `SelectableText`.

- [ ] **Step 3: Add the ARB keys**

In `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`, add next to the existing `filesTitle`/`filesEmpty` keys:

```json
  "filesTitle": "FILES",
  "filesEmpty": "NO FILES",
  "filesTooLargeToPreview": "FILE TOO LARGE TO PREVIEW",
  "filesCantPreviewType": "CAN'T PREVIEW THIS FILE TYPE",
```

Run: `cd client/packages/pocketcoder_flutter && flutter gen-l10n`
This regenerates `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_en.dart` with `filesTooLargeToPreview` and `filesCantPreviewType` getters.

- [ ] **Step 4: Add the size guard and use the new l10n keys**

In `client/packages/pocketcoder_flutter/lib/presentation/files/file_viewer_screen.dart`, add a constant near the top of the file (after `_imageExtensions`):

```dart
const _maxPreviewBytes = 10 * 1024 * 1024; // 10 MB
```

Replace the tail of `_buildBody`:

```dart
    if (_isImage) {
      return Center(child: Image.memory(bytes));
    }
    if (bytes.length > _maxPreviewBytes) {
      return Center(
        child: TerminalText(context.l10n.filesTooLargeToPreview, alpha: 0.5),
      );
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
        child: TerminalText(context.l10n.filesCantPreviewType, alpha: 0.5),
      );
    }
```

`context.l10n` needs `client/packages/pocketcoder_flutter/lib/design_system/theme/app_theme.dart` imported — it already is (line 5 of this file), so no new import is required.

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/files/file_viewer_screen_test.dart`
Expected: PASS (the new too-large test, plus the 3 pre-existing tests in this file — note the existing binary-fallback test asserts on the literal string `"CAN'T PREVIEW THIS FILE TYPE"`, which still matches since the English ARB value is unchanged).

- [ ] **Step 6: Run the full Flutter test suite and analyzer**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze && flutter test`
Expected: both PASS with no errors/warnings.

- [ ] **Step 7: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/files/file_viewer_screen.dart client/packages/pocketcoder_flutter/lib/l10n/app_en.arb client/packages/pocketcoder_flutter/lib/l10n/app_localizations.dart client/packages/pocketcoder_flutter/lib/l10n/app_localizations_en.dart client/packages/pocketcoder_flutter/test/presentation/files/file_viewer_screen_test.dart
git commit -m "fix(flutter): guard against OOM on large files in FileViewerScreen and localize its fallback strings"
```

---

## Final Verification

- [ ] **Backend:** `cd services/pocketbase && go build ./... && go vet ./... && go test ./...`
Expected: all PASS, no vet warnings.

- [ ] **Flutter:** `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`
Expected: all PASS, no analyzer warnings. (`build_runner` is a no-op here since no `@freezed`/`@JsonSerializable` models changed in this plan, but it's the project's standard post-change codegen step per root CLAUDE.md.)
