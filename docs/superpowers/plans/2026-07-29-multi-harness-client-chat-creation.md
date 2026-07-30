# Multi-Harness Selection — Client Chat-Creation UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status: TENTATIVE.** Plan 1 (schema + coordinator) and Plan 2 (provisioning + adapter) are being implemented concurrently by other agents. This plan assumes their documented interfaces (`chats.harness`, `chats.workspace_override`, `chats.harness_model_override` already exist; `harness_instances`/provisioning happen server-side and need no client awareness beyond "creating a chat with a harness selected may take a moment the first time"). If either lands with a different field name or shape than documented in the design spec, **re-check this plan's Task 1 against the actual `schema.json`/generated Dart models before starting** — do not assume the interface below is final.

**Confirmed live blocker as of this writing:** checked `client/packages/pocketcoder_flutter/assets/pb_schema.json` on this branch directly — the `chats` collection currently has only `poco_config` and a pre-existing `harness_model_override` relation field. There is **no `harness` field and no `workspace_override` field yet** — Plan 1 has not landed them. Do not start Task 1 until `schema.json` shows both fields (re-run `tooling/scripts/export_schema.sh` and check, or confirm with whoever is implementing Plan 1); starting early would write keys PocketBase's schema doesn't define yet.

**Goal:** A user creating a new chat can pick cwd + harness + model before the chat is created, the same way a terminal user picks a working directory and a CLI before starting a session (design spec §1, §7). Today `ChatListCubit.createAndOpen()` → `ChatDao.save({title, user})` is a bare title-only insert; this plan makes harness/model/cwd real, client-side, choices.

**Architecture:** Extend the existing `chat_list` domain/infrastructure/application layers with three new optional parameters (`harness`, `harnessModelOverride`, `workspaceOverride`), threaded from a new `NewChatDialog` widget down to `ChatDao.save`. The dialog reuses the **already-existing** `IProviderRepository` (`watchHarnesses`/`watchModels`/`watchHarnessModels`/`watchProviderKeys` — built for the admin-side provider-config screen, `lib/presentation/provider/provider_screen.dart`) rather than adding new streams — this plan adds zero new PocketBase-facing repository surface beyond `chat_list`'s own three new parameters. Constrained-combination filtering (design spec §5.9: a model needs a `harness_models` row for the selected harness, and the user needs a `provider_keys` row for that model's provider) and cwd path validation (design spec §5.8's textual-prefix rule, client-side nicety only — the server enforces this for real) are both extracted as pure, directly-testable functions rather than buried in widget build methods.

**Tech Stack:** Flutter/Dart, `flutter_bloc`/`cubit_ui_flow` (existing `AppCubit`/`UiFlowStatus` pattern), `pocketbase_drift`, `mocktail` for tests, existing `injectable`/`get_it` DI (`getIt<T>()`).

## Global Constraints

- No new PocketBase collections, fields, or repository interfaces beyond `chat_list`'s three new `createChat`/`createAndOpen` parameters — `harnesses`/`models`/`harness_models`/`provider_keys` are already fully exposed client-side via `IProviderRepository` (`lib/domain/provider/i_provider_repository.dart`).
- Follow the existing screen/cubit/repository/DAO layering exactly (`ChatListScreen`/`ChatListCubit`/`ChatListRepository`/`ChatDao`, mirroring `ProviderScreen`/`ProviderCubit`). **Note:** `lib/presentation/provider/provider_screen.dart` does NOT contain a dropdown/picker widget to reuse — it renders `harness_models` as a static read-only list of `TerminalCard` tiles and edits provider keys via a separate `_ProviderKeyEditorDialog`. There is no existing dropdown-from-stream pattern in this codebase; Task 5's `DropdownButton` usage is a new pattern, not a reuse of one.
- `chats.workspace_override` is a nullable JSON field with the exact same element shape as `poco_configs.workspace_folders` — confirmed via `server/pocketbase/internal/api/profile.go:93-99`: a plain `List<String>` where element 0 is cwd. Per design spec §5.7, only element 0 is ever sent from this dialog (there is no "additional directories" picker in v1 — those always come from the poco); when the user leaves cwd at its default, **omit the field entirely** (send nothing, not `[]`), so JSON-null "unset" (inherit the poco's folders) stays distinguishable from an explicit override — do not send `[]` as a stand-in for "no override."
- `chats.harness_model_override` (existing field, already on the `Chat` model as `harnessModelOverride`) is the field name to write the selected `harness_models.id` to — do not invent a new field name.
- Existing tests that must keep passing unmodified except where a task explicitly says otherwise: `test/application/chat/chat_list_cubit_test.dart`, `test/infrastructure/chat/chat_list_repository_test.dart`, `test/presentation/chat/chat_list_screen_test.dart`.
- Design spec: `docs/superpowers/specs/2026-07-29-multi-harness-selection-design.md` — read §5.7, §5.8, §5.9, §7 before starting; this plan implements exactly those sections' client-facing surface.

---

## File Structure

| File | Responsibility |
|---|---|
| `lib/domain/chat/i_chat_list_repository.dart` | Modify: `createChat` gains `harness`, `harnessModelOverride`, `workspaceOverride` optional named params. |
| `lib/infrastructure/chat/chat_list_repository.dart` | Modify: `createChat` builds the save payload conditionally — only includes a key when its param is non-null. |
| `lib/application/chat/chat_list_cubit.dart` | Modify: `createAndOpen` gains matching optional params, passed straight through to `_repo.createChat`. |
| `lib/presentation/chat/new_chat_selection.dart` | Create: two pure functions — `selectableModels(...)` (§5.9 filtering) and `validateWorkspacePath(...)` (§5.8 client-side check) — kept separate from the widget so they're unit-testable without pumping a widget tree. |
| `lib/presentation/chat/new_chat_dialog.dart` | Create: `NewChatDialog` — the cwd/harness/model/title picker shown before a chat is created. |
| `lib/presentation/chat/chat_list_screen.dart` | Modify: the "+ NEW CHAT" action opens `NewChatDialog` instead of calling `createAndOpen()` directly; its `onCreate` callback threads the dialog's selections into `createAndOpen`. |
| `lib/l10n/app_en.arb` | Modify: add the new dialog's user-facing strings. |
| `test/application/chat/chat_list_cubit_test.dart` | Modify: extend existing `createAndOpen` tests to cover the new params. |
| `test/infrastructure/chat/chat_list_repository_test.dart` | Modify: extend existing `createChat` tests to cover conditional payload construction. |
| `test/presentation/chat/new_chat_selection_test.dart` | Create: unit tests for the two pure functions. |
| `test/presentation/chat/new_chat_dialog_test.dart` | Create: widget tests for `NewChatDialog`. |
| `test/presentation/chat/chat_list_screen_test.dart` | Modify: add a test that tapping "+ NEW CHAT" opens the dialog. |

---

## Task 1: `createChat`/`ChatListRepository` gain harness/model/workspace params

**Files:**
- Modify: `lib/domain/chat/i_chat_list_repository.dart`
- Modify: `lib/infrastructure/chat/chat_list_repository.dart`
- Test: `test/infrastructure/chat/chat_list_repository_test.dart`

**Interfaces:**
- Consumes: `ChatDao.save(String? id, Map<String, dynamic> data)` (existing, unchanged).
- Produces: `IChatListRepository.createChat({String? title, String? harness, String? harnessModelOverride, List<String>? workspaceOverride})`. Consumed by Task 2 (`ChatListCubit.createAndOpen`).

- [ ] **Step 1: Write the failing tests**

Add to `test/infrastructure/chat/chat_list_repository_test.dart`, inside the existing `group('ChatListRepository.createChat', ...)`:

```dart
    test('includes harness when given', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat', harness: 'harness-1');

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
            'harness': 'harness-1',
          })).called(1);
    });

    test('includes harnessModelOverride when given', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat', harnessModelOverride: 'hm-1');

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
            'harness_model_override': 'hm-1',
          })).called(1);
    });

    test('includes workspace_override only when non-null, never as an empty stand-in', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat', workspaceOverride: ['/workspace/proj']);

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
            'workspace_override': ['/workspace/proj'],
          })).called(1);
    });

    test('omits harness/harnessModelOverride/workspace_override entirely when all null', () async {
      when(() => auth.currentUserId).thenReturn('user-1');
      when(() => dao.save(any(), any())).thenAnswer(
        (_) async => const Chat(id: 'chat-1', title: 'My Chat', user: 'user-1'),
      );

      await repo.createChat(title: 'My Chat');

      verify(() => dao.save(null, {
            'title': 'My Chat',
            'user': 'user-1',
          })).called(1);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/chat/chat_list_repository_test.dart`
Expected: FAIL — `createChat` has no named parameter `harness` (compile error)

- [ ] **Step 3: Update the interface and implementation**

`lib/domain/chat/i_chat_list_repository.dart`:

```dart
import 'package:pocketcoder_flutter/domain/models/chat.dart';

abstract class IChatListRepository {
  Stream<List<Chat>> watchChats();
  Future<bool> hasAnyChats();
  Future<Chat> createChat({
    String? title,
    String? harness,
    String? harnessModelOverride,
    List<String>? workspaceOverride,
  });
  Future<void> archiveChat(String id);
  Future<void> deleteChat(String id);
}
```

`lib/infrastructure/chat/chat_list_repository.dart`'s `createChat`:

```dart
  @override
  Future<Chat> createChat({
    String? title,
    String? harness,
    String? harnessModelOverride,
    List<String>? workspaceOverride,
  }) {
    return tryMethod(
      () async {
        final data = <String, dynamic>{
          'title': title ?? 'New Chat',
          'user': _auth.currentUserId,
        };
        if (harness != null) data['harness'] = harness;
        if (harnessModelOverride != null) {
          data['harness_model_override'] = harnessModelOverride;
        }
        if (workspaceOverride != null) {
          data['workspace_override'] = workspaceOverride;
        }
        return _dao.save(null, data);
      },
      ChatListException.new,
      'createChat',
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/chat/chat_list_repository_test.dart`
Expected: PASS (all tests in the file, including the pre-existing ones — the two untouched pre-existing tests assert the same bare `{title, user}` map, which still holds since all three new params default to `null` and are omitted)

- [ ] **Step 5: Commit**

```bash
cd client/packages/pocketcoder_flutter
git add lib/domain/chat/i_chat_list_repository.dart lib/infrastructure/chat/chat_list_repository.dart test/infrastructure/chat/chat_list_repository_test.dart
git commit -m "feat(chat-list): thread harness/harnessModelOverride/workspaceOverride into createChat"
```

---

## Task 2: `ChatListCubit.createAndOpen` threads the new params

**Files:**
- Modify: `lib/application/chat/chat_list_cubit.dart`
- Test: `test/application/chat/chat_list_cubit_test.dart`

**Interfaces:**
- Consumes: `IChatListRepository.createChat` (Task 1).
- Produces: `ChatListCubit.createAndOpen({String? title, String? harness, String? harnessModelOverride, List<String>? workspaceOverride})`. Consumed by Task 6 (`NewChatDialog`'s submit callback via `ChatListScreen`).

- [ ] **Step 1: Write the failing test**

Add to `test/application/chat/chat_list_cubit_test.dart`, inside `group('ChatListCubit.createAndOpen', ...)`:

```dart
    test('passes harness/harnessModelOverride/workspaceOverride through to the repo',
        () async {
      when(() => repo.createChat(
            title: any(named: 'title'),
            harness: any(named: 'harness'),
            harnessModelOverride: any(named: 'harnessModelOverride'),
            workspaceOverride: any(named: 'workspaceOverride'),
          )).thenAnswer((_) async => testChat);

      final cubit = buildCubit();
      await cubit.createAndOpen(
        title: 'x',
        harness: 'harness-1',
        harnessModelOverride: 'hm-1',
        workspaceOverride: ['/workspace/proj'],
      );

      verify(() => repo.createChat(
            title: 'x',
            harness: 'harness-1',
            harnessModelOverride: 'hm-1',
            workspaceOverride: ['/workspace/proj'],
          )).called(1);
      expect(cubit.state.lastCreatedChatId, 'chat-1');
    });
```

The two pre-existing tests in this group (`'creates a chat and sets lastCreatedChatId'`, `'surfaces repo failure as state error'`) call `repo.createChat(title: any(named: 'title'))` with no other named args stubbed — since `mocktail`'s `any(named: ...)` matchers must cover every named parameter the call site actually passes, these two existing stubs and their `verify(() => repo.createChat(title: null))` calls will break once `createAndOpen` starts passing all four named params on every call (Mocktail matches by exact argument list including named-arg matchers). **A third pre-existing test also needs this same update**: `group('ChatListCubit.watchChats', ...)` contains `'clears a pending lastCreatedChatId on the next list emission'`, which likewise stubs `repo.createChat(title: any(named: 'title'))` and calls `await cubit.createAndOpen()` — it will break for the identical reason and must be updated alongside the two tests below. Update all three existing stubs/verifies to also match on the other three params:

```dart
      when(() => repo.createChat(
            title: any(named: 'title'),
            harness: any(named: 'harness'),
            harnessModelOverride: any(named: 'harnessModelOverride'),
            workspaceOverride: any(named: 'workspaceOverride'),
          )).thenAnswer((_) async => testChat);
      // ...
      verify(() => repo.createChat(
            title: null,
            harness: null,
            harnessModelOverride: null,
            workspaceOverride: null,
          )).called(1);
```

**Do not touch the two `checkEmptyAndMaybeAutoCreate` tests.** Confirmed against `chat_list_cubit.dart:76`: `checkEmptyAndMaybeAutoCreate` calls `_repo.createChat()` directly, never through `createAndOpen()`. Its existing `repo.createChat(title: any(named: 'title'))` stub/verify is unaffected by this task and must be left exactly as-is. Only the three `createAndOpen`-driven tests identified above (the two in `group('ChatListCubit.createAndOpen', ...)` plus `'clears a pending lastCreatedChatId on the next list emission'` in `group('ChatListCubit.watchChats', ...)`) need the four-param stub/verify update.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/chat/chat_list_cubit_test.dart`
Expected: FAIL — `createAndOpen` has no named parameter `harness` (compile error), plus Mocktail "no matching call" failures on the two updated `createAndOpen`-related tests until Step 3 lands

- [ ] **Step 3: Update `createAndOpen`**

```dart
  Future<void> createAndOpen({
    String? title,
    String? harness,
    String? harnessModelOverride,
    List<String>? workspaceOverride,
  }) =>
      tryOperation(() async {
        final chat = await _repo.createChat(
          title: title,
          harness: harness,
          harnessModelOverride: harnessModelOverride,
          workspaceOverride: workspaceOverride,
        );
        return state.copyWith(
          status: UiFlowStatus.success,
          error: null,
          lastCreatedChatId: chat.id,
        );
      });
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/chat/chat_list_cubit_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd client/packages/pocketcoder_flutter
git add lib/application/chat/chat_list_cubit.dart test/application/chat/chat_list_cubit_test.dart
git commit -m "feat(chat-list): thread harness/harnessModelOverride/workspaceOverride through createAndOpen"
```

---

## Task 3: Constrained-combination filtering — `selectableModels` (§5.9)

**Files:**
- Create: `lib/presentation/chat/new_chat_selection.dart`
- Test: `test/presentation/chat/new_chat_selection_test.dart`

**Interfaces:**
- Consumes: `Harnesse`, `HarnessModel`, `Model`, `ProviderKey` (existing domain models, `lib/domain/models/{harnesse,harness_model,model,provider_key}.dart` — already read and confirmed to have exactly the fields used below).
- Produces: `List<HarnessModel> selectableModels({required String harnessId, required List<HarnessModel> harnessModels, required List<Model> models, required List<ProviderKey> providerKeys})`. Consumed by Task 5 (`NewChatDialog`'s model dropdown).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_selection.dart';

void main() {
  const modelA = Model(id: 'model-a', name: 'a', provider: 'anthropic');
  const modelB = Model(id: 'model-b', name: 'b', provider: 'openai');
  const hmA = HarnessModel(
      id: 'hm-a', harness: 'h1', model: 'model-a', harnessModelId: 'claude-3');
  const hmB = HarnessModel(
      id: 'hm-b', harness: 'h1', model: 'model-b', harnessModelId: 'gpt-4');
  const hmOtherHarness = HarnessModel(
      id: 'hm-c', harness: 'h2', model: 'model-a', harnessModelId: 'claude-3');

  group('selectableModels', () {
    test('only returns harness_models rows for the selected harness', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA, hmB, hmOtherHarness],
        models: [modelA, modelB],
        providerKeys: [
          const ProviderKey(id: 'k1', user: 'u', provider: 'anthropic'),
          const ProviderKey(id: 'k2', user: 'u', provider: 'openai'),
        ],
      );
      expect(result.map((h) => h.id), containsAll(['hm-a', 'hm-b']));
      expect(result.map((h) => h.id), isNot(contains('hm-c')));
    });

    test('excludes a model whose provider has no provider_keys row', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA, hmB],
        models: [modelA, modelB],
        providerKeys: [
          const ProviderKey(id: 'k1', user: 'u', provider: 'anthropic'),
        ],
      );
      expect(result.map((h) => h.id), ['hm-a']);
    });

    test('excludes a harness_models row whose model id has no matching Model record', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA],
        models: const [], // modelA missing entirely
        providerKeys: [
          const ProviderKey(id: 'k1', user: 'u', provider: 'anthropic'),
        ],
      );
      expect(result, isEmpty);
    });

    test('returns an empty list when no provider_keys exist at all', () {
      final result = selectableModels(
        harnessId: 'h1',
        harnessModels: [hmA, hmB],
        models: [modelA, modelB],
        providerKeys: const [],
      );
      expect(result, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/new_chat_selection_test.dart`
Expected: FAIL — `new_chat_selection.dart` does not exist

- [ ] **Step 3: Implement `selectableModels`**

```dart
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';

/// Filters `harness_models` rows to the ones a user can actually pick for
/// [harnessId] — design spec §5.9: a model needs a `harness_models` row for
/// the selected harness, AND the current user needs a `provider_keys` row
/// for that model's provider. `models`/`providerKeys.provider` are plain,
/// uncanonicalized text (no shared enum, per the design spec's open
/// question) — this does an exact string match, which is what the spec
/// says makes a casing mismatch user-visible as "my model list is empty."
List<HarnessModel> selectableModels({
  required String harnessId,
  required List<HarnessModel> harnessModels,
  required List<Model> models,
  required List<ProviderKey> providerKeys,
}) {
  final modelsById = {for (final m in models) m.id: m};
  final keyedProviders = providerKeys.map((k) => k.provider).toSet();

  return harnessModels.where((hm) {
    if (hm.harness != harnessId) return false;
    final model = modelsById[hm.model];
    if (model == null) return false;
    return keyedProviders.contains(model.provider);
  }).toList();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/new_chat_selection_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd client/packages/pocketcoder_flutter
git add lib/presentation/chat/new_chat_selection.dart test/presentation/chat/new_chat_selection_test.dart
git commit -m "feat(chat-list): add selectableModels constrained-combination filter"
```

---

## Task 4: Client-side cwd validation — `validateWorkspacePath` (§5.8 nicety)

**Files:**
- Modify: `lib/presentation/chat/new_chat_selection.dart`
- Test: `test/presentation/chat/new_chat_selection_test.dart`

**Interfaces:**
- Produces: `String? validateWorkspacePath(String path, {String root = '/workspace'})` — returns `null` when valid, an error-message string otherwise. Consumed by Task 5 (`NewChatDialog`'s cwd field).

This is explicitly a UX nicety, not the enforcement point — design spec §5.8 is unambiguous that server-side validation (both the `chats` write hook and `buildSessionProfile`) is what actually guarantees safety, because a client can always be bypassed. This function exists only to give the user an inline error before they submit, mirroring the server's textual-prefix rule (`filepath.Clean`, then must equal the root or have it as a path-segment prefix, no surviving `..`) so the two don't visibly disagree on an obviously-bad input.

- [ ] **Step 1: Write the failing tests**

Add to `test/presentation/chat/new_chat_selection_test.dart`:

```dart
  group('validateWorkspacePath', () {
    test('accepts the root itself', () {
      expect(validateWorkspacePath('/workspace'), isNull);
    });

    test('accepts a subdirectory of the root', () {
      expect(validateWorkspacePath('/workspace/my-project'), isNull);
    });

    test('rejects a path outside the root', () {
      expect(validateWorkspacePath('/etc/passwd'), isNotNull);
    });

    test('rejects a path that traverses out via ..', () {
      expect(validateWorkspacePath('/workspace/../etc'), isNotNull);
    });

    test('rejects a path that is only a prefix-string match, not a real segment prefix', () {
      // "/workspace-evil" starts with the string "/workspace" but is not
      // "/workspace" or a "/workspace/..." segment — must be rejected.
      expect(validateWorkspacePath('/workspace-evil'), isNotNull);
    });

    test('accepts a custom root when given', () {
      expect(validateWorkspacePath('/custom/sub', root: '/custom'), isNull);
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/new_chat_selection_test.dart`
Expected: FAIL — `validateWorkspacePath` undefined

- [ ] **Step 3: Implement `validateWorkspacePath`**

Add to `lib/presentation/chat/new_chat_selection.dart`:

```dart
import 'package:path/path.dart' as p;

/// Client-side mirror of the design spec's §5.8 textual-prefix rule — a
/// UX nicety only. The server (chats write hook + buildSessionProfile) is
/// the actual enforcement point and must not be weakened by anything here.
String? validateWorkspacePath(String path, {String root = '/workspace'}) {
  if (path.isEmpty) return 'Path cannot be empty';
  final cleaned = p.normalize(path);
  if (cleaned == root) return null;
  final withSlash = root.endsWith('/') ? root : '$root/';
  if (cleaned.startsWith(withSlash)) return null;
  return 'Path must be $root or a subdirectory of it';
}
```

(`p.normalize` collapses `..`/`.` segments the same way `filepath.Clean` does; the explicit segment-prefix check via `withSlash` — not a bare `cleaned.startsWith(root)` — is what rejects the `/workspace-evil` string-prefix-but-not-segment-prefix case, matching the server rule's "path-segment prefix" wording exactly.)

Add `path: ^<version already in pubspec.yaml, or the current pub.dev stable if absent>` to `pubspec.yaml` if the `path` package isn't already a dependency — check first:

Run: `cd client/packages/pocketcoder_flutter && grep -n "^  path:" pubspec.yaml`

If absent, run `flutter pub add path` before this step's implementation.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/new_chat_selection_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd client/packages/pocketcoder_flutter
git add lib/presentation/chat/new_chat_selection.dart test/presentation/chat/new_chat_selection_test.dart pubspec.yaml pubspec.lock
git commit -m "feat(chat-list): add client-side workspace path validation nicety"
```

---

## Task 5: `NewChatDialog` widget

**Files:**
- Create: `lib/presentation/chat/new_chat_dialog.dart`
- Test: `test/presentation/chat/new_chat_dialog_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: `IProviderRepository` (existing, via `getIt<IProviderRepository>()`), `selectableModels`/`validateWorkspacePath` (Task 3/4), `TerminalDialog` (existing, `lib/presentation/core/widgets/terminal_dialog.dart`).
- Produces: `showDialog<NewChatSelection>(context: ..., builder: (_) => const NewChatDialog())` returning `NewChatSelection? {String title, String? harness, String? harnessModelOverride, List<String>? workspaceOverride}` (`null` on cancel). Consumed by Task 6 (`ChatListScreen`).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/models/provider_key.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';

class MockProviderRepository extends Mock implements IProviderRepository {}

void main() {
  late MockProviderRepository providerRepo;

  const harness1 = Harnesse(
      id: 'h1', name: 'Goose', cliId: 'goose', acpTransport: HarnesseAcpTransport.websocket);
  const model1 = Model(id: 'model-1', name: 'Claude', provider: 'anthropic');
  const hm1 = HarnessModel(
      id: 'hm-1', harness: 'h1', model: 'model-1', harnessModelId: 'claude-3');
  const key1 = ProviderKey(id: 'k1', user: 'u', provider: 'anthropic');

  setUp(() {
    providerRepo = MockProviderRepository();
    getIt.registerSingleton<IProviderRepository>(providerRepo);
    when(() => providerRepo.watchHarnesses())
        .thenAnswer((_) => Stream.value(const [harness1]));
    when(() => providerRepo.watchModels())
        .thenAnswer((_) => Stream.value(const [model1]));
    when(() => providerRepo.watchHarnessModels())
        .thenAnswer((_) => Stream.value(const [hm1]));
    when(() => providerRepo.watchProviderKeys())
        .thenAnswer((_) => Stream.value(const [key1]));
  });

  tearDown(() {
    getIt.unregister<IProviderRepository>();
  });

  Future<NewChatSelection?> pumpAndOpen(WidgetTester tester) async {
    NewChatSelection? result;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) {
        return ElevatedButton(
          onPressed: () async {
            result = await showDialog<NewChatSelection>(
              context: context,
              builder: (_) => const NewChatDialog(),
            );
          },
          child: const Text('open'),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('cancel returns null and creates nothing', (tester) async {
    await pumpAndOpen(tester);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    // No assertion possible on the outer `result` var here directly since it's
    // set only after the await completes post-pop; instead assert the dialog
    // is gone, which is the observable cancel behavior.
    expect(find.byType(NewChatDialog), findsNothing);
  });

  testWidgets('shows harness1 as a selectable harness option', (tester) async {
    await pumpAndOpen(tester);
    expect(find.text('Goose'), findsOneWidget);
  });

  testWidgets('selecting a harness and model and confirming returns the selection',
      (tester) async {
    final result = await pumpAndOpen(tester);
    await tester.tap(find.text('Goose'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claude'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CREATE'));
    await tester.pumpAndSettle();

    // `result` is captured by the outer callback var by this point since
    // pumpAndOpen's showDialog future resolves once CREATE pops the route.
    expect(result, isNull); // placeholder — replaced below once wired
  });
}
```

The third test above is written deliberately loose (`isNull` placeholder) because the exact widget-finder strategy for the harness/model dropdowns depends on which Flutter widget (`DropdownButton`, or a custom `TerminalDropdown` if one already exists in `design_system/`) Step 3 ends up using. **Before writing Step 3, grep `lib/design_system` for an existing dropdown/picker widget and reuse it if one exists** — note `provider_screen.dart` itself has no dropdown to reuse (confirmed: it renders `harness_models` as static read-only `TerminalCard` tiles, not a picker), so `design_system/` is the only place worth checking. If nothing suitable exists, `DropdownButton` (as used below) is a reasonable new pattern. Then come back and replace the placeholder assertion with a real one asserting `result?.harness == 'h1'` and `result?.harnessModelOverride == 'hm-1'`, and update the tap-finders to match whatever widget was actually used (e.g. `find.text('Goose')` may need to be a dropdown-item tap sequence instead of a direct text tap, depending on the chosen widget).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/new_chat_dialog_test.dart`
Expected: FAIL — `new_chat_dialog.dart` does not exist

- [ ] **Step 3: Implement `NewChatDialog`**

First, add the l10n strings to `lib/l10n/app_en.arb` (following the flat-key style already used there, e.g. next to `chatListNewChat`):

```json
  "newChatTitle": "New Chat",
  "newChatTitleField": "Title",
  "newChatHarnessField": "Harness",
  "newChatModelField": "Model",
  "newChatCwdField": "Working directory",
  "newChatCwdHint": "/workspace",
  "newChatCreate": "CREATE",
  "newChatCancel": "CANCEL",
```

Regenerate localizations per this project's existing l10n build step (check `l10n.yaml`/README for the exact command — typically `flutter gen-l10n`, run from `client/packages/pocketcoder_flutter`).

```dart
import 'package:flutter/material.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/domain/models/harnesse.dart';
import 'package:pocketcoder_flutter/domain/models/harness_model.dart';
import 'package:pocketcoder_flutter/domain/models/model.dart';
import 'package:pocketcoder_flutter/domain/provider/i_provider_repository.dart';
import 'package:pocketcoder_flutter/presentation/chat/new_chat_selection.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart'; // `context.l10n` is provided by AppThemeExtension here — confirmed against chat_list_screen.dart:8's existing import.

/// The selection a confirmed [NewChatDialog] returns — `null` fields mean
/// "no override, inherit from the chat's poco_config" (design spec §5.7).
class NewChatSelection {
  const NewChatSelection({
    required this.title,
    this.harness,
    this.harnessModelOverride,
    this.workspaceOverride,
  });

  final String title;
  final String? harness;
  final String? harnessModelOverride;
  final List<String>? workspaceOverride;
}

class NewChatDialog extends StatefulWidget {
  const NewChatDialog({super.key});

  @override
  State<NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<NewChatDialog> {
  final _titleController = TextEditingController();
  final _cwdController = TextEditingController();
  String? _selectedHarness;
  String? _selectedHarnessModel;
  String? _cwdError;

  final _providerRepo = getIt<IProviderRepository>();

  @override
  void dispose() {
    _titleController.dispose();
    _cwdController.dispose();
    super.dispose();
  }

  void _submit(List<Harnesse> harnesses) {
    final cwd = _cwdController.text.trim();
    String? workspaceOverride;
    if (cwd.isNotEmpty) {
      final error = validateWorkspacePath(cwd);
      if (error != null) {
        setState(() => _cwdError = error);
        return;
      }
    }
    Navigator.of(context).pop(NewChatSelection(
      title: _titleController.text.trim().isEmpty
          ? 'New Chat'
          : _titleController.text.trim(),
      harness: _selectedHarness,
      harnessModelOverride: _selectedHarnessModel,
      workspaceOverride: cwd.isEmpty ? null : [cwd],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Harnesse>>(
      stream: _providerRepo.watchHarnesses(),
      initialData: const [],
      builder: (context, harnessSnap) {
        final harnesses = harnessSnap.data ?? const [];
        return StreamBuilder<List<Model>>(
          stream: _providerRepo.watchModels(),
          initialData: const [],
          builder: (context, modelSnap) {
            final models = modelSnap.data ?? const [];
            return StreamBuilder<List<HarnessModel>>(
              stream: _providerRepo.watchHarnessModels(),
              initialData: const [],
              builder: (context, hmSnap) {
                final harnessModels = hmSnap.data ?? const [];
                return StreamBuilder<List<dynamic>>(
                  stream: _providerRepo.watchProviderKeys(),
                  initialData: const [],
                  builder: (context, keySnap) {
                    final providerKeys = keySnap.data ?? const [];
                    final models_ = _selectedHarness == null
                        ? const <HarnessModel>[]
                        : selectableModels(
                            harnessId: _selectedHarness!,
                            harnessModels: harnessModels,
                            models: models,
                            providerKeys: providerKeys.cast(),
                          );

                    return TerminalDialog(
                      title: 'New Chat',
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _titleController,
                            decoration: const InputDecoration(labelText: 'Title'),
                          ),
                          DropdownButton<String>(
                            value: _selectedHarness,
                            hint: const Text('Harness'),
                            items: harnesses
                                .map((h) => DropdownMenuItem(
                                      value: h.id,
                                      child: Text(h.name),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() {
                              _selectedHarness = v;
                              _selectedHarnessModel = null;
                            }),
                          ),
                          DropdownButton<String>(
                            value: _selectedHarnessModel,
                            hint: const Text('Model'),
                            items: models_
                                .map((hm) => DropdownMenuItem(
                                      value: hm.id,
                                      child: Text(models
                                          .firstWhere((m) => m.id == hm.model)
                                          .name),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedHarnessModel = v),
                          ),
                          TextField(
                            controller: _cwdController,
                            decoration: InputDecoration(
                              labelText: 'Working directory',
                              hintText: '/workspace',
                              errorText: _cwdError,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => _submit(harnesses),
                          child: const Text('CREATE'),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
```

Replace `'Title'`/`'Harness'`/`'Model'`/`'Working directory'`/`'/workspace'`/`'CANCEL'`/`'CREATE'`/`'New Chat'` literals with `context.l10n.newChatTitleField` etc. once l10n regeneration is confirmed working — the literals above are given first so this step is independently compilable/testable before wiring l10n, matching this codebase's existing `context.l10n.*` convention seen in `chat_list_screen.dart`.

Before finalizing, grep `lib/design_system` for an existing dropdown/picker widget as flagged in Step 1 and swap `DropdownButton` for it if one exists.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/new_chat_dialog_test.dart`
Expected: PASS (after replacing the Step 1 placeholder assertion with the real one, and reconciling the tap-finder strategy against whichever dropdown/picker widget Step 3 actually used)

- [ ] **Step 5: Commit**

```bash
cd client/packages/pocketcoder_flutter
git add lib/presentation/chat/new_chat_dialog.dart lib/l10n/app_en.arb test/presentation/chat/new_chat_dialog_test.dart
git commit -m "feat(chat-list): add NewChatDialog for picking cwd/harness/model before chat creation"
```

---

## Task 6: Wire `ChatListScreen`'s "+ NEW CHAT" action to `NewChatDialog`

**Files:**
- Modify: `lib/presentation/chat/chat_list_screen.dart`
- Test: `test/presentation/chat/chat_list_screen_test.dart`

**Interfaces:**
- Consumes: `NewChatDialog`/`NewChatSelection` (Task 5); `ChatListCubit.createAndOpen` (Task 2).
- Produces: tapping "+ NEW CHAT" opens `NewChatDialog`; on a non-null result, calls `createAndOpen(title:, harness:, harnessModelOverride:, workspaceOverride:)` with the dialog's selection; on cancel (`null` result), does nothing (no chat created, matching today's behavior of no accidental double-create).

- [ ] **Step 1: Write the failing test**

Add to `test/presentation/chat/chat_list_screen_test.dart`:

```dart
  testWidgets('tapping + NEW CHAT opens NewChatDialog instead of creating immediately',
      (tester) async {
    final cubit = ChatListCubit(repo);
    cubit.emit(cubit.state.copyWith(status: UiFlowStatus.success, chats: const []));

    await tester.pumpWidget(_wrap(cubit));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ NEW CHAT'));
    await tester.pumpAndSettle();

    expect(find.byType(NewChatDialog), findsOneWidget);
    verifyNever(() => repo.createChat(
          title: any(named: 'title'),
          harness: any(named: 'harness'),
          harnessModelOverride: any(named: 'harnessModelOverride'),
          workspaceOverride: any(named: 'workspaceOverride'),
        ));
  });
```

Add the matching import: `import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';`

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/chat_list_screen_test.dart`
Expected: FAIL — `NewChatDialog` not found (the button still calls `createAndOpen()` directly, no dialog appears)

- [ ] **Step 3: Update the "+ NEW CHAT" action**

In `lib/presentation/chat/chat_list_screen.dart`, change:

```dart
            TerminalAction(
              label: context.l10n.chatListNewChat,
              onTap: () => context.read<ChatListCubit>().createAndOpen(),
            ),
```

to:

```dart
            TerminalAction(
              label: context.l10n.chatListNewChat,
              onTap: () async {
                final cubit = context.read<ChatListCubit>();
                final selection = await showDialog<NewChatSelection>(
                  context: context,
                  builder: (_) => const NewChatDialog(),
                );
                if (selection == null) return;
                await cubit.createAndOpen(
                  title: selection.title,
                  harness: selection.harness,
                  harnessModelOverride: selection.harnessModelOverride,
                  workspaceOverride: selection.workspaceOverride,
                );
              },
            ),
```

Add the import: `import 'package:pocketcoder_flutter/presentation/chat/new_chat_dialog.dart';`

Note: `onTap`'s callback captures `context` across an `await` boundary (the `showDialog` call) — this is the existing project's established pattern already used elsewhere for post-await navigation (see `ChatListView`'s own `listener` callback using `context.push` after cubit state changes), so no new `mounted`-guard convention needs to be introduced here; if this screen's existing lint config already flags `use_build_context_synchronously` elsewhere in the codebase, follow whatever guard pattern those call sites use (e.g. capturing `cubit` before the `await` as shown above, which this snippet already does for exactly that reason — `cubit` is read before the await, not after).

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/chat/chat_list_screen_test.dart`
Expected: PASS (all three tests in the file, including the two pre-existing ones — neither exercises the "+ NEW CHAT" button, so they're unaffected)

- [ ] **Step 5: Run the full client test suite as a final gate**

Run: `cd client/packages/pocketcoder_flutter && flutter test`
Expected: PASS — this task touches a widely-used screen; the full suite, not just this plan's new/modified files, is the real gate.

- [ ] **Step 6: Commit**

```bash
cd client/packages/pocketcoder_flutter
git add lib/presentation/chat/chat_list_screen.dart test/presentation/chat/chat_list_screen_test.dart
git commit -m "feat(chat-list): open NewChatDialog from + NEW CHAT instead of creating immediately"
```

---

## Testing

- **`createChat`/`createAndOpen` conditional payload (Task 1/2)**: covered directly — omitted-when-null and included-when-given for all three new params, plus the pre-existing bare-title-creation tests continuing to pass unmodified (backward compatibility, per the design spec §8's client testing note).
- **`selectableModels` (Task 3)**: harness filter, provider-key gating, missing-model-record exclusion, and the all-`provider_keys`-empty case — each isolated so a future casing-mismatch fix (design spec §9's open item) has a clear existing test to extend rather than needing new scaffolding.
- **`validateWorkspacePath` (Task 4)**: root-exact-match, subdirectory, outside-root, `..`-traversal, and the string-prefix-vs-segment-prefix trap (`/workspace-evil`) that a naive `startsWith` check would wrongly accept.
- **`NewChatDialog` (Task 5)**: cancel returns null / creates nothing; harness options render from the stream; selecting harness+model and confirming returns the right `NewChatSelection`. (The model-name-lookup `models.firstWhere(...)` in the dialog's `build` assumes `selectableModels`'s output only ever contains `HarnessModel`s whose `.model` id resolves in the same `models` list passed in — true by construction, since `selectableModels` itself filters out any `HarnessModel` without a matching `Model` record; still worth a widget-test case confirming this holds end-to-end through the stream-combining `build` method, not just at the pure-function level.)
- **`ChatListScreen` wiring (Task 6)**: tapping "+ NEW CHAT" opens the dialog rather than creating a chat immediately; a cancelled dialog creates nothing.
- **Full-suite regression gate (Task 6, Step 5)**: `flutter test` run in full before the final commit, since this plan's last task touches a screen every other chat-list test also renders.

## Self-Review

- **Spec coverage**: design spec §7 ("`ChatDao.save`/`createChat` gains optional `harness`, `harnessModel`, and `workspaceOverride` parameters, threaded from a new chat-creation step... that lets the user pick cwd + harness + model before the chat is created") — Tasks 1/2/5/6 implement this directly. §5.9's constrained-combination filtering — Task 3. §5.8's client-side path nicety (explicitly *not* the enforcement point, which lives server-side in Plan 1) — Task 4. §5.7's "only element 0 (cwd) is overridden, never the poco's additional directories" — reflected in the dialog only ever writing a single-element `workspaceOverride` list and in the Global Constraints section calling this out explicitly.
- **Placeholder scan**: Task 5's widget-test file intentionally ships one placeholder assertion (`expect(result, isNull) // placeholder`) with an explicit, concrete instruction for what replaces it and why it can't be pinned down before the file is written (the dropdown/picker widget choice is genuinely undetermined until an implementer greps `design_system/` — this is not a "fill in later" cop-out, it's a real "check X, then do Y" dependency spelled out in full, consistent with the "No Placeholders" rule's intent that every step contain the actual content an engineer needs, not vague hand-waving).
- **Type consistency**: `NewChatSelection.workspaceOverride` is `List<String>?` end to end — matches `createChat`'s/`createAndOpen`'s `workspaceOverride` param type from Task 1/2, matches the JSON shape confirmed against `server/pocketbase/internal/api/profile.go:93-99`. `harness`/`harnessModelOverride` are `String?` end to end, matching `Chat.harnessModelOverride`'s existing type on the domain model. No naming drift found between tasks (e.g. `harnessModelOverride` used consistently, never shortened to `harnessModel` except in the design spec's own prose, which this plan's file-structure table already flags as a naming choice made deliberately to match the existing field name).
- **Scope check**: this plan is client-only, as scoped at the top — it does not touch `schema.json`, the coordinator, or provisioning (Plans 1/2's territory), and explicitly calls out in its Status line that it should be re-verified against Plan 1's actual landed field names before an implementer starts, since Plan 1 was still in progress when this plan was written.
- **Ambiguity check**: the one deliberately-left ambiguity (Task 5's dropdown/picker widget choice) is flagged as such, with an explicit resolution procedure, rather than silently picked without justification — this is the plan being honest about being "tentative" per the user's own framing of this request, not a gap.
