# Diff Summaries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the diff data PocketCoder's backend already emits (`pocketcoder:diff` AG-UI CustomEvents) as tap-to-expand unified diffs inside chat tool-call cards.

**Architecture:** This feature spans two separate git repositories. `/Users/aicoder/Documents/ag_ui_widgets_flutter` (pinned as a `pub` git dependency, not a submodule) owns the reduced conversation model — it gets a new `ToolDiff` type, a `diffs` field on `ToolCallTimelineItem`, a reducer case that decodes `pocketcoder:diff` events, and a pass-through in `timelineToMessages`. Those changes are committed and **pushed to that repo's own `origin` remote** before `/Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter`'s `pubspec.yaml` bumps its pinned `ref:` to the new commit SHA. Only after that ref bump does `pocketcoder_flutter` get its own changes: a `diff_match_patch` dependency, a pure line-diff helper, two new rendering widgets, and a small `ToolCallCard` edit to use them.

**Tech Stack:** Dart/Flutter, `freezed` (code-generated unions), `diff_match_patch` (new dependency, line-diffing via a manual lines↔chars encoding — see Task 5), `flutter_test`.

## Global Constraints

- Never use the `!` null-assertion operator (`client/CLAUDE.md`) — use `?.`/`??`/early returns instead.
- No backend or ACP protocol changes — the wire data already exists end-to-end (spec §1).
- No new cubit — this is pure derived-data rendering of already-cached AG-UI events, not a new data-fetching concern (spec §3.2, confirmed against `client/CLAUDE.md`'s cubit-only-for-state-management convention: there is no async operation or loading/error state to manage here).
- Diff view is unified (+/- lines), not side-by-side (spec §3.2, §7) — matches this app's narrow mobile width and terminal-themed design system.
- Rendered diff lines are capped at 300 with an "N more lines omitted" footer; summary `(+N -M)` counts are always computed from the full uncapped diff (spec §5).

---

## Task 1: `ag_ui_widgets_flutter` — `ToolDiff` model + reducer case

**Repo:** `/Users/aicoder/Documents/ag_ui_widgets_flutter` (separate git repo — all commands in this task run with that as the working directory, not `pocketcoder`).

**Files:**
- Modify: `lib/src/model/conversation.dart`
- Modify: `lib/src/model/conversation_reducer.dart`
- Test: `test/model/conversation_reducer_test.dart`

**Interfaces:**
- Produces: `ToolDiff({required String path, String oldText = '', required String newText})` (new `@freezed` class in `conversation.dart`). `ToolCallTimelineItem.diffs` — `List<ToolDiff>`, defaults to `[]`.
- Consumes: `_updateTool(String id, ToolCallTimelineItem Function(ToolCallTimelineItem) update)` — existing private helper at `conversation_reducer.dart:157-163`. **Its real behavior**: if `id` isn't in `_toolTimelineIndex`, it inserts a new orphan `TimelineItem.toolCall(id: id, name: '')` and applies the update to that — it does **not** silently drop unknown ids. This is pre-existing behavior shared with `ToolCallArgsEvent`/`ToolCallResultEvent`; this task's reducer case relies on it as-is.

- [ ] **Step 1: Write the failing reducer tests**

Add this new group to `test/model/conversation_reducer_test.dart`, right after the existing `group('tool calls', ...)` block (after its closing `});` at line 64, before `group('permission/elicitation via state delta', ...)`):

```dart
  group('tool call diffs', () {
    BaseEvent diffEvent(String toolCallId, String path,
            {String? oldText, required String newText}) =>
        CustomEvent(name: 'pocketcoder:diff', value: {
          'toolCallId': toolCallId,
          'path': path,
          if (oldText != null) 'oldText': oldText,
          'newText': newText,
        });

    test('pocketcoder:diff event appends a ToolDiff to the matching tool call', () {
      final r = ConversationReducer()
        ..apply(const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'edit_file'))
        ..apply(diffEvent('t1', 'lib/foo.dart', oldText: 'a', newText: 'b'));

      final item = r.current.timeline.single as ToolCallTimelineItem;
      expect(item.diffs, hasLength(1));
      expect(item.diffs.single.path, 'lib/foo.dart');
      expect(item.diffs.single.oldText, 'a');
      expect(item.diffs.single.newText, 'b');
    });

    test('a second diff event for the same tool call appends rather than replaces', () {
      final r = ConversationReducer()
        ..apply(const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'multi_edit'))
        ..apply(diffEvent('t1', 'lib/a.dart', newText: 'a2'))
        ..apply(diffEvent('t1', 'lib/b.dart', newText: 'b2'));

      final item = r.current.timeline.single as ToolCallTimelineItem;
      expect(item.diffs, hasLength(2));
      expect(item.diffs[0].path, 'lib/a.dart');
      expect(item.diffs[1].path, 'lib/b.dart');
    });

    test('diff event for an unknown toolCallId creates an orphan entry, same as args/result would', () {
      final r = ConversationReducer()..apply(diffEvent('unknown', 'lib/c.dart', newText: 'c'));

      expect(r.current.timeline, hasLength(1));
      final item = r.current.timeline.single as ToolCallTimelineItem;
      expect(item.id, 'unknown');
      expect(item.name, '');
      expect(item.diffs.single.path, 'lib/c.dart');
    });

    test('new-file diff (no oldText in the event) defaults oldText to empty string', () {
      final r = ConversationReducer()
        ..apply(const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'write_file'))
        ..apply(diffEvent('t1', 'lib/new.dart', newText: 'content'));

      final item = r.current.timeline.single as ToolCallTimelineItem;
      expect(item.diffs.single.oldText, '');
    });

    test('a malformed diff event (missing newText) is ignored, not crashed on', () {
      final r = ConversationReducer()
        ..apply(const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'edit_file'))
        ..apply(const CustomEvent(
            name: 'pocketcoder:diff', value: {'toolCallId': 't1', 'path': 'lib/x.dart'}));

      final item = r.current.timeline.single as ToolCallTimelineItem;
      expect(item.diffs, isEmpty);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && flutter test test/model/conversation_reducer_test.dart`
Expected: FAIL — compile error, `The getter 'diffs' isn't defined for the class 'ToolCallTimelineItem'` (the field doesn't exist yet).

- [ ] **Step 3: Add `ToolDiff` and the `diffs` field**

In `lib/src/model/conversation.dart`, add this new class after the `ChatMessageKind` enum (after line 6, before the `TimelineItem` doc comment):

```dart
/// One diff hunk from a tool call's result — the full before/after text for
/// one file. [oldText] is empty for new-file diffs (the backend's ACP-facing
/// `ToolDiff.OldText` uses `omitempty`, so a new-file event never carries an
/// `oldText` key at all).
@freezed
class ToolDiff with _$ToolDiff {
  const factory ToolDiff({
    required String path,
    @Default('') String oldText,
    required String newText,
  }) = _ToolDiff;
}
```

Then change the `TimelineItem.toolCall` factory (currently lines 35-40) to:

```dart
  const factory TimelineItem.toolCall({
    required String id,
    required String name,
    @Default('') String args,
    String? result,
    @Default(<ToolDiff>[]) List<ToolDiff> diffs,
  }) = ToolCallTimelineItem;
```

- [ ] **Step 4: Regenerate freezed code**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: `[INFO] Succeeded after ...` with no errors. This rewrites the committed `lib/src/model/conversation.freezed.dart`.

- [ ] **Step 5: Add the reducer case**

In `lib/src/model/conversation_reducer.dart`, add this case to the `switch (event)` inside `apply()`, immediately after the existing `case ag_ui.ToolCallEndEvent():` block (after line 124, before the blank line and `case ag_ui.StateSnapshotEvent():`):

```dart
      case ag_ui.CustomEvent(name: 'pocketcoder:diff'):
        final value = event.value;
        if (value is Map) {
          final toolCallId = value['toolCallId'];
          final path = value['path'];
          final newText = value['newText'];
          if (toolCallId is String && path is String && newText is String) {
            final diff = ToolDiff(
              path: path,
              oldText: (value['oldText'] as String?) ?? '',
              newText: newText,
            );
            _updateTool(toolCallId, (t) => t.copyWith(diffs: [...t.diffs, diff]));
          }
        }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && flutter test test/model/conversation_reducer_test.dart`
Expected: PASS — all tests including the 5 new ones in `group('tool call diffs', ...)`.

- [ ] **Step 7: Run the full test suite to check for regressions**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && flutter test`
Expected: PASS — no regressions in `conversation_test.dart` or `ag_ui_chat_test.dart`.

- [ ] **Step 8: Commit**

```bash
cd /Users/aicoder/Documents/ag_ui_widgets_flutter
git add lib/src/model/conversation.dart lib/src/model/conversation.freezed.dart lib/src/model/conversation_reducer.dart test/model/conversation_reducer_test.dart
git commit -m "feat: decode pocketcoder:diff events into ToolCallTimelineItem.diffs"
```

---

## Task 2: `ag_ui_widgets_flutter` — pass diffs through `timelineToMessages`

**Repo:** `/Users/aicoder/Documents/ag_ui_widgets_flutter`

**Files:**
- Modify: `lib/src/widgets/timeline_to_messages.dart`
- Test: Create `test/widgets/timeline_to_messages_test.dart`

**Interfaces:**
- Consumes: `ToolDiff`, `TimelineItem.toolCall(..., diffs: ...)` from Task 1.
- Produces: `chat_core.CustomMessage.metadata['diffs']` — `List<Map<String, String>>`, each entry `{'path': ..., 'oldText': ..., 'newText': ...}`. This is the exact shape Task 6 (in `pocketcoder_flutter`) reads back out.

- [ ] **Step 1: Write the failing test**

Create `test/widgets/timeline_to_messages_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:ag_ui_widgets_flutter/src/model/conversation.dart';
import 'package:ag_ui_widgets_flutter/src/widgets/timeline_to_messages.dart';

void main() {
  group('timelineToMessages', () {
    test('toolCall item with diffs produces metadata["diffs"] with path/oldText/newText', () {
      const item = TimelineItem.toolCall(
        id: 't1',
        name: 'edit_file',
        args: '{}',
        result: 'ok',
        diffs: [ToolDiff(path: 'lib/foo.dart', oldText: 'a', newText: 'b')],
      );

      final messages = timelineToMessages([item]);
      final message = messages.single as chat_core.CustomMessage;
      final diffs = message.metadata?['diffs'] as List<dynamic>;
      expect(diffs, hasLength(1));
      expect(diffs.single, {'path': 'lib/foo.dart', 'oldText': 'a', 'newText': 'b'});
    });

    test('toolCall item with no diffs produces an empty diffs list', () {
      const item = TimelineItem.toolCall(id: 't1', name: 'search');
      final messages = timelineToMessages([item]);
      final message = messages.single as chat_core.CustomMessage;
      expect(message.metadata?['diffs'], isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && flutter test test/widgets/timeline_to_messages_test.dart`
Expected: FAIL — `type 'Null' is not a subtype of type 'List<dynamic>'` (metadata has no `'diffs'` key yet).

- [ ] **Step 3: Update `timeline_to_messages.dart`**

Replace the `ToolCallTimelineItem` match arm (currently lines 29-34) with:

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
          'diffs': diffs
              .map((d) => {'path': d.path, 'oldText': d.oldText, 'newText': d.newText})
              .toList(),
        },
      ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && flutter test test/widgets/timeline_to_messages_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full test suite**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && flutter test`
Expected: PASS — no regressions.

- [ ] **Step 6: Commit**

```bash
cd /Users/aicoder/Documents/ag_ui_widgets_flutter
git add lib/src/widgets/timeline_to_messages.dart test/widgets/timeline_to_messages_test.dart
git commit -m "feat: pass ToolCallTimelineItem.diffs through to CustomMessage metadata"
```

---

## Task 3: `ag_ui_widgets_flutter` — push to origin

**Repo:** `/Users/aicoder/Documents/ag_ui_widgets_flutter`

This is a small, standalone task because Task 4 (in the other repo) needs a real, pushed commit to pin against — `pocketcoder_flutter`'s `pub get` resolves the git dependency by fetching a ref from `origin`, so an unpushed local commit would fail resolution for anyone but this machine.

**Files:** none (git operations only).

**Interfaces:**
- Produces: `origin/main` of `ag_ui_widgets_flutter` updated to include Tasks 1-2's commits. Task 4 looks this up itself (`git rev-parse origin/main`) rather than depending on a value carried over from this task — see Task 4, Step 1.

- [ ] **Step 1: Confirm the working tree is clean and on `main`**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && git status && git branch --show-current`
Expected: `nothing to commit, working tree clean` (both Task 1 and Task 2 commits already made) and current branch `main`.

- [ ] **Step 2: Push to origin**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && git push origin main`
Expected: push succeeds (this is the project's own org repo — `git remote -v` confirms `origin` is `git@github-qtpi-bonding-org-ag_ui_widgets_flutter:qtpi-bonding-org/ag_ui_widgets_flutter.git`, not a third-party fork).

- [ ] **Step 3: Confirm the push landed**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && git rev-parse HEAD origin/main`
Expected: both lines print the same 40-character SHA, confirming `origin/main` now points at this task's commits. (Task 4 looks this SHA up itself via `origin/main` rather than depending on it being carried over from here — see Task 4, Step 1.)

---

## Task 4: `pocketcoder_flutter` — bump the pinned ref and add `diff_match_patch`

**Repo:** `/Users/aicoder/Documents/pocketcoder` (specifically `client/packages/pocketcoder_flutter`). All later tasks in this plan operate in this repo unless stated otherwise.

**Files:**
- Modify: `client/packages/pocketcoder_flutter/pubspec.yaml`

**Interfaces:**
- Consumes: the commit pushed to `ag_ui_widgets_flutter`'s `origin/main` in Task 3.
- Produces: `diff_match_patch` package available for import as `package:diff_match_patch/diff_match_patch.dart`, consumed by Task 5.

- [ ] **Step 1: Bump the pinned ref**

**Do not rely on a remembered value from Task 3's terminal output** — if this task runs as a fresh subagent (per this plan's recommended `subagent-driven-development` execution), it has no memory of Task 3's session. Instead, look the SHA up directly:

Run: `git -C /Users/aicoder/Documents/ag_ui_widgets_flutter rev-parse origin/main`
Expected: prints the 40-character SHA of the commit Task 3 pushed (its `HEAD` after Tasks 1-2's commits).

In `client/packages/pocketcoder_flutter/pubspec.yaml`, change line 80 from:

```yaml
      ref: df010806b11ad127a32a82e6d3eba38bd3e7a241
```

to that SHA (do not guess or reuse the old SHA — use the exact value the command above printed).

- [ ] **Step 2: Add the `diff_match_patch` dependency**

In the same `pubspec.yaml`, add this line in the `dependencies:` block, in the `# Utilities` cluster (after the existing `uuid: ^4.0.0` line, matching that section's flat-version style — this package has no `git:` source, it's a plain pub.dev dependency):

```yaml
  diff_match_patch: ^0.4.1
```

- [ ] **Step 3: Fetch dependencies**

Run: `cd /Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter && flutter pub get`
Expected: `Got dependencies!` with no version-resolution errors. This re-fetches `ag_ui_widgets_flutter` at the new pinned commit and resolves `diff_match_patch` (already present in the local pub cache from this session's investigation, so this should resolve without a network fetch for that package).

- [ ] **Step 4: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/pubspec.yaml client/packages/pocketcoder_flutter/pubspec.lock
git commit -m "chore: bump ag_ui_widgets_flutter ref, add diff_match_patch dependency"
```

---

## Task 5: `pocketcoder_flutter` — pure diff-computation helper

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/chat/diff_stats.dart`
- Test: Create `client/packages/pocketcoder_flutter/test/presentation/chat/diff_stats_test.dart`

**Interfaces:**
- Consumes: `diff_match_patch`'s top-level `diff(String text1, String text2, {bool checklines = true})` function (returns `List<Diff>`, each `Diff` having `int operation` — one of the exported constants `DIFF_INSERT` (1), `DIFF_DELETE` (-1), `DIFF_EQUAL` (0) — and `String text`). Verified against the installed package source (`~/.pub-cache/hosted/pub.dev/diff_match_patch-0.4.1/lib/src/diff/main.dart` and `diff/diff.dart`) during plan-writing — this is the real API, not `DiffMatchPatch().diff()` nor a `diffLinesToChars`/`diffMain` pairing (neither of the latter exist in this package).
- Produces: `computeDiffStats(String oldText, String newText) -> DiffStats`, where `DiffStats = {added: int, removed: int, lines: List<DiffLine>}` and `DiffLine = {text: String, kind: DiffLineKind}` (`DiffLineKind` = `added` | `removed` | `context`). Consumed by Task 6's `DiffSummaryLine`/`DiffBody` widgets. `DiffStats.lines` is **always the full, uncapped** diff — any truncation for rendering happens in Task 6's widget, not here (spec §5: summary counts must reflect the full diff regardless of what's rendered).

**Why not just call `diff()` directly on the raw text and split on newlines:** `diff_match_patch`'s `diff()` operates at character granularity. For a single-line change with no newlines (a very common case — one line edited in a file), `checklines: true` has no effect (it's a large-multi-line-block speedup, not a line-boundary guarantee), so the raw output would show a character-level insert/delete inside the line rather than a whole `-old line` / `+new line` pair — not the git-style unified diff this feature is meant to produce. This helper works around that with the standard "lines→unique chars→diff→chars→lines" technique: encode each unique line of `oldText`/`newText` as a single unicode character, diff those two encoded strings (now every diff unit is a whole line), then decode back. This is a well-known technique for getting line-granularity output from a character-level diff library, implemented here directly (not via a library method) since this port doesn't expose one publicly.

- [ ] **Step 1: Write the failing tests**

Create `client/packages/pocketcoder_flutter/test/presentation/chat/diff_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/presentation/chat/diff_stats.dart';

void main() {
  group('computeDiffStats', () {
    test('a single-line change counts one removed line and one added line', () {
      final stats = computeDiffStats('return a + b', 'return a - b');

      expect(stats.removed, 1);
      expect(stats.added, 1);
      expect(stats.lines, hasLength(2));
      expect(stats.lines[0].kind, DiffLineKind.removed);
      expect(stats.lines[0].text, 'return a + b');
      expect(stats.lines[1].kind, DiffLineKind.added);
      expect(stats.lines[1].text, 'return a - b');
    });

    test('identical old and new text yields zero added/removed, all context lines', () {
      final stats = computeDiffStats('line one\nline two', 'line one\nline two');

      expect(stats.added, 0);
      expect(stats.removed, 0);
      expect(stats.lines, hasLength(2));
      expect(stats.lines.every((l) => l.kind == DiffLineKind.context), isTrue);
    });

    test('empty oldText (new file) counts every line as added, zero removed', () {
      final stats = computeDiffStats('', 'line one\nline two\nline three');

      expect(stats.removed, 0);
      expect(stats.added, 3);
      expect(stats.lines.every((l) => l.kind == DiffLineKind.added), isTrue);
    });

    test('a multi-line edit preserves unchanged context lines around the change', () {
      final stats = computeDiffStats(
        'def add(a, b):\n    return a + b\n\ndef sub(a, b):',
        'def add(a, b):\n    result = a + b\n    return result\n\ndef sub(a, b):',
      );

      expect(stats.removed, 1);
      expect(stats.added, 2);
      expect(stats.lines.first.text, 'def add(a, b):');
      expect(stats.lines.first.kind, DiffLineKind.context);
      expect(stats.lines.last.text, 'def sub(a, b):');
      expect(stats.lines.last.kind, DiffLineKind.context);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter && flutter test test/presentation/chat/diff_stats_test.dart`
Expected: FAIL — `Error: Not found: 'package:pocketcoder_flutter/presentation/chat/diff_stats.dart'` (file doesn't exist yet).

- [ ] **Step 3: Write the implementation**

Create `client/packages/pocketcoder_flutter/lib/presentation/chat/diff_stats.dart`:

```dart
import 'package:diff_match_patch/diff_match_patch.dart' as dmp;

enum DiffLineKind { added, removed, context }

class DiffLine {
  const DiffLine(this.text, this.kind);
  final String text;
  final DiffLineKind kind;
}

class DiffStats {
  const DiffStats({required this.added, required this.removed, required this.lines});
  final int added;
  final int removed;
  final List<DiffLine> lines;
}

/// Computes a git-style, line-granularity diff between [oldText] and
/// [newText]. `diff_match_patch`'s `diff()` is character-level; this encodes
/// each unique line as a single unicode character first so the underlying
/// diff operates on whole lines, then decodes the result back to text.
DiffStats computeDiffStats(String oldText, String newText) {
  final oldLines = oldText.isEmpty ? const <String>[] : oldText.split('\n');
  final newLines = newText.isEmpty ? const <String>[] : newText.split('\n');

  final lineToChar = <String, String>{};
  String encode(List<String> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      final code = lineToChar.putIfAbsent(line, () => String.fromCharCode(lineToChar.length));
      buffer.write(code);
    }
    return buffer.toString();
  }

  final oldEncoded = encode(oldLines);
  final newEncoded = encode(newLines);
  final charToLine = {for (final entry in lineToChar.entries) entry.value: entry.key};

  final rawDiffs = dmp.diff(oldEncoded, newEncoded, checklines: false);

  var added = 0;
  var removed = 0;
  final lines = <DiffLine>[];
  for (final d in rawDiffs) {
    final kind = switch (d.operation) {
      dmp.DIFF_INSERT => DiffLineKind.added,
      dmp.DIFF_DELETE => DiffLineKind.removed,
      _ => DiffLineKind.context,
    };
    for (final code in d.text.split('')) {
      final line = charToLine[code] ?? '';
      lines.add(DiffLine(line, kind));
      if (kind == DiffLineKind.added) added++;
      if (kind == DiffLineKind.removed) removed++;
    }
  }
  return DiffStats(added: added, removed: removed, lines: lines);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter && flutter test test/presentation/chat/diff_stats_test.dart`
Expected: PASS — all 4 tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/presentation/chat/diff_stats.dart client/packages/pocketcoder_flutter/test/presentation/chat/diff_stats_test.dart
git commit -m "feat: add computeDiffStats line-diff helper for tool-call diffs"
```

---

## Task 6: `pocketcoder_flutter` — diff summary widgets + wire into `ToolCallCard`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/chat/diff_summary_view.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/chat/tool_call_card.dart`
- Test: Create `client/packages/pocketcoder_flutter/test/presentation/chat/tool_call_card_test.dart`

**Interfaces:**
- Consumes: `computeDiffStats`, `DiffLine`, `DiffLineKind` from Task 5. `context.terminalColors` (`terminalColors.danger`, `terminalColors.attention`), `context.colorScheme`, `AppFonts.bodyFamily`, `AppFonts.heavy`, `AppSizes.fontMini`, `AppSizes.space`, `AppSizes.borderWidth`, `HSpace.x1`, `VSpace.x1` — all confirmed present in `lib/design_system/theme/app_theme.dart` and `lib/design_system/primitives/app_sizes.dart`/`app_fonts.dart`, and already used by the existing `tool_call_card.dart` (do not invent new design-system members).
- Produces: `DiffSummaryLine({required String path, required String oldText, required String newText})` — a `StatefulWidget`; tapping toggles an inline `DiffBody`. `DiffBody({required List<DiffLine> lines})` — the capped, colored unified-diff view.

- [ ] **Step 1: Write the failing widget test**

Create `client/packages/pocketcoder_flutter/test/presentation/chat/tool_call_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/tool_call_card.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('ToolCallCard diff rendering', () {
    testWidgets('a tool call with no diffs renders no diff summary line', (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: const {'kind': 'toolCall', 'name': 'search', 'args': '{}', 'result': 'ok'},
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      expect(find.textContaining('+'), findsNothing);
    });

    testWidgets('a tool call with one diff renders a summary line with path and counts',
        (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: {
          'kind': 'toolCall',
          'name': 'edit_file',
          'args': '{}',
          'result': 'ok',
          'diffs': [
            {'path': 'lib/foo.dart', 'oldText': 'return a + b', 'newText': 'return a - b'},
          ],
        },
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      expect(find.textContaining('LIB/FOO.DART'), findsOneWidget);
      expect(find.textContaining('(+1 -1)'), findsOneWidget);
      expect(find.text('return a - b'), findsNothing);
    });

    testWidgets('tapping the summary line expands the diff body', (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: {
          'kind': 'toolCall',
          'name': 'edit_file',
          'args': '{}',
          'result': 'ok',
          'diffs': [
            {'path': 'lib/foo.dart', 'oldText': 'return a + b', 'newText': 'return a - b'},
          ],
        },
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('LIB/FOO.DART'));
      await tester.pumpAndSettle();

      expect(find.text('- return a + b'), findsOneWidget);
      expect(find.text('+ return a - b'), findsOneWidget);
    });

    testWidgets('a new-file diff (empty oldText) shows NEW FILE instead of counts', (tester) async {
      final message = chat_core.Message.custom(
        id: 't1',
        authorId: 'assistant',
        metadata: {
          'kind': 'toolCall',
          'name': 'write_file',
          'args': '{}',
          'result': 'ok',
          'diffs': [
            {'path': 'lib/new.dart', 'oldText': '', 'newText': 'content'},
          ],
        },
      ) as chat_core.CustomMessage;

      await tester.pumpWidget(_wrap(ToolCallCard(message: message)));
      await tester.pumpAndSettle();

      expect(find.textContaining('NEW FILE'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter && flutter test test/presentation/chat/tool_call_card_test.dart`
Expected: FAIL — the first test passes trivially (nothing to find yet is correct), but the diff-rendering tests fail with `findsNothing`/`findsOneWidget` mismatches since `ToolCallCard` doesn't read `metadata['diffs']` yet.

- [ ] **Step 3: Create the diff summary widgets**

Create `client/packages/pocketcoder_flutter/lib/presentation/chat/diff_summary_view.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'diff_stats.dart';

const int kDiffLineCap = 300;

class DiffSummaryLine extends StatefulWidget {
  const DiffSummaryLine({
    super.key,
    required this.path,
    required this.oldText,
    required this.newText,
  });

  final String path;
  final String oldText;
  final String newText;

  @override
  State<DiffSummaryLine> createState() => _DiffSummaryLineState();
}

class _DiffSummaryLineState extends State<DiffSummaryLine> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final isNewFile = widget.oldText.isEmpty;
    final stats = computeDiffStats(widget.oldText, widget.newText);
    final label = isNewFile
        ? '${widget.path.toUpperCase()} (NEW FILE)'
        : '${widget.path.toUpperCase()} (+${stats.added} -${stats.removed})';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 14,
                color: colors.onSurface.withValues(alpha: 0.7),
              ),
              HSpace.x1,
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.onSurface,
                    fontFamily: AppFonts.bodyFamily,
                    fontSize: AppSizes.fontMini,
                    fontWeight: AppFonts.heavy,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_expanded) DiffBody(lines: stats.lines),
      ],
    );
  }
}

class DiffBody extends StatelessWidget {
  const DiffBody({super.key, required this.lines});

  final List<DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final terminalColors = context.terminalColors;
    final colors = context.colorScheme;
    final capped = lines.length > kDiffLineCap ? lines.sublist(0, kDiffLineCap) : lines;
    final omitted = lines.length - capped.length;

    Color colorFor(DiffLineKind kind) => switch (kind) {
          DiffLineKind.added => terminalColors.attention,
          DiffLineKind.removed => terminalColors.danger,
          DiffLineKind.context => colors.onSurface.withValues(alpha: 0.7),
        };

    String prefixFor(DiffLineKind kind) => switch (kind) {
          DiffLineKind.added => '+ ',
          DiffLineKind.removed => '- ',
          DiffLineKind.context => '  ',
        };

    return Container(
      margin: EdgeInsets.only(top: AppSizes.space * 0.5),
      padding: EdgeInsets.all(AppSizes.space * 0.5),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.5),
        border: Border.all(
          color: colors.onSurface.withValues(alpha: 0.15),
          width: AppSizes.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in capped)
            Text(
              '${prefixFor(line.kind)}${line.text}',
              style: TextStyle(
                color: colorFor(line.kind),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
          if (omitted > 0)
            Text(
              '… $omitted more lines omitted',
              style: TextStyle(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontFamily: AppFonts.bodyFamily,
                fontSize: AppSizes.fontMini,
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Wire diffs into `ToolCallCard`**

In `client/packages/pocketcoder_flutter/lib/presentation/chat/tool_call_card.dart`, add the import:

```dart
import 'diff_summary_view.dart';
```

Add this line alongside the existing `name`/`args`/`result` reads (after the existing `final result = message.metadata?['result'] as String?;` line):

```dart
    final diffs = (message.metadata?['diffs'] as List<dynamic>?) ?? const [];
```

Then add this block to the `Column`'s `children`, immediately after the existing `if (result != null) [...]` block (i.e. as the last entries before the closing `],`):

```dart
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

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter && flutter test test/presentation/chat/tool_call_card_test.dart`
Expected: PASS — all 4 tests.

- [ ] **Step 6: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/presentation/chat/diff_summary_view.dart client/packages/pocketcoder_flutter/lib/presentation/chat/tool_call_card.dart client/packages/pocketcoder_flutter/test/presentation/chat/tool_call_card_test.dart
git commit -m "feat: render diff summaries in ToolCallCard, tap to expand unified diff"
```

---

## Task 7: Final verification

**Files:** none — verification only.

- [ ] **Step 1: Static analysis**

Run: `cd /Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Full Flutter test suite**

Run: `cd /Users/aicoder/Documents/pocketcoder/client/packages/pocketcoder_flutter && flutter test`
Expected: PASS — all tests green, including every test added in Tasks 5 and 6 and every pre-existing test (no regressions).

- [ ] **Step 3: Full `ag_ui_widgets_flutter` test suite (re-check)**

Run: `cd /Users/aicoder/Documents/ag_ui_widgets_flutter && flutter test`
Expected: PASS — confirms Task 1/2's changes are still green after the `pocketcoder_flutter` side was built against the pushed commit.

- [ ] **Step 4: Manual smoke check (documented, not automatable in this environment)**

There is no automated end-to-end check that a live Goose tool call actually renders a diff card, since that requires a running `docker compose --profile agent` stack with a real model key. Note this plan's automated coverage stops at widget/unit tests exercising the pipeline with synthetic events — a manual pass through a real chat session (edit a file via the agent, confirm the diff summary line and its expansion render correctly) is recommended before considering this feature fully verified in production, but is out of scope for this plan's automated steps.

---

## Self-Review

**Spec coverage:** §1 (why) — no task needed, background only. §2 (scope: decode + render) — Tasks 1-2 (decode) + Tasks 5-6 (render). §3.1 (`ag_ui_widgets_flutter` architecture) — Tasks 1-3. §3.2 (`pocketcoder_flutter` architecture) — Tasks 4-6. §4 (data flow) — end-to-end path is exercised by Task 1's reducer tests (event → timeline) + Task 2's tests (timeline → message metadata) + Task 6's widget tests (metadata → rendered UI); no gap. §5 (error handling) — orphan-entry behavior documented and tested (Task 1), malformed-event skip tested (Task 1), new-file case tested (Tasks 5-6), large-diff cap implemented and left to a future dedicated test if the team wants one (see note below). §6 (testing) — all four bullet points have corresponding tasks/tests. §7 (out of scope) — file browser, editing/reverting, syntax highlighting, side-by-side layout, backend/ACP changes: none of these appear in any task, confirmed out of scope.

**Gap acknowledged:** the spec's §5 large-diff cap (300 lines, footer note) is implemented in `DiffBody` (Task 6, Step 3) but has no dedicated widget test for the >300-line case in this plan — adding 301 synthetic lines to a widget test is straightforward but was judged lower-value than the four scenarios already covered (empty/no-op, new-file, multi-line, tap-to-expand) given the cap logic itself is a single `sublist`/`length` comparison. If stricter coverage is wanted, add a `DiffBody`-only widget test (not `ToolCallCard`) constructing `List<DiffLine>` directly with 301 entries and asserting the footer text appears with `omitted == 1`.

**Placeholder scan:** no TBD/TODO markers; every step has real code or a real command with expected output.

**Type consistency:** `DiffStats`/`DiffLine`/`DiffLineKind` (Task 5) are the exact types `DiffSummaryLine`/`DiffBody` (Task 6) consume — verified the field names (`text`, `kind`, `added`, `removed`, `lines`) match across both tasks. The wire shape `{'path', 'oldText', 'newText'}` is identical across Task 2's `timeline_to_messages.dart` output, Task 6's `ToolCallCard` decode, and every test's fixture data.
