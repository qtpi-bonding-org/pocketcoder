# Logout + Dead Collection Teardown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the long-dormant `AuthCubit.logout()`/`IAuthRepository.logout()` to a real Settings UI action, and fully remove five PocketBase collections (`proposals`, `sops`, `questions`, `harness_auth`, `sandbox_configs`) confirmed by a multi-agent audit to have zero consumers anywhere in the live system (not Flutter, not Goose, not MCP, not cognee, not PocketBase's own backend beyond the now-pointless `sops.go` sealing hook).

**Architecture:** Logout follows the existing `AuthCubit`/`tryOperation`/`UiFlowListener` pattern already used for login. Teardown removes the five collections from `schema.json`, deletes the one backend hook that touches them (`sops.go`), regenerates Flutter models via the existing Model Generation Pipeline, then hand-deletes the app-layer code (screen/cubit/repository) that was built for SOPs but never wired to real data, plus the now-orphaned generated model files (the pipeline's generator does NOT delete files for removed collections — confirmed by reading `scripts/generate_models.py`: `generate_model()` only writes files for collections present in the current schema and has no deletion logic, so stale model files must be hand-removed).

**Tech Stack:** Flutter/Dart (freezed, injectable/GetIt, flutter_bloc, cubit_ui_flow, mocktail), Go (PocketBase), Model Generation Pipeline (Docker + Python + build_runner).

## Global Constraints

- Never use `!` operator in Dart (client/CLAUDE.md).
- Cubits extend `AppCubit<T>`; state extends `IUiFlowState` with `@freezed`; use `tryOperation`; must set `status: UiFlowStatus.success` explicitly (client/CLAUDE.md).
- Repository methods wrapped in `tryMethod`; typed exceptions per domain (client/CLAUDE.md).
- Dot-notation ARB source keys map to camelCase generated keys, e.g. `settings.account_section` → `settingsAccountSection` (client/CLAUDE.md).
- `MessageKey` reserved for cubit/service-originated strings; inline widget text uses `context.l10n.xxx` (client/CLAUDE.md).
- After PB schema changes, run the exact 5-step Model Generation Pipeline from root `CLAUDE.md`: `docker compose build pocketbase goose` → `docker compose up -d pocketbase goose` → `scripts/export_schema.sh` → `python3 scripts/generate_models.py` (from `client/packages/pocketcoder_flutter`) → `dart run build_runner build --delete-conflicting-outputs`.
- PocketBase always owns its own primary key; schema changes go through `schema.json` (root `CLAUDE.md`).

---

## Task 1: `AuthCubit.logout()`

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/application/system/auth_cubit.dart`
- Test: `client/packages/pocketcoder_flutter/test/application/system/auth_cubit_test.dart` (new file — none exists yet for this cubit)

**Interfaces:**
- Consumes: `IAuthRepository.logout()` — `Future<void> logout()`, already implemented at `lib/infrastructure/auth/auth_repository.dart:51-54` (clears `PocketBase.authStore` + secure storage, does not throw in normal operation).
- Produces: `AuthCubit.logout()` — `Future<void> logout()`. On success emits `AuthState(status: UiFlowStatus.success, error: null)`. Task 2 calls this method and listens for `state.isSuccess`.

- [ ] **Step 1: Write the failing test**

Create `client/packages/pocketcoder_flutter/test/application/system/auth_cubit_test.dart`:

```dart
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  late MockAuthRepository repo;
  AuthCubit? lastCubit;

  AuthCubit buildCubit() {
    final cubit = AuthCubit(repo);
    lastCubit = cubit;
    return cubit;
  }

  setUp(() {
    repo = MockAuthRepository();
  });

  tearDown(() async {
    if (lastCubit != null) {
      await lastCubit!.close();
      lastCubit = null;
    }
  });

  group('AuthCubit.logout', () {
    test('calls repository.logout() and emits success', () async {
      when(() => repo.logout()).thenAnswer((_) async {});
      final cubit = buildCubit();

      await cubit.logout();

      verify(() => repo.logout()).called(1);
      expect(cubit.state.status, UiFlowStatus.success);
      expect(cubit.state.error, isNull);
    });

    test('emits failure when repository.logout() throws', () async {
      when(() => repo.logout()).thenThrow(Exception('storage write failed'));
      final cubit = buildCubit();

      await cubit.logout();

      expect(cubit.state.status, UiFlowStatus.failure);
      expect(cubit.state.error, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/system/auth_cubit_test.dart`
Expected: FAIL — `The method 'logout' isn't defined for the type 'AuthCubit'`

- [ ] **Step 3: Write minimal implementation**

Edit `client/packages/pocketcoder_flutter/lib/application/system/auth_cubit.dart`, adding `logout()` after the existing `login()` method:

```dart
  Future<void> logout() async {
    return tryOperation(() async {
      await _authRepository.logout();
      return createSuccessState();
    });
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/application/system/auth_cubit_test.dart`
Expected: PASS — 2 tests passed

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/application/system/auth_cubit.dart client/packages/pocketcoder_flutter/test/application/system/auth_cubit_test.dart
git commit -m "feat: add AuthCubit.logout()"
```

---

## Task 2: Wire logout into Settings screen

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb` (add 5 new keys)
- Test: `client/packages/pocketcoder_flutter/test/presentation/settings/settings_screen_test.dart` (new file)

**Interfaces:**
- Consumes: `AuthCubit.logout()` (Task 1), `AuthState` (existing, `lib/application/system/auth_cubit.dart` — `status: UiFlowStatus`, `error: Object?`), `RouteNames.onboarding` (existing constant, `lib/app_router.dart:277`), `TerminalDialog({title, content, actions})` (existing widget, `lib/presentation/core/widgets/terminal_dialog.dart`), `BiosListTile({label, value, onTap, isDestructive})` (existing widget, `lib/presentation/core/widgets/bios_list_tile.dart`).
- Produces: nothing consumed by later tasks — this is a leaf UI change.

- [ ] **Step 1: Add the 5 new ARB keys**

Edit `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`, adding after the existing `"settingsObservabilitySection"`-style keys (find the settings section keys near the top of the file and add alongside them):

```json
  "settingsAccountSection": "ACCOUNT",
  "settingsLogoutConfirmTitle": "SIGN OUT",
  "settingsLogoutConfirmBody": "This will end your current session. You will need to log in again to continue.",
  "settingsLogoutCancel": "CANCEL",
  "settingsLogoutConfirm": "SIGN OUT",
```

Run: `cd client/packages/pocketcoder_flutter && flutter gen-l10n`
Expected: no output on success (regenerates `lib/l10n/app_localizations.dart` and per-locale files silently); confirms via `git diff --stat` showing changes to generated l10n files.

- [ ] **Step 2: Write the failing widget test**

Create `client/packages/pocketcoder_flutter/test/presentation/settings/settings_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/auth/i_auth_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/settings/settings_screen.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class MockMcpCubit extends Mock implements McpCubit {}

void main() {
  late MockAuthRepository authRepo;
  late MockMcpCubit mcpCubit;

  setUp(() {
    authRepo = MockAuthRepository();
    mcpCubit = MockMcpCubit();
    when(() => mcpCubit.state).thenReturn(const McpState.loaded(servers: []));
    when(() => mcpCubit.stream)
        .thenAnswer((_) => const Stream<McpState>.empty());

    getIt.registerFactory<AuthCubit>(() => AuthCubit(authRepo));
  });

  tearDown(() {
    getIt.reset();
  });

  Widget buildTestable() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<McpCubit>.value(
        value: mcpCubit,
        child: const SettingsScreen(),
      ),
    );
  }

  testWidgets('tapping LOGOUT opens a confirm dialog; confirming calls logout',
      (tester) async {
    when(() => authRepo.logout()).thenAnswer((_) async {});

    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOGOUT'));
    await tester.pumpAndSettle();

    expect(find.text('SIGN OUT'), findsWidgets);

    await tester.tap(find.text('SIGN OUT').last);
    await tester.pumpAndSettle();

    verify(() => authRepo.logout()).called(1);
  });

  testWidgets('tapping CANCEL does not call logout', (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOGOUT'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    verifyNever(() => authRepo.logout());
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/settings/settings_screen_test.dart`
Expected: FAIL — `find.text('LOGOUT')` finds nothing (no ACCOUNT section exists yet)

- [ ] **Step 4: Write minimal implementation**

Replace the full contents of `client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_cubit.dart';
import 'package:pocketcoder_flutter/application/mcp/mcp_state.dart';
import 'package:pocketcoder_flutter/application/system/auth_cubit.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_list_tile.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_section.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_dialog.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/ui_flow_listener.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import '../../app_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static List<(String, List<(String, String, String)>)> _sections(
      BuildContext context) {
    return [
      (context.l10n.settingsAiAgentsSection, [
        ('LLM MANAGEMENT', '[KEYS]', 'configureLlm'),
        ('AGENT REGISTRY', '[MODELS]', 'configureAi'),
      ]),
      (context.l10n.settingsSecuritySection, [
        ('TOOL PERMISSIONS', '[SETUP]', 'configureToolPermissions'),
        ('MCP MANAGEMENT', '[CONFIGURE]', 'configureMcp'),
        ('SKILLS', '[MANAGE]', 'configureSkills'),
      ]),
      (context.l10n.settingsSystemSection, [
        ('SYSTEM CHECKS', '[DIAGNOSE]', 'configureSystemChecks'),
        ('PERMISSION RELAY', '[STATUS]', 'configurePaywall'),
      ]),
      (context.l10n.settingsObservabilitySection, [
        ('AGENT OBSERVABILITY', '[MANAGE]', 'configureObservability'),
      ]),
      (context.l10n.settingsAutomationSection, [
        ('SCHEDULER', '[MANAGE]', 'configureScheduler'),
      ]),
      (context.l10n.settingsAccountSection, [
        ('LOGOUT', '[SIGN OUT]', 'logout'),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthCubit>(),
      child: UiFlowListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.isSuccess && context.mounted) {
            context.goNamed(RouteNames.onboarding);
          }
        },
        child: PocketCoderShell(
          title: context.l10n.settingsTitle,
          activePillar: NavPillar.configure,
          showBack: false,
          body: BlocBuilder<McpCubit, McpState>(
            builder: (context, state) {
              final hasPendingMcp = state.maybeWhen(
                loaded: (servers) =>
                    servers.any((s) => s.status == McpServerStatus.pending),
                orElse: () => false,
              );

              return ListView(
                children: [
                  for (final section in _sections(context)) ...[
                    BiosSection(
                      title: section.$1,
                      child: Column(
                        children: [
                          for (final item in section.$2)
                            Builder(builder: (context) {
                              final isMcp = item.$3 == 'configureMcp';
                              final isLogout = item.$3 == 'logout';
                              return BiosListTile(
                                label: item.$1,
                                value: item.$2,
                                hasBadge: isMcp && hasPendingMcp,
                                isDestructive: isLogout,
                                onTap: () {
                                  if (isLogout) {
                                    _confirmLogout(context);
                                  } else {
                                    _navigateTo(context, item.$3);
                                  }
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    final cubit = context.read<AuthCubit>();
    showDialog(
      context: context,
      builder: (dialogContext) => TerminalDialog(
        title: context.l10n.settingsLogoutConfirmTitle,
        content: Text(context.l10n.settingsLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.settingsLogoutCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.logout();
            },
            child: Text(context.l10n.settingsLogoutConfirm),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeKey) {
    switch (routeKey) {
      case 'configureAi':
        context.push(AppRoutes.configureAi);
      case 'configureToolPermissions':
        context.push(AppRoutes.configureToolPermissions);
      case 'configureMcp':
        context.push(AppRoutes.configureMcp);
      case 'configureSkills':
        context.push(AppRoutes.configureSkills);
      case 'configureSystemChecks':
        context.push(AppRoutes.configureSystemChecks);
      case 'configurePaywall':
        context.push(AppRoutes.configurePaywall);
      case 'configureObservability':
        context.push(AppRoutes.configureObservability);
      case 'configureLlm':
        context.push(AppRoutes.configureLlm);
      case 'configureScheduler':
        context.push(AppRoutes.configureScheduler);
    }
  }
}
```

Note: the `configureSop` case and the `('SOP MANAGEMENT', ...)` tile are already omitted above — Task 4 removes the remaining SOP references (route definition, import) elsewhere; this task's rewrite already drops the settings-screen half so Task 4 doesn't need to touch this file again.

- [ ] **Step 5: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/settings/settings_screen_test.dart`
Expected: PASS — 2 tests passed

- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart client/packages/pocketcoder_flutter/lib/l10n/app_en.arb client/packages/pocketcoder_flutter/lib/l10n/app_localizations*.dart client/packages/pocketcoder_flutter/test/presentation/settings/settings_screen_test.dart
git commit -m "feat: wire logout into settings screen"
```

---

## Task 3: Backend teardown — remove dead collections from schema + delete `sops.go` hook

**Files:**
- Modify: `services/pocketbase/pb_migrations/schema.json` (remove 5 collection entries)
- Delete: `services/pocketbase/internal/hooks/sops.go`
- Modify: `services/pocketbase/main.go` (remove `RegisterSopHooks` call site)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: a regenerated `client/packages/pocketcoder_flutter/assets/pb_schema.json` and regenerated `collections.dart`/model files that Task 4 depends on (Task 4 hand-deletes the files this task's pipeline run leaves orphaned).

- [ ] **Step 1: Remove the 5 collection definitions from schema.json**

Edit `services/pocketbase/pb_migrations/schema.json`. Find and delete the 4 full JSON objects (each a top-level array element) whose `"name"` field is exactly `"proposals"`, `"sops"`, `"questions"`, `"harness_auth"`, `"sandbox_configs"` — that's 5 objects total. Each object spans from its opening `{` (starting with `"id": "pc_<name>"`) to its matching closing `}`, followed by a comma if not the last element in the array. Use this to locate and verify all 5 before editing:

```bash
python3 -c "
import json
d = json.load(open('services/pocketbase/pb_migrations/schema.json'))
targets = {'proposals','sops','questions','harness_auth','sandbox_configs'}
found = {c['name'] for c in d if c['name'] in targets}
print('Found:', sorted(found))
assert found == targets, f'Missing: {targets - found}'
"
```

Expected output: `Found: ['harness_auth', 'proposals', 'questions', 'sandbox_configs', 'sops']`

After manually deleting the 5 objects from the JSON array (preserve valid JSON — no trailing/missing commas), verify the file still parses and the 5 are gone:

```bash
python3 -c "
import json
d = json.load(open('services/pocketbase/pb_migrations/schema.json'))
targets = {'proposals','sops','questions','harness_auth','sandbox_configs'}
remaining = {c['name'] for c in d if c['name'] in targets}
assert remaining == set(), f'Still present: {remaining}'
print('OK: schema.json valid, all 5 removed. Total collections now:', len(d))
"
```

Expected output: `OK: schema.json valid, all 5 removed. Total collections now: 17` (was 22).

- [ ] **Step 2: Delete the sops.go hook and its call site**

```bash
rm services/pocketbase/internal/hooks/sops.go
```

Edit `services/pocketbase/main.go`, removing this line (currently at line 58, in the "2. Register Global Sovereign Hooks" section):

```go
	hooks.RegisterSopHooks(app)
```

leaving that section as:

```go
	// 2. Register Global Sovereign Hooks
	hooks.RegisterGlobalTimestamps(app)
	hooks.RegisterNotificationHooks(app)
```

- [ ] **Step 3: Verify Go builds and vets clean**

Run: `cd services/pocketbase && go build ./... && go vet ./...`
Expected: no output (clean build, no errors)

- [ ] **Step 4: Run the Model Generation Pipeline**

Run each step from the repo root, per root `CLAUDE.md`:

```bash
docker compose build pocketbase goose
docker compose up -d pocketbase goose
```
Expected: both containers rebuild and report `Started`/`Running` with no error exit codes (`docker compose ps` shows both as `Up`).

```bash
scripts/export_schema.sh
```
Expected: overwrites `client/packages/pocketcoder_flutter/assets/pb_schema.json` with the new (5-collections-fewer) schema. Verify:

```bash
python3 -c "
import json
d = json.load(open('client/packages/pocketcoder_flutter/assets/pb_schema.json'))
targets = {'proposals','sops','questions','harness_auth','sandbox_configs'}
remaining = {c['name'] for c in d['items'] if c['name'] in targets}
assert remaining == set(), f'Still present in exported schema: {remaining}'
print('OK: exported schema has none of the 5 dead collections')
"
```
Expected output: `OK: exported schema has none of the 5 dead collections`

```bash
cd client/packages/pocketcoder_flutter && python3 scripts/generate_models.py
```
Expected output: a list of `Generated lib/domain/models/<name>.dart` lines (one per remaining collection) plus `Generated lib/domain/models/collections.dart`. Confirm `collections.dart` no longer lists the 5 removed constants:

```bash
grep -E "proposals|sops|questions|harnessAuth|sandboxConfigs" lib/domain/models/collections.dart
```
Expected: no output (grep finds nothing — these are gone from the regenerated file).

Note: this step does **not** delete `question.dart`, `harness_auth.dart`, `sandbox_config.dart`, `proposal.dart`, `sop.dart` (and their `.freezed.dart`/`.g.dart`) — `generate_model()` in `scripts/generate_models.py` only writes files for collections present in the current schema; it has no logic to delete files for collections that were removed. Those 5 model file sets (15 files) are now orphaned on disk and are hand-deleted in Task 4, Step 1.

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: ends with `Succeeded after ...ms with ... outputs`. This regenerates `.freezed.dart`/`.g.dart` for every model still referenced by the codebase — but since the 5 orphaned `.dart` model files still exist on disk (not yet deleted) and still have valid syntax (they just import `Sop`, `Proposal`, etc. which still compile fine as isolated files with no other references), this step should complete without errors. If it errors on the orphaned files, that confirms Task 4 must run before this step in a future iteration — but expect success here since these are self-contained files.

- [ ] **Step 5: Commit**

```bash
git add services/pocketbase/pb_migrations/schema.json services/pocketbase/main.go client/packages/pocketcoder_flutter/assets/pb_schema.json client/packages/pocketcoder_flutter/lib/domain/models/collections.dart
git rm services/pocketbase/internal/hooks/sops.go
git commit -m "feat: remove dead PocketBase collections from schema (proposals, sops, questions, harness_auth, sandbox_configs)

Multi-agent audit confirmed zero consumers anywhere in the live system.
Deletes the sops.go sealing hook (its only reason to exist was these
two collections). Flutter-side model files for the 5 collections are
now orphaned; removed in the next commit."
```

---

## Task 4: Flutter teardown — delete SOP app layer + orphaned models + routes + tests

**Files:**
- Delete: `client/packages/pocketcoder_flutter/lib/presentation/sop/sop_management_screen.dart`
- Delete: `client/packages/pocketcoder_flutter/lib/application/sop/sop_cubit.dart`, `sop_state.dart`, `sop_state.freezed.dart`
- Delete: `client/packages/pocketcoder_flutter/lib/domain/evolution/i_evolution_repository.dart`
- Delete: `client/packages/pocketcoder_flutter/lib/infrastructure/evolution/evolution_repository.dart`, `evolution_daos.dart`
- Delete: `client/packages/pocketcoder_flutter/lib/domain/exceptions/sop_exception.dart`
- Delete (orphaned generated models, 15 files): `lib/domain/models/{question,harness_auth,sandbox_config,proposal,sop}.dart` and matching `.freezed.dart`/`.g.dart` for each
- Modify: `client/packages/pocketcoder_flutter/lib/app_router.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`

**Interfaces:**
- Consumes: nothing from earlier tasks (Task 3 already removed the schema-level source; this task removes app-layer code that referenced it).
- Produces: a fully clean `flutter analyze` — the terminal deliverable for this plan.

- [ ] **Step 1: Verify no test suite references the code being deleted**

```bash
cd client/packages/pocketcoder_flutter
grep -rl "Sop\|Proposal\|Evolution\|Question\|HarnessAuth\|SandboxConfig" test/ 2>/dev/null || echo "NONE FOUND"
```
Expected: `NONE FOUND` (confirmed during plan-writing — no existing test references any of `SopCubit`, `SopManagementScreen`, `EvolutionRepository`, `Question`, `HarnessAuth`, or `SandboxConfig`). If this instead prints file paths, stop and read each one — it means a test was added since this plan was written and needs to be deleted/updated as part of this step before continuing.

- [ ] **Step 2: Delete the SOP application/domain/infrastructure layer**

```bash
cd client/packages/pocketcoder_flutter
rm lib/presentation/sop/sop_management_screen.dart
rmdir lib/presentation/sop 2>/dev/null || true
rm lib/application/sop/sop_cubit.dart lib/application/sop/sop_state.dart lib/application/sop/sop_state.freezed.dart
rmdir lib/application/sop 2>/dev/null || true
rm lib/domain/evolution/i_evolution_repository.dart
rmdir lib/domain/evolution 2>/dev/null || true
rm lib/infrastructure/evolution/evolution_repository.dart lib/infrastructure/evolution/evolution_daos.dart
rmdir lib/infrastructure/evolution 2>/dev/null || true
rm lib/domain/exceptions/sop_exception.dart
```

- [ ] **Step 3: Delete the 5 orphaned generated model file sets**

```bash
cd client/packages/pocketcoder_flutter/lib/domain/models
rm question.dart question.freezed.dart question.g.dart
rm harness_auth.dart harness_auth.freezed.dart harness_auth.g.dart
rm sandbox_config.dart sandbox_config.freezed.dart sandbox_config.g.dart
rm proposal.dart proposal.freezed.dart proposal.g.dart
rm sop.dart sop.freezed.dart sop.g.dart
cd -
```

- [ ] **Step 4: Remove SOP references from the router**

Edit `client/packages/pocketcoder_flutter/lib/app_router.dart`:

Remove this import line:
```dart
import 'package:pocketcoder_flutter/presentation/sop/sop_management_screen.dart';
```

Remove this line from the `redirect` function:
```dart
      if (loc == '/sop') return AppRoutes.configureSop;
```

Remove this `GoRoute` block entirely (the one whose `path` is `AppRoutes.configureSop`):
```dart
      GoRoute(
        path: AppRoutes.configureSop,
        name: RouteNames.configureSop,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: const SopManagementScreen(),
        ),
      ),
```
(Read the file first to get this block's exact surrounding syntax/indentation before deleting — the `pageBuilder` body shape may differ slightly from other routes; match what's actually there.)

Remove these 4 route-constant lines:
```dart
  static const String configureSop = '/configure/sop';
```
```dart
  static const String sopManagement = '/sop';
```
```dart
  static const String configureSop = 'configureSop';
```
```dart
  static const String sopManagement = 'configureSop';
```

- [ ] **Step 5: Remove the sop ARB keys**

Edit `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`, removing these 6 keys (and their `@`-prefixed metadata entries if any exist for them — check for `"@sopTitle"` etc. alongside):

```json
  "sopTitle": "SOP MANAGEMENT",
  "sopProjectProcedures": "PROJECT PROCEDURES",
  "sopNewProposal": "NEW PROPOSAL",
  "sopActiveProcedures": "ACTIVE PROCEDURES",
  "sopDraftProposals": "DRAFT PROPOSALS",
  "sopPendingSignature": "PENDING SIGNATURE",
```

Run: `flutter gen-l10n`
Expected: no output on success.

- [ ] **Step 6: Regenerate and verify analyzer is clean**

```bash
cd client/packages/pocketcoder_flutter
dart run build_runner build --delete-conflicting-outputs
```
Expected: ends with `Succeeded after ...ms with ... outputs` and no errors about missing `Sop`/`Proposal`/`Question`/`HarnessAuth`/`SandboxConfig` symbols.

```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 7: Run the full test suite**

```bash
flutter test
```
Expected: all tests pass, 0 failures.

- [ ] **Step 8: Commit**

```bash
cd /Users/aicoder/Documents/pocketcoder
git add -A client/packages/pocketcoder_flutter
git status
```
Review the output to confirm only expected deletions/modifications are staged (no accidental unrelated changes), then:

```bash
git commit -m "feat: remove dead SOP app layer and orphaned collection models

Deletes SopManagementScreen/SopCubit/EvolutionRepository (never wired
to real data — hardcoded placeholder screen) plus the 5 generated
model file sets left orphaned by the schema teardown in the previous
commit (question, harness_auth, sandbox_config, proposal, sop)."
```

---

## Self-Review

**1. Spec coverage:**
- §3.1 (logout: `AuthCubit.logout()`, settings ACCOUNT section, confirm dialog, redirect on success, 5 ARB keys) → Tasks 1 + 2. ✓
- §3.2 (backend: schema.json, sops.go, main.go, Model Generation Pipeline) → Task 3. ✓
- §3.2 (Flutter: screen/cubit/repository/exception/router/settings/ARB deletion) → Task 4 (settings-screen half already folded into Task 2's full-file rewrite, noted explicitly in Task 2 Step 4). ✓
- §4 Data flow (logout clears authStore, no drift cache invalidation needed) → matches Task 1/2 implementation (no drift-specific code added, since `logout()` only touches `PocketBase.authStore` + secure storage per the existing `IAuthRepository.logout()` implementation). ✓
- §5 Error handling (no new exception-mapper case needed) → confirmed in Task 1 test (failure path sets `state.error` directly via `tryOperation`'s catch, no typed exception thrown). ✓
- §6 Testing (auth_cubit_test extension, settings_screen_test, teardown grep-before-delete) → Tasks 1, 2, 4 Step 1. ✓
- §7 Out of scope (healthchecks/ssh_keys/sandbox_agents/harnesses untouched) → no task touches these. ✓

**2. Placeholder scan:** No TBD/TODO/"add error handling"-style placeholders found. Task 4 Step 4's `GoRoute` removal step includes an explicit instruction to read the file first rather than assuming exact formatting, since that block's precise shape wasn't independently re-verified line-by-line at plan-writing time (unlike the constants and import lines, which were).

**3. Type consistency check:** `AuthCubit.logout()` (Task 1) → called as `context.read<AuthCubit>().logout()` in Task 2, matching signature `Future<void> logout()`. `AuthState.isSuccess`/`.status`/`.error` (existing, unchanged) used consistently in Task 1's test and Task 2's listener. `RouteNames.onboarding` (existing constant) used consistently. No mismatches found.

**4. Ordering resolution (the one open question flagged in the spec):** Confirmed by reading `scripts/generate_models.py` in full — `generate_model()`/`generate_collections()` only ever *write* files for collections present in the schema passed in; there is no deletion logic anywhere in the script. So Task 3 (schema edit + pipeline run) does NOT auto-remove the 5 orphaned model files — Task 4 does that by hand, after Task 3. This ordering (schema/backend first, hand-deletion of app-layer + orphaned models second) is now definitive, not a plan-time guess.
