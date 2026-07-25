# Diff Summaries — Design

## 1. Why this exists

Goose's ACP tool-call results already carry structured diff content — `ToolCallContentDiff{Path, OldText, NewText}` — whenever a tool edits a file. PocketCoder's backend already extracts this and emits it as a dedicated AG-UI CustomEvent, `pocketcoder:diff` (`toolCallId`/`path`/`oldText`/`newText`), on every tool-call diff hunk:

- `services/pocketbase/internal/agent/agui/content.go:39-45` — `ToolDiff` struct, decoded from ACP's `ToolCallContent.Diff` variant.
- `services/pocketbase/internal/agent/agui/bridge.go:204-227` — `toolResult()` emits one `customDiff(id, d)` event per diff hunk in a tool call's result content.
- `services/pocketbase/internal/agent/agui/custom.go:53-61` — `customDiff()` constructs the `pocketcoder:diff` CustomEvent.
- `services/pocketbase/internal/agent/agui/bridge_test.go:286` — covers this path; not incidental or speculative.

Flutter receives and caches every AG-UI event, including these (`AgentChatRepository.ingestOnce`, `lib/infrastructure/agent/agent_chat_repository.dart`, stores every frame via `_cache.upsertEvent` regardless of type). But nothing decodes or renders `pocketcoder:diff`:

- `grep -rn "pocketcoder:diff\|oldText\|newText" client/packages/pocketcoder_flutter/lib` returns zero matches.
- `lib/presentation/chat/tool_call_card.dart` renders a tool call's `name`/`args`/`result` only — no diff awareness.

Net effect: a tool call that edits a file shows `NAME` / `ARGS: ...` / `RESULT: ...` as opaque text. The user can't see what actually changed without reading raw JSON out of the offline cache. **No backend or protocol work is needed** — this is purely a client-side decode + render gap, split across two repos (see §3).

## 2. Scope

Render diff summaries in the existing chat timeline, attached to the tool call that produced them:

- Decode `pocketcoder:diff` CustomEvents into the reduced conversation model, keyed by `toolCallId`.
- Render a compact summary line per diff (`path (+N -M)`, or `NEW FILE` when there's no prior content) inside the existing `ToolCallCard`.
- Tapping a summary line expands an inline unified diff view (+/- colored lines).

Out of scope (see §7).

## 3. Architecture

The reduced timeline model (`Conversation`, `TimelineItem`, `ConversationReducer`) lives in a separate git-dependency repo, **`ag_ui_widgets_flutter`** (pinned by commit `ref` in `client/packages/pocketcoder_flutter/pubspec.yaml:77-80`), not inside `pocketcoder_flutter` itself. This feature therefore touches two repos.

### 3.1 `ag_ui_widgets_flutter` — model + reducer

**New type** (`lib/src/model/conversation.dart`), a small `@freezed` class alongside `TimelineItem`:

```dart
@freezed
class ToolDiff with _$ToolDiff {
  const factory ToolDiff({
    required String path,
    @Default('') String oldText,
    required String newText,
  }) = _ToolDiff;
}
```

**Extend `ToolCallTimelineItem`** (`conversation.dart:35-40`) with a `diffs` field, defaulting to empty so all existing call sites (including `timeline_to_messages.dart`'s pattern match) keep compiling:

```dart
const factory TimelineItem.toolCall({
  required String id,
  required String name,
  @Default('') String args,
  String? result,
  @Default([]) List<ToolDiff> diffs,
}) = ToolCallTimelineItem;
```

**Reducer** (`lib/src/model/conversation_reducer.dart`) — add a new `case` in `ConversationReducer.apply`'s switch, following the exact shape of the existing `isReplaceMarker` special-case (checked before the switch) but as an in-switch case since diffs are per-tool-call, not a global reset:

```dart
case ag_ui.CustomEvent(name: 'pocketcoder:diff'):
  final value = event.value;
  if (value is Map) {
    final toolCallId = value['toolCallId'] as String?;
    final path = value['path'] as String?;
    final newText = value['newText'] as String?;
    if (toolCallId != null && path != null && newText != null) {
      final diff = ToolDiff(
        path: path,
        oldText: (value['oldText'] as String?) ?? '',
        newText: newText,
      );
      _updateTool(toolCallId, (t) => t.copyWith(diffs: [...t.diffs, diff]));
    }
  }
```

This reuses `_updateTool` (`conversation_reducer.dart` — same helper `ToolCallArgsEvent`/`ToolCallResultEvent` already use), which is already a safe no-op if `toolCallId` doesn't match any open tool call (covers out-of-order arrival — see §5). Multiple diffs on the same tool call (e.g. a multi-file edit) each append to the list in arrival order; nothing is ever overwritten.

**`timeline_to_messages.dart`** (`lib/src/widgets/timeline_to_messages.dart:29-34`) — pass `diffs` through into the existing metadata map:

```dart
ToolCallTimelineItem(:final id, :final name, :final args, :final result, :final diffs) =>
  chat_core.Message.custom(
    id: id,
    authorId: kAgentAuthorId,
    metadata: {
      'kind': 'toolCall',
      'name': name,
      'args': args,
      'result': result,
      'diffs': diffs.map((d) => {'path': d.path, 'oldText': d.oldText, 'newText': d.newText}).toList(),
    },
  ),
```

Encoding as `List<Map<String, String>>` (rather than passing `ToolDiff` objects directly) matches the existing metadata map's `Map<String, dynamic>` shape and keeps `chat_core.CustomMessage` (from the third-party `flutter_chat_core` package) decoupled from this package's freezed types.

**Versioning:** after these changes land and are committed/pushed to `ag_ui_widgets_flutter`, bump the pinned `ref:` in `client/packages/pocketcoder_flutter/pubspec.yaml:80` to the new commit SHA, then run `flutter pub get` in `pocketcoder_flutter`.

### 3.2 `pocketcoder_flutter` — diff computation + rendering

**New dependency**: `diff_match_patch` (no diffing library exists in this app today — confirmed via `grep -n "diff" pubspec.yaml` returning nothing). Used to compute a line-based diff between `oldText` and `newText` client-side; the wire payload only ever carries full before/after text, never a pre-computed patch.

**New file** `lib/presentation/chat/diff_summary_view.dart` — two widgets:

- `DiffSummaryLine` — stateless-looking but wraps local expand/collapse state (a `StatefulWidget`, no cubit — this is pure derived-data rendering, not a data-fetching concern `AppCubit` conventions are for). Displays `path.toUpperCase()` + `(+N -M)` computed once via a pure helper (see below), or `NEW FILE` when `oldText.isEmpty`. Tapping toggles an expanded `DiffBody` beneath it.
- `DiffBody` — renders the unified diff as a `Column` of `Text` lines: `-` prefixed lines in `terminalColors.danger` (matching the existing `isDestructive` styling precedent from `BiosListTile`), `+` prefixed lines in `terminalColors.attention` (matching `ToolCallCard`'s existing accent color), unchanged context lines in the default body color. Font: `AppFonts.bodyFamily` at `AppSizes.fontMini`, matching `ToolCallCard`'s existing `RESULT:` text style. Capped at 300 rendered lines with a trailing `"N more lines omitted"` footer in muted text if the diff exceeds that — the `(+N -M)` summary count is always computed from the full uncapped diff.

**New pure helper** `lib/presentation/chat/diff_stats.dart` (or a top-level function in `diff_summary_view.dart` if small enough — decide at implementation time, YAGNI a separate file if it's under ~20 lines): given `oldText`/`newText`, returns `{added: int, removed: int, lines: List<DiffLine>}` where `DiffLine` is `{text: String, kind: added|removed|context}`, built from `diff_match_patch`'s line-mode diff (its `diffLinesToChars`/`diffMain` pairing, the package's documented pattern for line-level rather than character-level diffs).

**`ToolCallCard`** (`lib/presentation/chat/tool_call_card.dart`) — after the existing `RESULT:` block, decode `message.metadata?['diffs'] as List<dynamic>?` and render one `DiffSummaryLine` per entry:

```dart
final diffs = (message.metadata?['diffs'] as List<dynamic>?) ?? const [];
// ...
if (diffs.isNotEmpty) ...[
  VSpace.x1,
  for (final d in diffs)
    DiffSummaryLine(
      path: (d as Map)['path'] as String? ?? '',
      oldText: d['oldText'] as String? ?? '',
      newText: d['newText'] as String? ?? '',
    ),
],
```

## 4. Data flow

Goose ACP tool result (`Diff` content) → `bridge.go` extracts `ToolDiff` → `pocketcoder:diff` CustomEvent → `AgentChatRepository.ingestOnce` caches it like any other frame (no change) → on read, `reduce()`/`ConversationReducer.apply` matches the new case, appends to the matching tool call's `diffs` list by `toolCallId` → `timelineToMessages` copies `diffs` into `CustomMessage.metadata` → `ToolCallCard` renders one collapsed `DiffSummaryLine` per diff → tap computes the unified diff (via `diff_match_patch`) and expands `DiffBody` in place.

No new PocketBase collection, no new repository method, no new cubit — this is a pure read-side rendering pipeline on data that's already flowing and already cached offline.

## 5. Error handling

- **Diff event for an unknown `toolCallId`** (arrived before `ToolCallStartEvent`, or the tool call was evicted from the timeline) — `_updateTool` is already a safe no-op when the id isn't found (existing behavior shared with `args`/`result`); no new handling needed.
- **Malformed event value** (missing `path` or `newText`, non-Map `value`) — the reducer case skips that single event via the null checks shown in §3.1; it never throws.
- **Empty/no-op diff** (`oldText == newText`) — still renders a `(+0 -0)` summary line rather than being hidden, so the user isn't confused by a tool call that silently dropped a diff it reported.
- **New-file diffs** (`oldText` empty) — `DiffSummaryLine` shows `NEW FILE` instead of a `+N -M` count; `DiffBody` renders every line of `newText` as an addition.
- **Very large diffs** — `DiffBody` caps rendered lines at 300 with a footer note, protecting scroll performance on mobile; the summary counts are unaffected by the cap.

## 6. Testing

**`ag_ui_widgets_flutter`:**
- Reducer test: a `pocketcoder:diff` CustomEvent for a known `toolCallId` appends to that item's `diffs`; a second diff event for the same id appends rather than replaces (multi-file-edit case); an event for an unknown id is a no-op (no crash, no orphan entry).
- `timeline_to_messages` test: a `ToolCallTimelineItem` with non-empty `diffs` produces `CustomMessage.metadata['diffs']` with the expected shape.

**`pocketcoder_flutter`:**
- Pure-Dart test for the diff-computation helper: correct `added`/`removed` counts for a simple two-line change; `oldText` empty → all lines counted as added; identical `oldText`/`newText` → zero counts; a diff exceeding 300 lines is truncated in the rendered `DiffLine` list with the omitted-count preserved separately from the summary counts.
- Widget test for `ToolCallCard`: given `metadata['diffs']` with one entry, a `DiffSummaryLine` renders showing the path and counts; tapping it reveals diff content; given an empty/absent `diffs` list, no diff UI renders (regression guard — must not affect tool calls without diffs, matching current behavior).

## 7. Out of scope

- File browser (separate spec — `docs/superpowers/specs/` will get its own design once this ships).
- Editing or reverting a change from the diff view — read-only display only.
- Syntax highlighting inside the diff body.
- Side-by-side (old/new column) diff layout — unified +/- only, per this project's terminal-themed, mobile-width design system.
- Any backend or ACP protocol change — the wire data already exists end-to-end; this spec is 100% client-side.
