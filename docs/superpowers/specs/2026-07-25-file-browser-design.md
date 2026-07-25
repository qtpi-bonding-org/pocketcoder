# File Browser — Design

## 1. Why this exists

Backend has exactly one file-related route today: `GET /api/pocketcoder/files/{path...}` (`services/pocketbase/internal/filesystem/filesystem.go:35-78`) — auth-gated, path-sanitized, streams a single file's bytes given its exact path. There is no way to discover *what* files exist; nothing lists a directory anywhere in the backend (confirmed via grep for `ReadDir`/`WalkDir` — zero hits outside the vendored PocketBase library itself).

Flutter has zero file-browsing UI. A previous single-file viewer (`FileScreen`, `lib/presentation/files/file_screen.dart`) existed but was deleted in commit `9f017712b` as collateral damage when the old pre-Goose `ChatCubit`/`ChatRepository` runtime was ripped out (it depended on `ChatCubit.fetchFileContent()`, which no longer exists). Dead markers were deliberately left behind — `AppRoutes.files = '/files'` and `AppNavigation.toFiles()` (`lib/app_router.dart:226`, `310-311`) are defined but the route itself is never registered in `AppRouter`'s `routes:` list, so invoking it today 404s via the router's `errorBuilder`. Commit `3e5772f8a` explicitly left these as a "come back and build this" marker rather than deleting them outright.

ACP does not help here: Goose's ACP capabilities are limited to `fs/read_text_file`/`fs/write_text_file` (the agent already knows the exact path when it calls these — precedent confirmed while investigating this feature). There is no `fs/list` method in the ACP protocol, and PocketCoder doesn't even advertise the `Fs` capability to Goose today (`coordinator/run.go:554-560` advertises only `Elicitation`). Directory listing must be a new PocketBase REST endpoint — there is no protocol shortcut.

There is exactly one workspace today: the `goose_workspace` Docker volume, mounted at `/workspace` in both `goose` and `pocketbase` containers (`docker-compose.yml:14`, `80-81`), shared globally across every chat/session — the same assumption the existing single-file endpoint already makes (it takes no chat/session identifier). This feature does not change that; it exposes the same shared, global, read-only workspace that the single-file endpoint already reads from.

## 2. Scope

Add a read-only file browser: a new backend directory-listing endpoint, and a new Flutter list screen + file viewer screen, entered via a `FILES` button on the chat screen header.

**In scope:** listing a directory's immediate children (files + subdirectories), navigating into subdirectories and back up, opening a file to view its contents (text rendered as monospace, common image types rendered as an image, anything else shown as an unsupported-type message).

**Out of scope (§7):** upload/delete/rename/edit, search, per-chat/per-session workspace scoping, syntax highlighting.

## 3. Architecture

### 3.1 Backend — `services/pocketbase/internal/filesystem/filesystem.go`

Add a second route, `RegisterFilesApi` gains a sibling registration in the same function, reusing the exact same auth gate and path sanitization already on lines 37-51:

```go
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
```

Note the empty-path case: unlike the single-file endpoint (which rejects an empty path as a bad request, since you can't read "no file"), listing the workspace root is the primary entry point, so `path=""` is valid here and maps to `cleanPath = "."`, `prefix = ""`.

`fsys.List(prefix)` is PocketBase's own already-imported `filesystem.System.List` method (`github.com/pocketbase/pocketbase/tools/filesystem`, vendored at `tools/filesystem/filesystem.go:178-197`) — it wraps the underlying blob store's `bucket.List(&blob.ListOptions{Prefix: prefix})` and returns every object whose key starts with `prefix`, **recursively** (no delimiter support), as `[]*blob.ListObject{Key, IsDir, Size, ModTime}`. No new dependency and no change to the vendored library is needed — `groupImmediateChildren` derives immediate-children-only semantics from that flat recursive list in plain Go:

Requires three additions to the existing import block (lines 22-31 today have no `sort`, `time`, or `blob` imports):

```go
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
```

```go
type fileEntry struct {
	Name    string `json:"name"`
	IsDir   bool   `json:"isDir"`
	Size    int64  `json:"size"`
	ModTime string `json:"modTime"`
}

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
```

Response shape:

```json
{
  "path": "src",
  "entries": [
    {"name": "internal", "isDir": true, "size": 0, "modTime": ""},
    {"name": "main.go", "isDir": false, "size": 1203, "modTime": "2026-07-25T10:00:00Z"}
  ]
}
```

This is a **custom REST endpoint, not a PocketBase collection** — same category as the existing `skills/list`/`schedules/list` endpoints (`services/pocketbase/internal/...` handlers backing `ApiEndpoints.skillsList`/`schedulesList`). It is intentionally **not** run through `scripts/generate_models.py` / the Model Generation Pipeline in root `CLAUDE.md` — that pipeline generates Dart models from `pb_migrations/schema.json` collection definitions only (confirmed by reading `generate_models.py`: it reads `assets/pb_schema.json` and iterates collections, with no concept of ad hoc endpoint response shapes). The Flutter-side response type is a hand-written `@freezed` model, matching how `Skill` (`lib/domain/models/skill.dart`) is hand-written for the equally non-collection-backed `skills/list` endpoint.

### 3.2 Flutter — `client/packages/pocketcoder_flutter/`

**Endpoint constant** (`lib/infrastructure/core/api_endpoints.dart`), alongside the existing `files(path)` at line 35:

```dart
/// GET /api/pocketcoder/files-list/{path}
/// Lists the immediate children of a workspace directory.
static String filesList(String path) => '/api/pocketcoder/files-list/$path';
```

**Domain model** (new `lib/domain/models/file_entry.dart`, hand-written freezed — see §3.1 on why this isn't generator output):

```dart
@freezed
sealed class FileEntry with _$FileEntry {
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

**Repository** (new `lib/domain/files/i_files_repository.dart` + `lib/infrastructure/files/files_repository.dart`, mirrors `ISkillsRepository`/`SkillsRepository`):

```dart
abstract class IFilesRepository {
  Future<List<FileEntry>> listFiles(String path);
  Future<List<int>> readFile(String path);
}
```

`listFiles` uses `_pb.send<dynamic>(ApiEndpoints.filesList(path), method: 'GET')` — the response-decoding shape (pull a named key out of the JSON map, decode into a list of models) matches `SkillsRepository.listSkills()` (`lib/infrastructure/skills/skills_repository.dart:18-24`), which decodes `response['skills']`; the HTTP verb differs (`listSkills` is a `POST` with an empty body, since its backend route is POST-only) since the new backend route here is GET-only.

`readFile` cannot use `_pb.send` — that method is built for JSON bodies, and the underlying endpoint streams raw bytes with a `Content-Type` header PocketBase's client doesn't special-case. It uses the `http` package (already a pubspec dependency). The `Authorization: Bearer ${_pb.authStore.token}` header-attachment pattern is established precedent — both `lib/infrastructure/observability/observability_repository.dart:25-32` and `lib/infrastructure/agent/agent_stream_client.dart:81-92` pull the token from `_pb.authStore.token` this way — but neither does a plain `http.get`/`bodyBytes` call: `observability_repository.dart` uses the `flutter_client_sse` package's `SSEClient.subscribeToSSE(...)`, and `agent_stream_client.dart` builds an `http.Request` and calls `_http.send(request)` for a streamed response. `readFile` is simpler than both — a one-shot, non-streamed fetch — so it uses `http.get(uri, headers: {'Authorization': 'Bearer ${_pb.authStore.token}'})` directly and returns `response.bodyBytes`; this specific call shape has no existing precedent in the codebase to copy, only the token-header pattern does.

New exception type `FilesException` in `lib/domain/exceptions.dart`, alongside `SkillsException` (line 87-89):

```dart
class FilesException extends DomainException {
  FilesException(super.message, [super.cause]);
}
```

Both repository methods wrapped in `tryMethod(..., FilesException.new, 'listFiles'|'readFile')`, matching `SkillsRepository`'s pattern exactly.

**State + Cubit** (new `lib/application/files/file_browser_state.dart` + `file_browser_cubit.dart`). Modeled on `AuthState`/`AuthCubit` (`lib/application/system/auth_cubit.dart`) — a single non-union `IUiFlowState`, not a `SkillsState`-style sealed union, because there's one screen with one loading/loaded/error shape, not several distinct named states:

```dart
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

**Screens.** `FileBrowserScreen` (new `lib/presentation/files/file_browser_screen.dart`) follows `SkillsScreen`'s structure (`lib/presentation/skills/skills_screen.dart:20-31`): outer `StatelessWidget` provides `BlocProvider(create: (_) => getIt<FileBrowserCubit>()..open(''))` wrapped in `UiFlowListener<FileBrowserCubit, FileBrowserState>`, inner `_FileBrowserView` renders `PocketCoderShell(title: ..., activePillar: NavPillar.chats, showBack: true, body: ...)`. Body is a `BlocBuilder<FileBrowserCubit, FileBrowserState>` showing the current path as a header line and a `ListView` of `state.entries`: directories get a folder glyph and `onTap: () => context.read<FileBrowserCubit>().navigateInto(entry.name)`; files get a file glyph and `onTap` pushes `AppRoutes.fileViewer` with the full path. Empty `entries` (and not loading) renders a "no files" message, matching `SkillsScreen`'s `skills.isEmpty` branch (lines 87-96).

`FileViewerScreen` (new `lib/presentation/files/file_viewer_screen.dart`) takes a `path` and is its own small `StatefulWidget` that calls `getIt<IFilesRepository>().readFile(path)` in `initState` (no cubit needed — this is a one-shot fetch-and-render with no further user interaction, unlike the browser list which has navigation state). While loading: `TerminalLoadingIndicator`. On success: if `path` ends in `.png`/`.jpg`/`.jpeg`/`.gif`/`.webp` (case-insensitive), `Image.memory(Uint8List.fromList(bytes))`; else attempt `utf8.decode(bytes)` in a try/catch — on success render as monospace `SelectableText` inside a scrollable container (matching the terminal aesthetic — reuse `TerminalText`'s monospace font family); on `FormatException` (binary/non-UTF-8), render a centered "Can't preview this file type" message. On fetch error: existing generic error-toast pattern via a plain `catchError`/`setState` (no `UiFlowListener` here since there's no cubit).

**Routing** (`lib/app_router.dart`): register the already-defined-but-unregistered `AppRoutes.files` as a `GoRoute` pointing at `FileBrowserScreen`, in the routes list. Add a new `AppRoutes.fileViewer = '/files/view'` + `RouteNames.fileViewer = 'fileViewer'`, registered as a `GoRoute` reading the file path from a query parameter (`state.uri.queryParameters['path']`) rather than a path segment — file paths contain `/`, which don't survive as a single path-segment parameter cleanly. This has direct precedent in this exact file: `AppNavigation.toDeploymentDetails` (`lib/app_router.dart:322-328`) already does `context.pushNamed(RouteNames.deploymentDetails, queryParameters: {'instanceId': instanceId})`. Follow that same `pushNamed(..., queryParameters: {...})` form rather than manual string concatenation — it handles encoding automatically: `AppNavigation.toFileViewer(BuildContext context, String path) => context.pushNamed(RouteNames.fileViewer, queryParameters: {'path': path})`, alongside the existing `toFiles` (line 310-311).

**Entry point** (`lib/presentation/chat/chat_screen.dart:129-135`): add a `FILES` button to the existing `extraHeaderActions` list, alongside the conditional `CANCEL` button — same `TerminalAction` shape, unconditional (always shown, not gated on `isRunning`):

```dart
extraHeaderActions: [
  TerminalAction(
    label: 'FILES',
    onTap: () => AppNavigation.toFiles(context),
  ),
  if (isRunning)
    TerminalAction(
      label: 'CANCEL',
      onTap: () => context.read<ChatCubit>().cancel(),
    ),
],
```

New ARB keys (dot-notation source → generated camelCase, per `client/CLAUDE.md`): `files.title` → `filesTitle`, `files.empty` → `filesEmpty`, `files.unsupported_type` → `filesUnsupportedType`, `chat.files_button` → `chatFilesButton` (label text, replacing the inline `'FILES'` string literal above once ARB keys exist — matches how `CANCEL`'s label is currently also an inline string, so this stays consistent with existing (non-localized) precedent in that exact call site rather than introducing a new inconsistency).

## 4. Data flow

**Browsing:** user taps `FILES` on the chat screen → `AppNavigation.toFiles` pushes `AppRoutes.files` → `FileBrowserScreen` mounts, `FileBrowserCubit.open('')` fires → `IFilesRepository.listFiles('')` → `GET /api/pocketcoder/files-list/` → backend lists workspace root → `FileBrowserState` updates with `entries` → `ListView` renders. Tapping a directory entry calls `navigateInto(name)` → `open('$path/$name')` → same flow with the new path. Tapping a file entry pushes `FileViewerScreen(path: ...)`.

**Viewing:** `FileViewerScreen.initState` calls `readFile(path)` → authenticated `http.get` against `GET /api/pocketcoder/files/{path}` (the pre-existing single-file endpoint, unchanged) → bytes returned → extension-based dispatch to image/text/unsupported rendering, as described in §3.2.

No drift cache, no offline mirror — this is live-fetch-only read data, matching the existing single-file endpoint's usage pattern (nothing today caches file bytes locally).

## 5. Error handling

- **Empty/nonexistent directory:** `fsys.List(prefix)` on a path with no matching keys returns an empty slice, not an error — the endpoint returns `200` with `entries: []`; the UI's existing empty-state branch handles this the same as an actually-empty directory. (A typo'd path and a genuinely empty directory are indistinguishable this way — accepted, since directory *existence* isn't separately tracked by the blob storage abstraction being used; this matches the read side of the existing file endpoint, which also can't distinguish "no such file" from other failure modes beyond a generic 404.)
- **Path escape attempt** (`..`, leading `/`): `403 Forbidden`, same sanitization and error message as the existing single-file endpoint — surfaces as a `FilesException` → generic toast via `UiFlowListener`'s error path (same mechanism `AuthCubit`/`SkillsCubit` failures already use).
- **Binary file opened in viewer:** `utf8.decode` throws `FormatException`, caught, renders the "can't preview" message — no crash, no exception propagates to a toast (this is expected/routine, not an error state).
- **Network/auth failure on `readFile`:** caught in `FileViewerScreen`'s fetch, rendered as an inline error message in the viewer body (no cubit/`UiFlowListener` available here since `FileViewerScreen` deliberately has no cubit — see §3.2 for why).

## 6. Testing

**Backend** (`services/pocketbase/internal/filesystem/`):
- Unit test for `groupImmediateChildren`: flat multi-level `[]*blob.ListObject` input → asserts correct immediate-children-only output (files and one-level-deep directories, deeper nesting collapsed into a single directory entry, sorted, deduped).
- `httptest`-based route test in a new `filesystem_test.go` (`services/pocketbase/internal/filesystem/` currently has no test file — this is a new file, not an extension of an existing one): unauthenticated request → 403; path escape (`../etc`) → 403; empty path → 200 with root listing; nonexistent path → 200 with empty entries (per §5).

**Flutter:**
- `FileBrowserCubit` unit tests: `open` success populates `entries`/`path` and sets `status: success`; `open` failure sets `status: failure` with `error`; `navigateInto` and `navigateUp` compute the expected next path and delegate to `open` (verify via a fake `IFilesRepository` capturing the path argument).
- `FileBrowserScreen` widget test (`theme: AppTheme.lightTheme` set explicitly on the test `MaterialApp` — required per this project's known past bug where an omitted theme crashes instead of failing red): entries render as tappable rows; tapping a directory row calls `navigateInto`; tapping a file row navigates to the viewer route; empty `entries` renders the empty-state message.
- `FileViewerScreen` widget test (same theme requirement): text content renders as `SelectableText`; a `.png` path renders `Image.memory`; a byte sequence that fails `utf8.decode` renders the unsupported-type message.

## 7. Out of scope

- Upload, delete, rename, or any write operation — this feature is read-only, matching the existing single-file endpoint's read-only nature.
- Search / filtering within the browser.
- Per-chat or per-session workspace scoping — the workspace is a single global volume today (§1); introducing scoping is a separate, larger change (would need Goose/session-to-directory mapping that doesn't exist yet) and isn't needed for this feature to be useful.
- Syntax highlighting in the text viewer — plain monospace text only.
- Any change to the existing single-file endpoint (`GET /api/pocketcoder/files/{path}`) — it's reused as-is for `readFile`.
