# Tool-Permissions UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter screen that lets a human view and edit `tool_permissions` rows (allow/ask/deny per tool), fixing the currently-dead "TOOL PERMISSIONS" Settings button, without touching PocketBase schema or the existing live-delivery mechanism.

**Architecture:** New DAO → repository → cubit → screen stack in `client/packages/pocketcoder_flutter`, mirroring the already-shipped MCP governance UI's file shapes exactly (`ToolPermissionDao`/`ToolPermissionRepository`/`ToolPermissionsCubit`/`ToolPermissionsScreen` mirror `McpServerDao`/`McpRepository`/`McpCubit`/`McpManagementScreen`). Rows are scoped to `poco_config = ""` (global) only. One Go doc-comment edit; no other backend changes.

**Tech Stack:** Flutter/Dart, Freezed, injectable/GetIt, flutter_bloc (Cubit), mocktail, pocketbase_drift.

## Global Constraints

- No PocketBase schema changes. No new PocketBase migrations.
- No changes to `RenderToolPermissions`'s logic, `deliverToolPermissions`, or `activeToolPermissionRows` — doc-comment only (Task 1).
- Every row created by this UI writes `pattern: "*"` — the field is never shown in any form (spec Component 2).
- `poco_config` and `sandbox_config` are never written by this UI — always omitted, which PocketBase defaults to `""` (spec Component 1).
- `watchRules()` must not filter on `active` — inactive rows stay visible so they can be re-enabled (spec Component 1 / self-review fix).
- `watchRules()` must not be wrapped in `tryMethod` — it returns a `Stream`, not a `Future` (spec Component 3 / Sonnet review fix).
- Follow `client/CLAUDE.md`: never use `!`; cubits extend the pattern already used by the file being mirrored (`McpCubit` — a plain `Cubit<T>`, not `AppCubit<T>`/`tryOperation`, per the spec's noted pre-existing deviation this plan does not fix); every repository method wrapped in `tryMethod` except stream-returning ones; run `dart run build_runner build --delete-conflicting-outputs` from `client/packages/pocketcoder_flutter` after adding `@freezed`/`@injectable`/`@lazySingleton` annotations.

---

### Task 1: Document the `pattern` field's dead status in the backend

**Files:**
- Modify: `services/pocketbase/internal/gooseconfig/permissions.go:51-58` (doc comment on `RenderToolPermissions`)

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new — this is a comment-only change. `RenderToolPermissions`'s signature, behavior, and existing tests (`permissions_test.go`) are unchanged.

No behavior changes in this task, so no new test — the existing test suite is the regression check.

- [ ] **Step 1: Confirm the current doc comment and existing tests**

Run: `cd services/pocketbase && go test ./internal/gooseconfig/... -v -run TestRenderToolPermissions`
Expected: `PASS` for `TestRenderToolPermissions_PatternDropped`, `TestRenderToolPermissions_NoRulesOmits`, and any other `TestRenderToolPermissions*` tests, unchanged.

- [ ] **Step 2: Update the doc comment**

Open `services/pocketbase/internal/gooseconfig/permissions.go` and replace the comment above `func RenderToolPermissions` (currently lines 51-58) with:

```go
// RenderToolPermissions maps tool_permissions rows onto Goose's per-tool
// tools/permissions/set entries. A non-"*" pattern is NOT dropped from the
// resulting entry — Goose's ToolPermissionEntry is tool-name-only (verified
// against acp-schema.json's ToolPermissionEntry def and the exact-match
// lookup in Goose's permission.rs), so the pattern value is ignored and the
// row's action still produces an entry; only a diagnostic note is added to
// the dropped-reasons slice. Callers that write new rows should always use
// pattern "*" (the Tool-Permissions UI does — see
// docs/superpowers/specs/2026-07-23-tool-permissions-ui-design.md) since
// any other pattern value is enforcement-misleading, not enforcement-inert.
// Same-tool conflicts resolve deny > ask > allow — deny always wins (noted
// in dropped); otherwise ask beats allow only because a tool can carry both
// an explicit ask row and a broader allow row and the more cautious one
// should apply. Unlike the old config.yaml allowlist, "ask" is never
// dropped — ask_before is a real permission level here.
```

- [ ] **Step 3: Run the full gooseconfig test suite to confirm no regressions**

Run: `cd services/pocketbase && go build ./... && go test ./internal/gooseconfig/...`
Expected: `ok  	github.com/qtpi-automaton/pocketcoder/backend/internal/gooseconfig`

- [ ] **Step 4: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add services/pocketbase/internal/gooseconfig/permissions.go
git commit -m "docs(gooseconfig): clarify RenderToolPermissions' pattern-field handling"
```

---

### Task 2: `ToolPermissionDao` + `IToolPermissionRepository`/`ToolPermissionRepository`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/tool_permissions/tool_permission_daos.dart`
- Create: `client/packages/pocketcoder_flutter/lib/domain/tool_permissions/i_tool_permission_repository.dart`
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/tool_permissions/tool_permission_repository.dart`
- Create: `client/packages/pocketcoder_flutter/test/infrastructure/tool_permissions/tool_permission_repository_test.dart`
- Delete: `client/packages/pocketcoder_flutter/lib/domain/exceptions/tool_permissions_exception.dart`

**Interfaces:**
- Consumes: `ToolPermission` (`lib/domain/models/tool_permission.dart`, already exists — fields `id, tool, pattern, action: ToolPermissionAction, active?, pocoConfig?, sandboxConfig?`); `ToolPermissionsException` (`lib/domain/exceptions.dart:57-64`, already exists — `ToolPermissionsException(String message, [Object? cause])`, extends `DomainException`); `Collections.toolPermissions` (`lib/domain/models/collections.dart:7`, already exists, value `'tool_permissions'`); `BaseDao<T>` (`lib/infrastructure/core/base_dao.dart` — `watch({filter, sort, expand})`, `save(String? id, Map<String, dynamic> data)`); `tryMethod` (`lib/core/try_operation.dart` — `Future<T> Function() method, E Function(String, [Object?]) wrapException, String methodName`).
- Produces: `ToolPermissionDao` (class, `@lazySingleton`, constructor `ToolPermissionDao(PocketBase pb)`). `IToolPermissionRepository` (abstract interface: `Stream<List<ToolPermission>> watchRules()`, `Future<void> createRule({required String tool, required String action})`, `Future<void> updateAction(String id, String action)`, `Future<void> setActive(String id, bool active)`). `ToolPermissionRepository` (`@LazySingleton(as: IToolPermissionRepository)`, constructor `ToolPermissionRepository(ToolPermissionDao dao)`) — Task 3's cubit consumes `IToolPermissionRepository` by these exact method signatures.

First, confirm the dead exception file is truly unreferenced before deleting it (the spec's claim, re-verify locally in case something changed):

- [ ] **Step 1: Verify the standalone exception file is unreferenced, then delete it**

Run: `cd client/packages/pocketcoder_flutter && grep -rn "tool_permissions_exception.dart" lib test`
Expected: no output (no other file imports it).

```bash
git rm client/packages/pocketcoder_flutter/lib/domain/exceptions/tool_permissions_exception.dart
```

- [ ] **Step 2: Write the failing repository tests**

Create `client/packages/pocketcoder_flutter/test/infrastructure/tool_permissions/tool_permission_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/infrastructure/tool_permissions/tool_permission_daos.dart';
import 'package:pocketcoder_flutter/infrastructure/tool_permissions/tool_permission_repository.dart';

class MockToolPermissionDao extends Mock implements ToolPermissionDao {}

class _FakeToolPermission extends Fake implements ToolPermission {}

void main() {
  late ToolPermissionRepository repo;
  late MockToolPermissionDao dao;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    dao = MockToolPermissionDao();
    repo = ToolPermissionRepository(dao);
  });

  group('ToolPermissionRepository.watchRules', () {
    test('watches with poco_config="" filter, sorted by tool', () async {
      when(() => dao.watch(filter: any(named: 'filter'), sort: any(named: 'sort')))
          .thenAnswer((_) => const Stream.empty());

      repo.watchRules();

      verify(() => dao.watch(filter: 'poco_config = ""', sort: 'tool'))
          .called(1);
    });
  });

  group('ToolPermissionRepository.createRule', () {
    test('creates a tool_permissions row with pattern "*" and active true',
        () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeToolPermission());

      await repo.createRule(tool: 'bash', action: 'allow');

      verify(() => dao.save(null, {
            'tool': 'bash',
            'pattern': '*',
            'action': 'allow',
            'active': true,
          })).called(1);
    });

    test('wraps failures in ToolPermissionsException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.createRule(tool: 'bash', action: 'allow'),
        throwsA(isA<ToolPermissionsException>()),
      );
    });
  });

  group('ToolPermissionRepository.updateAction', () {
    test('saves only the action field', () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeToolPermission());

      await repo.updateAction('rule-1', 'deny');

      verify(() => dao.save('rule-1', {'action': 'deny'})).called(1);
    });

    test('wraps failures in ToolPermissionsException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.updateAction('rule-1', 'deny'),
        throwsA(isA<ToolPermissionsException>()),
      );
    });
  });

  group('ToolPermissionRepository.setActive', () {
    test('saves only the active field', () async {
      when(() => dao.save(any(), any()))
          .thenAnswer((_) async => _FakeToolPermission());

      await repo.setActive('rule-1', false);

      verify(() => dao.save('rule-1', {'active': false})).called(1);
    });

    test('wraps failures in ToolPermissionsException', () async {
      when(() => dao.save(any(), any())).thenThrow(Exception('boom'));

      await expectLater(
        () => repo.setActive('rule-1', false),
        throwsA(isA<ToolPermissionsException>()),
      );
    });
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/tool_permissions/tool_permission_repository_test.dart`
Expected: FAIL — compile error, `tool_permission_daos.dart`/`tool_permission_repository.dart` don't exist yet.

- [ ] **Step 4: Create the DAO**

Create `client/packages/pocketcoder_flutter/lib/infrastructure/tool_permissions/tool_permission_daos.dart`:

```dart
import 'package:injectable/injectable.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/infrastructure/core/base_dao.dart';
import "package:pocketcoder_flutter/domain/models/collections.dart";

@lazySingleton
class ToolPermissionDao extends BaseDao<ToolPermission> {
  ToolPermissionDao(PocketBase pb)
      : super(pb, Collections.toolPermissions, ToolPermission.fromJson);
}
```

- [ ] **Step 5: Create the repository interface**

Create `client/packages/pocketcoder_flutter/lib/domain/tool_permissions/i_tool_permission_repository.dart`:

```dart
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';

abstract class IToolPermissionRepository {
  Stream<List<ToolPermission>> watchRules();
  Future<void> createRule({required String tool, required String action});
  Future<void> updateAction(String id, String action);
  Future<void> setActive(String id, bool active);
}
```

- [ ] **Step 6: Create the repository implementation**

Create `client/packages/pocketcoder_flutter/lib/infrastructure/tool_permissions/tool_permission_repository.dart`:

```dart
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'tool_permission_daos.dart';

@LazySingleton(as: IToolPermissionRepository)
class ToolPermissionRepository implements IToolPermissionRepository {
  final ToolPermissionDao _toolPermissionDao;

  ToolPermissionRepository(this._toolPermissionDao);

  @override
  Stream<List<ToolPermission>> watchRules() {
    return _toolPermissionDao.watch(filter: 'poco_config = ""', sort: 'tool');
  }

  @override
  Future<void> createRule({required String tool, required String action}) async {
    return tryMethod(
      () async {
        await _toolPermissionDao.save(null, {
          'tool': tool,
          'pattern': '*',
          'action': action,
          'active': true,
        });
      },
      ToolPermissionsException.new,
      'createRule',
    );
  }

  @override
  Future<void> updateAction(String id, String action) async {
    return tryMethod(
      () async {
        await _toolPermissionDao.save(id, {'action': action});
      },
      ToolPermissionsException.new,
      'updateAction',
    );
  }

  @override
  Future<void> setActive(String id, bool active) async {
    return tryMethod(
      () async {
        await _toolPermissionDao.save(id, {'active': active});
      },
      ToolPermissionsException.new,
      'setActive',
    );
  }
}
```

- [ ] **Step 7: Regenerate DI registrations**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: build succeeds; `lib/app/bootstrap.config.dart` now contains `gh.lazySingleton<ToolPermissionDao>(...)` and `gh.lazySingleton<IToolPermissionRepository>(...)` entries (grep for `ToolPermissionDao` in that file to confirm).

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/tool_permissions/tool_permission_repository_test.dart`
Expected: `PASS`, all 7 tests green.

- [ ] **Step 9: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/infrastructure/tool_permissions/ \
        client/packages/pocketcoder_flutter/lib/domain/tool_permissions/ \
        client/packages/pocketcoder_flutter/test/infrastructure/tool_permissions/ \
        client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart \
        client/packages/pocketcoder_flutter/lib/domain/exceptions/tool_permissions_exception.dart
git commit -m "feat(tool-permissions): add ToolPermissionDao/ToolPermissionRepository, remove dead duplicate exception"
```

---

### Task 3: `ToolPermissionsState` + `ToolPermissionsCubit`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/application/tool_permissions/tool_permissions_state.dart`
- Create: `client/packages/pocketcoder_flutter/lib/application/tool_permissions/tool_permissions_cubit.dart`
- Create: `client/packages/pocketcoder_flutter/test/application/tool_permissions/tool_permissions_cubit_test.dart`

**Interfaces:**
- Consumes: `IToolPermissionRepository` (Task 2's exact signatures above); `ToolPermission` model; `logError` (`lib/infrastructure/core/logger.dart`, already used by `McpCubit`).
- Produces: `ToolPermissionsState` (Freezed sealed class, 4 variants: `.initial()`, `.loading()`, `.loaded(List<ToolPermission> rules)`, `.error(String message)`, implements `IUiFlowState`). `ToolPermissionsCubit` (`@injectable`, constructor `ToolPermissionsCubit(IToolPermissionRepository repository)`, methods `watchRules()`, `Future<void> updateAction(String id, String action)`, `Future<void> setActive(String id, bool active)`, `Future<void> createRule({required String tool, required String action})`) — Task 5's screen consumes this cubit and state by these exact names.

- [ ] **Step 1: Write the failing cubit test**

Create `client/packages/pocketcoder_flutter/test/application/tool_permissions/tool_permissions_cubit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart';
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart';

class MockToolPermissionRepository extends Mock
    implements IToolPermissionRepository {}

void main() {
  late MockToolPermissionRepository repo;
  ToolPermissionsCubit? lastCubit;

  ToolPermissionsCubit buildCubit() {
    final cubit = ToolPermissionsCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockToolPermissionRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('ToolPermissionsCubit.createRule', () {
    test('calls repository.createRule with the given fields', () async {
      when(() => repo.createRule(
            tool: any(named: 'tool'),
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.createRule(tool: 'bash', action: 'allow');

      verify(() => repo.createRule(tool: 'bash', action: 'allow')).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.createRule(
            tool: any(named: 'tool'),
            action: any(named: 'action'),
          )).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.createRule(tool: 'bash', action: 'allow');

      expect(cubit.state.hasError, isTrue);
    });
  });

  group('ToolPermissionsCubit.updateAction', () {
    test('calls repository.updateAction with the given fields', () async {
      when(() => repo.updateAction(any(), any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.updateAction('rule-1', 'deny');

      verify(() => repo.updateAction('rule-1', 'deny')).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.updateAction(any(), any())).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.updateAction('rule-1', 'deny');

      expect(cubit.state.hasError, isTrue);
    });
  });

  group('ToolPermissionsCubit.setActive', () {
    test('calls repository.setActive with the given fields', () async {
      when(() => repo.setActive(any(), any())).thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.setActive('rule-1', false);

      verify(() => repo.setActive('rule-1', false)).called(1);
    });

    test('emits error state on repository failure', () async {
      when(() => repo.setActive(any(), any())).thenThrow(Exception('boom'));

      final cubit = buildCubit();
      await cubit.setActive('rule-1', false);

      expect(cubit.state.hasError, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/tool_permissions/tool_permissions_cubit_test.dart`
Expected: FAIL — compile error, `tool_permissions_cubit.dart`/`i_tool_permission_repository.dart` import unresolved (the cubit file doesn't exist yet).

- [ ] **Step 3: Create the state**

Create `client/packages/pocketcoder_flutter/lib/application/tool_permissions/tool_permissions_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';

part 'tool_permissions_state.freezed.dart';

@freezed
sealed class ToolPermissionsState with _$ToolPermissionsState
    implements IUiFlowState {
  const ToolPermissionsState._();

  const factory ToolPermissionsState.initial() = _Initial;
  const factory ToolPermissionsState.loading() = _Loading;
  const factory ToolPermissionsState.loaded(List<ToolPermission> rules) =
      _Loaded;
  const factory ToolPermissionsState.error(String message) = _Error;

  @override
  UiFlowStatus get status => when(
        initial: () => UiFlowStatus.idle,
        loading: () => UiFlowStatus.loading,
        loaded: (_) => UiFlowStatus.success,
        error: (_) => UiFlowStatus.failure,
      );

  @override
  Object? get error => maybeWhen(
        error: (msg) => msg,
        orElse: () => null,
      );

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

- [ ] **Step 4: Create the cubit**

Create `client/packages/pocketcoder_flutter/lib/application/tool_permissions/tool_permissions_cubit.dart`:

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/tool_permissions/i_tool_permission_repository.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'tool_permissions_state.dart';

@injectable
class ToolPermissionsCubit extends Cubit<ToolPermissionsState> {
  final IToolPermissionRepository _repository;
  StreamSubscription? _subscription;

  ToolPermissionsCubit(this._repository)
      : super(const ToolPermissionsState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchRules() {
    emit(const ToolPermissionsState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchRules().listen(
      (rules) {
        emit(ToolPermissionsState.loaded(rules));
      },
      onError: (e) {
        logError('ToolPermissions: Failed to watch rules', e);
        emit(ToolPermissionsState.error(e.toString()));
      },
    );
  }

  Future<void> updateAction(String id, String action) async {
    try {
      await _repository.updateAction(id, action);
    } catch (e) {
      logError('ToolPermissions: Failed to update action', e);
      emit(ToolPermissionsState.error(e.toString()));
    }
  }

  Future<void> setActive(String id, bool active) async {
    try {
      await _repository.setActive(id, active);
    } catch (e) {
      logError('ToolPermissions: Failed to set active', e);
      emit(ToolPermissionsState.error(e.toString()));
    }
  }

  Future<void> createRule({required String tool, required String action}) async {
    try {
      await _repository.createRule(tool: tool, action: action);
    } catch (e) {
      logError('ToolPermissions: Failed to create rule', e);
      emit(ToolPermissionsState.error(e.toString()));
    }
  }
}
```

- [ ] **Step 5: Regenerate Freezed + DI code**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: build succeeds; `lib/application/tool_permissions/tool_permissions_state.freezed.dart` is generated; `lib/app/bootstrap.config.dart` now contains a `gh.factory<ToolPermissionsCubit>(...)` entry.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/tool_permissions/tool_permissions_cubit_test.dart`
Expected: `PASS`, all 6 tests green.

- [ ] **Step 7: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/application/tool_permissions/ \
        client/packages/pocketcoder_flutter/test/application/tool_permissions/ \
        client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart
git commit -m "feat(tool-permissions): add ToolPermissionsState/ToolPermissionsCubit"
```

---

### Task 4: Localization keys

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: nothing.
- Produces: `context.l10n.toolPermissionsScreenTitle`, `context.l10n.toolPermissionsRulesRegistry`, `context.l10n.toolPermissionsNoRules`, `context.l10n.toolPermissionsAddRuleTitle`, `context.l10n.toolPermissionsToolNameLabel`, `context.l10n.toolPermissionsAllowLabel`, `context.l10n.toolPermissionsAskLabel`, `context.l10n.toolPermissionsDenyLabel` — Task 5's screen uses these exact getter names. (`context.l10n.actionAdd` and `context.l10n.actionCancel` already exist, reused as-is.)

- [ ] **Step 1: Add the new ARB keys**

`lib/l10n/app_en.arb` already has a `"toolPermissionsTitle": "GATEKEEPER CONFIGURATION"` key (line 275) and several other `toolPermissions*` keys, dead scaffolding left over from the earlier abandoned attempt at this screen (referenced only by generated `l10n_key_resolver.g.dart` codegen, not by any application code — confirmed by grep). Reusing or deleting that block is out of scope here; instead, every new key below is deliberately named to avoid colliding with it — note the screen's title key is `toolPermissionsScreenTitle`, not `toolPermissionsTitle`.

Open `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`. After the existing `"actionAdd": "ADD",` line (line 179, immediately before the blank line preceding `"settingsTitle"`), insert:

```json
  "toolPermissionsScreenTitle": "TOOL PERMISSIONS",
  "toolPermissionsRulesRegistry": "PERMISSION RULES",
  "toolPermissionsNoRules": "NO RULES CONFIGURED",
  "toolPermissionsAddRuleTitle": "ADD PERMISSION RULE",
  "toolPermissionsToolNameLabel": "TOOL NAME",
  "toolPermissionsAllowLabel": "ALLOW",
  "toolPermissionsAskLabel": "ASK",
  "toolPermissionsDenyLabel": "DENY",
```

Verify the file is still valid JSON (the ARB format is a flat JSON object) — no trailing comma after the last inserted key, and the following `"settingsTitle"` line remains intact.

- [ ] **Step 2: Regenerate localization files**

Run: `cd client/packages/pocketcoder_flutter && flutter gen-l10n`
Expected: no errors; `lib/l10n/app_localizations.dart` and `lib/l10n/app_localizations_en.dart` now declare the 8 new getters (grep for `toolPermissionsScreenTitle` in `app_localizations_en.dart` to confirm).

- [ ] **Step 3: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/l10n/
git commit -m "feat(tool-permissions): add localization keys for the new screen"
```

---

### Task 5: `ToolPermissionsScreen`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/tool_permissions/tool_permissions_screen.dart`

**Interfaces:**
- Consumes: `ToolPermissionsCubit`/`ToolPermissionsState` (Task 3's exact method/variant names), `ToolPermission`/`ToolPermissionAction` (`lib/domain/models/tool_permission.dart` — `action` is `ToolPermissionAction.allow/.ask/.deny/.unknown`), the l10n keys from Task 4, `getIt` (`lib/app/bootstrap.dart`), `PocketCoderShell`/`NavPillar`/`BiosFrame`/`BiosSection`/`UiFlowListener`/`TerminalButton`/`TerminalCard`/`TerminalDialog`/`TerminalTextField`/`TerminalText` (all `lib/presentation/core/widgets/*`, already used by `mcp_management_screen.dart` — same imports).
- Produces: `ToolPermissionsScreen` (StatelessWidget, no constructor params besides `key`) — Task 6 registers a `GoRoute` pointing `child: const ToolPermissionsScreen()`.

No widget test — matches the existing convention: `McpManagementScreen` has no widget test either (only its cubit/repository are unit-tested). Verification for this task is manual (Step 3).

- [ ] **Step 1: Create the screen**

Create `client/packages/pocketcoder_flutter/lib/presentation/tool_permissions/tool_permissions_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_card.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text_field.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_cubit.dart';
import 'package:pocketcoder_flutter/application/tool_permissions/tool_permissions_state.dart';
import 'package:pocketcoder_flutter/domain/models/tool_permission.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';

class ToolPermissionsScreen extends StatelessWidget {
  const ToolPermissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ToolPermissionsCubit>()..watchRules(),
      child: UiFlowListener<ToolPermissionsCubit, ToolPermissionsState>(
        child: const _ToolPermissionsView(),
      ),
    );
  }
}

class _ToolPermissionsView extends StatelessWidget {
  const _ToolPermissionsView();

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.toolPermissionsScreenTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.toolPermissionsRulesRegistry,
        child: BlocBuilder<ToolPermissionsCubit, ToolPermissionsState>(
          builder: (context, state) {
            final colors = context.colorScheme;
            return state.maybeWhen(
              loaded: (rules) {
                return ListView(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(AppSizes.space),
                      child: TerminalButton(
                        label: 'ADD RULE',
                        onTap: () => _showAddRuleDialog(context),
                      ),
                    ),
                    if (rules.isNotEmpty)
                      BiosSection(
                        title: context.l10n.toolPermissionsRulesRegistry,
                        child: Column(
                          children:
                              rules.map((r) => _buildRuleItem(context, r)).toList(),
                        ),
                      ),
                    if (rules.isEmpty)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSizes.space * 4),
                          child: TerminalText(
                            context.l10n.toolPermissionsNoRules,
                            alpha: 0.5,
                          ),
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (msg) => Center(
                child: Text(
                  'ERROR: $msg',
                  style: TextStyle(color: colors.error),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRuleItem(BuildContext context, ToolPermission rule) {
    final isActive = rule.active == true;

    return TerminalCard(
      isActive: isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TerminalText(
                  rule.tool.toUpperCase(),
                  weight: TerminalTextWeight.heavy,
                ),
              ),
              Switch(
                value: isActive,
                onChanged: (value) => context
                    .read<ToolPermissionsCubit>()
                    .setActive(rule.id, value),
              ),
            ],
          ),
          VSpace.x1,
          _buildActionSelector(context, rule),
        ],
      ),
    );
  }

  Widget _buildActionSelector(BuildContext context, ToolPermission rule) {
    Widget actionButton(String label, ToolPermissionAction action, String value) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.space / 2),
          child: TerminalButton(
            label: label,
            isPrimary: rule.action == action,
            onTap: () => context
                .read<ToolPermissionsCubit>()
                .updateAction(rule.id, value),
          ),
        ),
      );
    }

    return Row(
      children: [
        actionButton(context.l10n.toolPermissionsAllowLabel,
            ToolPermissionAction.allow, 'allow'),
        actionButton(context.l10n.toolPermissionsAskLabel,
            ToolPermissionAction.ask, 'ask'),
        actionButton(context.l10n.toolPermissionsDenyLabel,
            ToolPermissionAction.deny, 'deny'),
      ],
    );
  }

  void _showAddRuleDialog(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cubit = context.read<ToolPermissionsCubit>();
    final toolController = TextEditingController();
    String selectedAction = 'allow';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setState) => TerminalDialog(
          title: context.l10n.toolPermissionsAddRuleTitle,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TerminalTextField(
                controller: toolController,
                label: context.l10n.toolPermissionsToolNameLabel,
                obscureText: false,
              ),
              VSpace.x2,
              Row(
                children: [
                  ('allow', context.l10n.toolPermissionsAllowLabel),
                  ('ask', context.l10n.toolPermissionsAskLabel),
                  ('deny', context.l10n.toolPermissionsDenyLabel),
                ].map((entry) {
                  final (value, label) = entry;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.space / 2),
                      child: TerminalButton(
                        label: label,
                        isPrimary: selectedAction == value,
                        onTap: () => setState(() => selectedAction = value),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.onSurface,
                side:
                    BorderSide(color: colors.onSurface.withValues(alpha: 0.3)),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              child: Text(context.l10n.actionCancel),
            ),
            HSpace.x2,
            OutlinedButton(
              onPressed: () {
                final tool = toolController.text.trim();
                if (tool.isEmpty) return;
                cubit.createRule(tool: tool, action: selectedAction);
                Navigator.of(dialogContext).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.primary,
                side: BorderSide(color: colors.primary),
                shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero),
              ),
              child: Text(context.l10n.actionAdd),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Confirm it compiles**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/presentation/tool_permissions/tool_permissions_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/presentation/tool_permissions/
git commit -m "feat(tool-permissions): add ToolPermissionsScreen"
```

---

### Task 6: Register the route and manually verify end to end

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/app_router.dart:127-135` (insert new `GoRoute` after the `configureMcp` route)

**Interfaces:**
- Consumes: `ToolPermissionsScreen` (Task 5); `AppRoutes.configureToolPermissions` and `RouteNames.configureToolPermissions` (both already exist, `app_router.dart:217,257` — no changes needed to either constant).
- Produces: nothing new for later tasks — this is the final task.

- [ ] **Step 1: Add the import**

In `client/packages/pocketcoder_flutter/lib/app_router.dart`, add near the existing `import 'package:pocketcoder_flutter/presentation/mcp/mcp_management_screen.dart';` (line 9):

```dart
import 'package:pocketcoder_flutter/presentation/tool_permissions/tool_permissions_screen.dart';
```

- [ ] **Step 2: Register the route**

Insert this `GoRoute`, placed immediately after the existing `configureMcp` route block (`app_router.dart:127-135`, so it sits between `configureMcp` and `configureSop`) — `GoRoute` list order has no effect on routing, this placement is just for readability, keeping `configure*` routes grouped together:

```dart
      GoRoute(
        path: AppRoutes.configureToolPermissions,
        name: RouteNames.configureToolPermissions,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const ToolPermissionsScreen(),
        ),
      ),
```

- [ ] **Step 3: Confirm the app still builds**

Run: `cd client/packages/pocketcoder_flutter && flutter analyze lib/app_router.dart`
Expected: `No issues found!`

- [ ] **Step 4: Run the full Flutter test suite**

Run: `cd client/packages/pocketcoder_flutter && flutter test`
Expected: all tests pass, including the new `test/infrastructure/tool_permissions/` and `test/application/tool_permissions/` suites from Tasks 2–3.

- [ ] **Step 5: Manual verification**

Launch the app against a running PocketBase instance (`flutter run` with the dev server configured, per existing onboarding), sign in as the admin user, go to Settings → TOOL PERMISSIONS. Confirm:
- The screen loads (the button is no longer dead).
- Existing seeded rows (`*`/`allow`/`ask`/etc. from `1740000101_consolidated_seed.go`) appear, since they all have `poco_config` unset.
- Tapping ALLOW/ASK/DENY on a row updates its action (refresh reflects the PocketBase write).
- Toggling the Switch off dims the row (via `TerminalCard.isActive`) but keeps it in the list; toggling back on undims it.
- "ADD RULE" creates a new row with the entered tool name and selected action, and it appears in the list.

- [ ] **Step 6: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add client/packages/pocketcoder_flutter/lib/app_router.dart
git commit -m "feat(tool-permissions): register the ToolPermissionsScreen route

Fixes the Settings screen's 'TOOL PERMISSIONS' button, which has pointed
at an unregistered route since the earlier abandoned attempt at this
screen."
```
