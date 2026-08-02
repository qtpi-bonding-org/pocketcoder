# Error Catcher Inbox Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish wiring the already-half-installed `flutter_error_privserver` package so every exception that reaches an `AppCubit`'s `tryOperation` (plus one identified bootstrap swallow site) is captured on-device, and add a Settings → Error Reports screen where the user can view and delete captured entries. No network transmission of any kind.

**Architecture:** `ErrorPrivserver.configure(...)` is called once at bootstrap with a `SharedPrefsErrorBoxStorage` singleton, a new PocketCoder-specific error-code mapper, the app's existing `IExceptionKeyMapper`, and two required-but-unused UI builder implementations (`toastBuilder` is dead in this package version; `pageBuilder` is the real integration point). The inbox screen is built on top of the package's own `ErrorBoxPageCubit`, not a new custom cubit.

**Tech Stack:** Flutter, `flutter_bloc`/`cubit_ui_flow` (Cubits), `injectable`/`get_it` (DI), `flutter_error_privserver` (git-pinned package, commit `3565d9d47f24bee06bc88314b51a7df04ee3f78e`), `go_router`, `shared_preferences` (via the package), `mocktail` + `flutter_test` for tests.

## Global Constraints

- Never use the `!` operator — use `?.`/`??`/`requireNonNull` (`client/CLAUDE.md`).
- Every public repo/service method wrapped in `tryMethod`; every cubit failure path uses `tryOperation` (`client/CLAUDE.md`). `ErrorBoxPageCubit` is an exception — it's the package's own cubit, not app code, and doesn't follow this app's conventions internally.
- No hardcoded user-facing strings — use `MessageKey`/`context.l10n.*`, dot-notation ARB keys map to camelCase getters (`client/CLAUDE.md`, confirmed via `lib/l10n/app_en.arb:29` `"permissionError"` ↔ dot-key `permission.error`).
- After any codegen-affecting change (new `@injectable`/`@module` provider, new l10n key), run `dart run build_runner build --delete-conflicting-outputs` from `client/packages/pocketcoder_flutter` (`client/CLAUDE.md`).
- No PII in captured errors — every exception that reaches a cubit's `tryOperation` via `tryMethod` is already type-only by construction (spec §2); do not add message-string capture anywhere in this work.
- No `reporter`/send/network path is wired to any UI control — `reporter` stays a no-op stub (spec §3).
- Spec: `docs/superpowers/specs/2026-08-02-error-catcher-inbox-design.md`.

---

## Task 1: `PocketCoderErrorCodeMapper`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/errors/error_code_mapper.dart`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/errors/error_code_mapper_test.dart`

**Interfaces:**
- Produces: `class PocketCoderErrorCodeMapper { static String mapError(Object error); }` — a pure static function, no DI registration needed (matches how `ErrorCodeMapper.mapError` from the package itself is referenced directly as a function value, not injected).

- [x] **Step 1: Write the failing test**

```dart
// test/infrastructure/errors/error_code_mapper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/error_code_mapper.dart';

void main() {
  group('PocketCoderErrorCodeMapper.mapError', () {
    test('maps known domain exceptions to stable codes', () {
      expect(PocketCoderErrorCodeMapper.mapError(AuthException('x')), 'AUTH_001');
      expect(PocketCoderErrorCodeMapper.mapError(ChatException('x')), 'CHAT_001');
      expect(PocketCoderErrorCodeMapper.mapError(ChatListException('x')), 'CHATLIST_001');
      expect(PocketCoderErrorCodeMapper.mapError(PermissionException('x')), 'PERM_001');
      expect(PocketCoderErrorCodeMapper.mapError(AiException('x')), 'AI_001');
      expect(PocketCoderErrorCodeMapper.mapError(ToolPermissionsException('x')), 'TOOLPERM_001');
      expect(PocketCoderErrorCodeMapper.mapError(RepositoryException('x')), 'REPO_001');
      expect(PocketCoderErrorCodeMapper.mapError(McpException('x')), 'MCP_001');
      expect(PocketCoderErrorCodeMapper.mapError(McpOAuthException('x')), 'MCP_002');
      expect(PocketCoderErrorCodeMapper.mapError(ObservabilityException('x')), 'OBS_001');
      expect(PocketCoderErrorCodeMapper.mapError(SkillsException('x')), 'SKILLS_001');
      expect(PocketCoderErrorCodeMapper.mapError(SchedulerException('x')), 'SCHED_001');
      expect(PocketCoderErrorCodeMapper.mapError(FilesException('x')), 'FILES_001');
    });

    test('falls back to ERR_<Type> for unmapped exception types', () {
      expect(PocketCoderErrorCodeMapper.mapError(FormatException('x')), 'ERR_FormatException');
      expect(PocketCoderErrorCodeMapper.mapError(StateError('x')), 'ERR_StateError');
    });
  });
}
```

Check `ChatListException`'s constructor signature first — `lib/domain/exceptions/chat_list_exception.dart:1` declares `class ChatListException implements Exception` (not a `DomainException` subclass like the others). Confirm its constructor takes a single positional `String` before using `ChatListException('x')` verbatim; adjust the test call if it differs (e.g. a named `message:` parameter).

- [x] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/errors/error_code_mapper_test.dart`
Expected: FAIL — `error_code_mapper.dart` doesn't exist yet (import error).

- [x] **Step 3: Write minimal implementation**

```dart
// lib/infrastructure/errors/error_code_mapper.dart
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/exceptions/chat_list_exception.dart';

/// Maps PocketCoder's typed domain exceptions to short, stable codes for
/// the local error inbox. No string-matching on `error.toString()` — every
/// exception that reaches this point is already type-only by construction
/// (see `tryMethod`'s `SafeExceptionCause` wrapping), so message-content
/// heuristics would be dead code, not a safety net.
class PocketCoderErrorCodeMapper {
  PocketCoderErrorCodeMapper._();

  static final Map<Type, String> _codes = {
    AuthException: 'AUTH_001',
    ChatException: 'CHAT_001',
    ChatListException: 'CHATLIST_001',
    PermissionException: 'PERM_001',
    AiException: 'AI_001',
    ToolPermissionsException: 'TOOLPERM_001',
    RepositoryException: 'REPO_001',
    McpException: 'MCP_001',
    McpOAuthException: 'MCP_002',
    ObservabilityException: 'OBS_001',
    SkillsException: 'SKILLS_001',
    SchedulerException: 'SCHED_001',
    FilesException: 'FILES_001',
  };

  static String mapError(Object error) {
    return _codes[error.runtimeType] ?? 'ERR_${error.runtimeType}';
  }
}
```

- [x] **Step 4: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/errors/error_code_mapper_test.dart`
Expected: PASS

- [x] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/infrastructure/errors/error_code_mapper.dart client/packages/pocketcoder_flutter/test/infrastructure/errors/error_code_mapper_test.dart
git commit -m "feat(client): add PocketCoderErrorCodeMapper for error inbox"
```

---

## Task 2: Register `ErrorBoxStorage` in DI

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart`

**Interfaces:**
- Consumes: `SharedPrefsErrorBoxStorage` and `ErrorBoxStorage` from `package:flutter_error_privserver/flutter_error_privserver.dart`.
- Produces: `getIt<ErrorBoxStorage>()` resolves to a singleton `SharedPrefsErrorBoxStorage` instance, usable from Task 3 (bootstrap config + bootstrap-level capture) and Task 4 (inbox screen reads via `ErrorBoxPageCubit`, which reads storage through `ErrorPrivserverMixin.config`, not DI — so this registration exists purely for Task 3's two use sites).

- [x] **Step 1: Add the provider**

Add this import and method to `ExternalModule` in `lib/infrastructure/core/external_module.dart` (append to the existing `@module abstract class ExternalModule { ... }` body, alongside `httpClient`/`mcpOAuthRelayBaseUrl`):

```dart
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
```

```dart
  /// Local-only storage for the on-device error inbox. Never synced or
  /// transmitted — see docs/superpowers/specs/2026-08-02-error-catcher-inbox-design.md.
  @lazySingleton
  ErrorBoxStorage get errorBoxStorage => SharedPrefsErrorBoxStorage();
```

- [x] **Step 2: Regenerate DI registrations**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs`
Expected: build succeeds; `lib/app/bootstrap.config.dart` now contains a registration for `ErrorBoxStorage`. Grep to confirm: `grep -n "ErrorBoxStorage" lib/app/bootstrap.config.dart` should show a hit.

- [x] **Step 3: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart
git commit -m "feat(client): register ErrorBoxStorage singleton for error inbox"
```

---

## Task 3: Wire `ErrorPrivserver.configure` and bootstrap-level capture

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/app/bootstrap.dart`
- Test: `client/packages/pocketcoder_flutter/test/app/bootstrap_error_capture_test.dart`

**Interfaces:**
- Consumes: `PocketCoderErrorCodeMapper.mapError` (Task 1), `getIt<ErrorBoxStorage>()` (Task 2), `getIt<IExceptionKeyMapper>()` (existing, `AppExceptionKeyMapper`), `PocketCoderErrorBoxPageBuilder` (Task 4 — forward reference; this task's `configure()` call passes it as `pageBuilder`, so Task 3 must land after Task 4, or use a placeholder class temporarily — **this plan runs Task 4 before Task 3's `configure()` step to avoid a forward reference; see ordering note below**).
- Produces: `ErrorPrivserver` is configured and capturing after `bootstrap()` runs. A private `_NoopErrorToastBuilder` class in `bootstrap.dart`.

**Ordering note:** This task depends on `PocketCoderErrorBoxPageBuilder` existing (Task 4). Implement Task 4 first, then return to this task. The task numbering here reflects the spec's component order, not execution order — a subagent-driven executor should run Task 4 before Task 3's Step 3 below (Steps 1-2, the bootstrap-capture half, have no such dependency and can run in either order).

- [x] **Step 1: Write the failing test for bootstrap-level capture**

```dart
// test/app/bootstrap_error_capture_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/error_code_mapper.dart';

class MockErrorBoxStorage extends Mock implements ErrorBoxStorage {}

void main() {
  test('billing-identify failure is captured with the right source and code', () async {
    final storage = MockErrorBoxStorage();
    when(() => storage.saveError(any())).thenAnswer((_) async {});

    // Exercises the exact capture call this task adds at the
    // billing-identify catch site in bootstrap.dart, without needing to
    // run the whole bootstrap() function.
    final error = Exception('identify failed');
    final stack = StackTrace.current;
    await storage.saveError(ErrorEntry(
      source: 'Bootstrap.billingIdentify',
      errorType: error.runtimeType.toString(),
      errorCode: PocketCoderErrorCodeMapper.mapError(error),
      stackTrace: stack.toString(),
      timestamp: DateTime.now(),
    ));

    final captured = verify(() => storage.saveError(captureAny())).captured;
    final entry = captured.single as ErrorEntry;
    expect(entry.source, 'Bootstrap.billingIdentify');
    expect(entry.errorCode, 'ERR_Exception'); // Exception has no dedicated mapping
  });
}
```

(This test exercises the same call shape Step 3 below adds to `bootstrap.dart`, rather than driving the full `bootstrap()` entrypoint, since `bootstrap()` also touches DI/PocketBase/push/billing init that would need extensive mocking unrelated to this feature.)

- [x] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/app/bootstrap_error_capture_test.dart`
Expected: FAIL — `PocketCoderErrorCodeMapper` import resolves (Task 1 done), but this is a self-contained assertion, so it should actually currently PASS once Task 1 lands, since it doesn't touch `bootstrap.dart` at all yet. Treat this as a smoke test confirming the call shape compiles and behaves as expected; the real regression protection is Step 4's manual verification plus this test locking the exact `ErrorEntry` shape used in `bootstrap.dart`.

- [x] **Step 3: Wire `bootstrap.dart`**

In `lib/app/bootstrap.dart`, add imports:

```dart
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/infrastructure/errors/error_code_mapper.dart';
import 'package:pocketcoder_flutter/presentation/errors/error_box_page_builder.dart';
import 'package:cubit_ui_flow/cubit_ui_flow.dart' show IExceptionKeyMapper;
```

Change the existing catch clause at `bootstrap.dart:61-69` from `catch (e)` to `catch (e, stack)` and add a capture call:

```dart
    try {
      final pocketBase = getIt<PocketBase>();
      final userId = pocketBase.authStore.record?.id;
      if (pocketBase.authStore.isValid && userId != null) {
        await billingService.identify(userId);
      }
    } catch (e, stack) {
      debugPrint('Bootstrap: Warning - billing identify on session restore failed: $e');
      await getIt<ErrorBoxStorage>().saveError(ErrorEntry(
        source: 'Bootstrap.billingIdentify',
        errorType: e.runtimeType.toString(),
        errorCode: PocketCoderErrorCodeMapper.mapError(e),
        stackTrace: stack.toString(),
        timestamp: DateTime.now(),
      ));
    }
```

Replace `_configureErrorPrivserver()`'s body entirely:

```dart
void _configureErrorPrivserver() {
  ErrorPrivserver.configure(
    ErrorPrivserverConfig(
      storage: getIt<ErrorBoxStorage>(),
      reporter: (_) async {}, // no-op: no network transmission, see spec §3
      errorCodeMapper: PocketCoderErrorCodeMapper.mapError,
      exceptionMapper: (error) => getIt<IExceptionKeyMapper>().map(error),
      showToast: false, // dead field in this package version (pinned commit 3565d9d4), set explicitly for clarity
      toastBuilder: const _NoopErrorToastBuilder(),
      pageBuilder: const PocketCoderErrorBoxPageBuilder(),
    ),
  );
}

/// Satisfies ErrorPrivserverConfig.toastBuilder, which is required by the
/// constructor but never invoked anywhere in the pinned package version
/// (commit 3565d9d4) — confirmed by grep, no automatic toast-on-capture
/// exists. This class exists purely to compile.
class _NoopErrorToastBuilder extends ErrorToastBuilder {
  const _NoopErrorToastBuilder();

  @override
  void show(
    BuildContext context,
    String message, {
    required VoidCallback onDismiss,
    required VoidCallback onSend,
  }) {}
}
```

`_configureErrorPrivserver()`'s call site at `bootstrap.dart:78` and its surrounding `debugPrint`s stay unchanged.

- [x] **Step 4: Run the full test suite for this file's package**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/app/bootstrap_error_capture_test.dart && flutter analyze lib/app/bootstrap.dart`
Expected: test PASSES; `flutter analyze` reports no new errors (it will already have been clean before this change — this catches typos/missing imports in the edit above).

- [x] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/app/bootstrap.dart client/packages/pocketcoder_flutter/test/app/bootstrap_error_capture_test.dart
git commit -m "feat(client): configure ErrorPrivserver and capture bootstrap-level failures"
```

---

## Task 4: `PocketCoderErrorBoxPageBuilder` and the Error Inbox screen

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/presentation/errors/error_box_page_builder.dart`
- Create: `client/packages/pocketcoder_flutter/lib/presentation/errors/error_inbox_screen.dart`
- Test: `client/packages/pocketcoder_flutter/test/presentation/errors/error_inbox_screen_test.dart`

**Interfaces:**
- Consumes: `ErrorBoxPageCubit`, `ErrorBoxPageState`, `ErrorBoxEntry`, `ErrorBoxPageBuilder` from `package:flutter_error_privserver/flutter_error_privserver.dart` (all confirmed present in the pinned commit, spec §2). `PocketCoderShell`, `BiosFrame`, `TerminalText`, `TerminalButton`, `UiFlowListener` widget conventions from `lib/presentation/core/widgets/`.
- Produces: `class PocketCoderErrorBoxPageBuilder implements ErrorBoxPageBuilder { const PocketCoderErrorBoxPageBuilder(); Widget build(BuildContext context); }` — consumed by Task 3's `configure()` call and by Task 5's route.
- Produces: `class ErrorInboxScreen extends StatelessWidget` — the widget `PocketCoderErrorBoxPageBuilder.build()` returns, wrapped in its own `BlocProvider<ErrorBoxPageCubit>`.

- [x] **Step 1: Write the failing widget test**

```dart
// test/presentation/errors/error_inbox_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:pocketcoder_flutter/presentation/errors/error_inbox_screen.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';

class MockErrorBoxStorage extends Mock implements ErrorBoxStorage {}

final _entry = ErrorBoxEntry(
  id: 'e1',
  fingerprint: 'fp1',
  errorData: ErrorEntry(
    source: 'ChatCubit',
    errorType: 'ChatException',
    errorCode: 'CHAT_001',
    stackTrace: '#0 fake stack',
    timestamp: DateTime(2026, 1, 1),
  ),
  occurrenceCount: 3,
  firstOccurred: DateTime(2026, 1, 1),
  lastOccurred: DateTime(2026, 1, 2),
);

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  late MockErrorBoxStorage storage;

  setUp(() {
    storage = MockErrorBoxStorage();
    ErrorPrivserver.configure(ErrorPrivserverConfig(
      storage: storage,
      reporter: (_) async {},
      errorCodeMapper: (_) => 'ERR_TEST',
      exceptionMapper: (_) => null,
      showToast: false,
      toastBuilder: _FakeToastBuilder(),
      pageBuilder: _FakePageBuilder(),
    ));
  });

  testWidgets('renders a captured entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);

    await tester.pumpWidget(_wrap(
      BlocProvider(
        create: (_) => ErrorBoxPageCubit()..loadErrors(),
        child: const ErrorInboxScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ChatCubit'), findsOneWidget);
    expect(find.text('CHAT_001'), findsOneWidget);
  });

  testWidgets('shows empty state with no entries', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(
      BlocProvider(
        create: (_) => ErrorBoxPageCubit()..loadErrors(),
        child: const ErrorInboxScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO ERRORS CAPTURED'), findsOneWidget);
  });

  testWidgets('delete removes an entry', (tester) async {
    when(() => storage.getUnsentErrors()).thenAnswer((_) async => [_entry]);
    when(() => storage.deleteError('e1')).thenAnswer((_) async {});

    await tester.pumpWidget(_wrap(
      BlocProvider(
        create: (_) => ErrorBoxPageCubit()..loadErrors(),
        child: const ErrorInboxScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    verify(() => storage.deleteError('e1')).called(1);
  });
}

class _FakeToastBuilder extends ErrorToastBuilder {
  @override
  void show(BuildContext context, String message,
      {required VoidCallback onDismiss, required VoidCallback onSend}) {}
}

class _FakePageBuilder extends ErrorBoxPageBuilder {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

Confirm the exact ARB key/string for the empty state before asserting `'NO ERRORS CAPTURED'` literally — Step 3 below defines it as `errorsEmpty` → `"NO ERRORS CAPTURED"`; if you change that string, update this assertion to match.

- [x] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/errors/error_inbox_screen_test.dart`
Expected: FAIL — `error_inbox_screen.dart` doesn't exist yet.

- [x] **Step 3: Add l10n keys**

Add to `lib/l10n/app_en.arb` (alongside the other `settings*`/`system*` keys, e.g. near `systemChecksTitle`/`systemChecksEmpty`):

```json
  "errorsTitle": "ERROR REPORTS",
  "errorsEmpty": "NO ERRORS CAPTURED",
  "errorsClearAll": "CLEAR ALL",
  "errorsOccurred": "Occurred {count}x",
  "@errorsOccurred": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
```

(matches the existing parameterized-key pattern, e.g. `llmModelsAvailable`/`@llmModelsAvailable` at `app_en.arb:132-135` — every other parameterized key in this file declares `"type": "int"` on its placeholder, not an empty object.)

Also add `"settingsErrorsRow": "ERROR REPORTS"` is not needed separately — Task 5 reuses `errorsTitle` for both the settings row label and the screen title.

- [x] **Step 4: Write `ErrorInboxScreen`**

```dart
// lib/presentation/errors/error_inbox_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'package:intl/intl.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/pocketcoder_shell.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_frame.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_text.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_button.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import '../../app_router.dart' show NavPillar;

class ErrorInboxScreen extends StatelessWidget {
  const ErrorInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PocketCoderShell(
      title: context.l10n.errorsTitle,
      activePillar: NavPillar.configure,
      showBack: true,
      body: BiosFrame(
        title: context.l10n.errorsTitle,
        child: BlocBuilder<ErrorBoxPageCubit, ErrorBoxPageState>(
          builder: (context, state) {
            if (state.unsentErrors.isEmpty) {
              return Padding(
                padding: EdgeInsets.all(AppSizes.space * 2),
                child: TerminalText(
                  context.l10n.errorsEmpty,
                  size: TerminalTextSize.small,
                ),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(AppSizes.space),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TerminalButton(
                      label: context.l10n.errorsClearAll,
                      isPrimary: false,
                      onTap: () async {
                        final cubit = context.read<ErrorBoxPageCubit>();
                        for (final entry in List.of(state.unsentErrors)) {
                          await cubit.deleteError(entry.id);
                        }
                      },
                    ),
                  ),
                ),
                for (final entry in state.unsentErrors)
                  _ErrorTile(entry: entry),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final ErrorBoxEntry entry;

  const _ErrorTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: TerminalText(entry.errorData.source, size: TerminalTextSize.small),
      subtitle: TerminalText(
        '${entry.errorData.errorCode} · ${DateFormat.yMd().add_Hm().format(entry.lastOccurred)} · '
        '${context.l10n.errorsOccurred(entry.occurrenceCount)}',
        size: TerminalTextSize.mini,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => context.read<ErrorBoxPageCubit>().deleteError(entry.id),
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(entry.errorData.stackTrace),
          ),
        ),
      ],
    );
  }
}
```

`intl` is already available (pulled in transitively via Flutter's l10n tooling and already imported elsewhere under `lib/l10n/`) — no `pubspec.yaml` change needed for the `DateFormat` import above.

- [x] **Step 5: Write `PocketCoderErrorBoxPageBuilder`**

```dart
// lib/presentation/errors/error_box_page_builder.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_error_privserver/flutter_error_privserver.dart';
import 'error_inbox_screen.dart';

class PocketCoderErrorBoxPageBuilder extends ErrorBoxPageBuilder {
  const PocketCoderErrorBoxPageBuilder();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ErrorBoxPageCubit()..loadErrors(),
      child: const ErrorInboxScreen(),
    );
  }
}
```

- [x] **Step 6: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs && flutter test test/presentation/errors/error_inbox_screen_test.dart`
(`build_runner` regenerates `app_localizations.dart`/`l10n_key_resolver.g.dart` from the new ARB keys added in Step 3, which the screen and test both need to compile.)
Expected: all three test cases PASS.

- [x] **Step 7: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/errors/ client/packages/pocketcoder_flutter/test/presentation/errors/ client/packages/pocketcoder_flutter/lib/l10n/app_en.arb client/packages/pocketcoder_flutter/lib/l10n/app_localizations*.dart client/packages/pocketcoder_flutter/lib/l10n/l10n_key_resolver.g.dart client/packages/pocketcoder_flutter/pubspec.yaml client/packages/pocketcoder_flutter/pubspec.lock
git commit -m "feat(client): add Error Inbox screen backed by ErrorBoxPageCubit"
```

**Return to Task 3, Step 3** now that `PocketCoderErrorBoxPageBuilder` exists, if it wasn't already completed.

---

## Task 5: Settings entry point and route

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/app_router.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/test/presentation/settings/settings_screen_test.dart` (already exists — has full `GoRouter`/mock-cubit scaffolding and two existing `testWidgets` cases for LOGOUT; add a new case to it, don't create a separate file)

**Interfaces:**
- Consumes: `PocketCoderErrorBoxPageBuilder` (Task 4), `ErrorInboxScreen` (Task 4).
- Produces: `AppRoutes.configureErrors = '/configure/errors'`, `RouteNames.configureErrors = 'configureErrors'` — terminal additions, nothing downstream depends on these beyond this task.

- [ ] **Step 1: Add the route**

In `lib/app_router.dart`, add to `AppRoutes` (near `configureObservability`, `app_router.dart:295`):
```dart
  static const String configureErrors = '/configure/errors';
```
Add to `RouteNames` (near `configureObservability`, `app_router.dart:338`):
```dart
  static const String configureErrors = 'configureErrors';
```
Add the import:
```dart
import 'package:pocketcoder_flutter/presentation/errors/error_box_page_builder.dart';
```
Add a `GoRoute` (near the `configureObservability` route, `app_router.dart:207-215`), using the same `TerminalTransition.buildPage` wrapper pattern as its neighbors, but routing through the builder rather than instantiating `ErrorInboxScreen` directly — this keeps `ErrorPrivserver.page()`/`PocketCoderErrorBoxPageBuilder` as the single source of truth for how the page is assembled (its own `BlocProvider` included), matching how the package's `pageBuilder` contract is meant to be used:
```dart
      GoRoute(
        path: AppRoutes.configureErrors,
        name: RouteNames.configureErrors,
        pageBuilder: (context, state) => TerminalTransition.buildPage(
          context: context,
          state: state,
          child: Builder(
            builder: (context) => const PocketCoderErrorBoxPageBuilder().build(context),
          ),
        ),
      ),
```

- [ ] **Step 2: Add the settings row**

In `lib/presentation/settings/settings_screen.dart`, add a row to the `settingsSystemSection` group in `_sections` (`settings_screen.dart:32-36`):
```dart
      (context.l10n.settingsSystemSection, [
        ('SYSTEM CHECKS', '[DIAGNOSE]', 'configureSystemChecks'),
        ('PERMISSION RELAY', '[STATUS]', 'configurePaywall'),
        ('SERVER UPDATE', '[UPDATE]', 'updateServer'),
        (context.l10n.errorsTitle, '[VIEW]', 'configureErrors'),
      ]),
```
Add a case in `_navigateTo` (`settings_screen.dart:134-159`):
```dart
      case 'configureErrors':
        context.push(AppRoutes.configureErrors);
```

- [ ] **Step 3: Extend the existing settings screen navigation test**

`test/presentation/settings/settings_screen_test.dart` already has `buildTestable()` wiring a real `GoRouter` with mocked `AuthCubit`/`McpCubit` dependencies and two `testWidgets` cases (LOGOUT confirm/cancel). Add a third case to that `main()` block, following the same pattern — register an additional route for the destination and assert the router navigated:

```dart
  testWidgets('tapping ERROR REPORTS navigates to /configure/errors',
      (tester) async {
    await tester.pumpWidget(buildTestable());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('ERROR REPORTS'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERROR REPORTS'));
    await tester.pumpAndSettle();

    expect(find.text('errors-placeholder'), findsOneWidget);
  });
```

This requires adding a matching route to `buildTestable()`'s router (alongside its existing `/settings` and `/onboarding` routes):
```dart
        GoRoute(
          path: '/configure/errors',
          builder: (context, state) => const Text('errors-placeholder'),
        ),
```
Use `AppRoutes.configureErrors` (from Task 5 Step 1) as that route's `path` value instead of the literal `'/configure/errors'` string, so the test breaks if the two ever drift apart.

- [ ] **Step 4: Run tests**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/presentation/settings/ && flutter analyze lib/app_router.dart lib/presentation/settings/settings_screen.dart`
Expected: PASS, no new analyzer errors.

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/app_router.dart client/packages/pocketcoder_flutter/lib/presentation/settings/settings_screen.dart client/packages/pocketcoder_flutter/test/presentation/settings/settings_screen_test.dart
git commit -m "feat(client): add Error Reports entry point to Settings"
```

---

## Task 6: Manual verification

**Files:** none (no code changes — this task is a checklist, run after Tasks 1-5 are all committed)

- [ ] **Step 1: Run the full test suite**

Run: `cd client/packages/pocketcoder_flutter && flutter test`
Expected: all tests PASS, including the new ones from Tasks 1, 3, 4, 5.

- [ ] **Step 2: Run the app and force a real cubit failure**

Run: `client/scripts/run_chrome_incognito.sh` (or `run_ios.sh`/`run_android.sh`). Log in, then disable network (airplane mode / dev-tools offline throttling) and trigger any action that goes through an `AppCubit` (e.g. refresh the chat list). Confirm a toast/failure state appears as before (unchanged behavior) — then re-enable network, navigate to Settings → SYSTEM → ERROR REPORTS, and confirm the failure appears with a non-empty `source`/`errorCode`/stack trace.

- [ ] **Step 3: Verify persistence across restart**

Fully close and relaunch the app. Navigate back to Settings → ERROR REPORTS. Confirm the entry from Step 2 is still present (proves `SharedPreferences` persistence, not just in-memory state).

- [ ] **Step 4: Verify dedup/occurrence counting**

Repeat the same failure from Step 2 (same action, same exception type) 2-3 more times. Confirm the inbox shows **one** entry for it with an incremented occurrence count, not multiple duplicate entries (proves `SharedPrefsErrorBoxStorage`'s fingerprint dedup, spec §2).

- [ ] **Step 5: Verify delete and clear-all**

Delete the single entry via its trailing delete icon — confirm it disappears and the empty state (`NO ERRORS CAPTURED`) shows if it was the only entry. Trigger 2+ distinct failures (different cubits/exception types), then use "CLEAR ALL" and confirm the list empties.

- [ ] **Step 6: Note the known gap**

Confirm (by reading `lib/application/*/*_cubit.dart` for the 10 cubits listed in the spec's §2/§3) that this is still accurate at implementation time — package/dependency updates between spec-writing and implementation could have changed which cubits extend `AppCubit`. If any of those 10 have since been migrated to `AppCubit`, no action needed (they'll just start working automatically); if new non-`AppCubit` cubits have been added since, note them for a future follow-up but do not expand this plan's scope to cover them.
