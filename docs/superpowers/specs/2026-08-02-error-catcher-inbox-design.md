# Error Catcher Inbox — Design Spec

**Date:** 2026-08-02
**Status:** DESIGN — ready for review
**Grounded against (code, not docs):** `client/packages/pocketcoder_flutter/lib/app/bootstrap.dart`, `lib/support/extensions/cubit_ui_flow_extension.dart`, `lib/core/try_operation.dart`, `lib/infrastructure/feedback/exception_mapper.dart`, `lib/presentation/settings/settings_screen.dart`, `pubspec.yaml`, and **the exact pinned copy** of `flutter_error_privserver` at `~/.pub-cache/git/flutter_error_privserver-3565d9d47f24bee06bc88314b51a7df04ee3f78e` (matches `pubspec.yaml`'s `ref: 3565d9d47f24bee06bc88314b51a7df04ee3f78e` exactly) — specifically `lib/src/error_privserver.dart`, `lib/src/cubits/error_privserver_cubit.dart`, `lib/src/cubits/error_box_page_cubit.dart`, `lib/src/config/error_privserver_config.dart`, `lib/src/storage/error_box_storage.dart`, `lib/src/models/error_entry.dart`, `lib/src/builders/{error_toast_builder,error_box_page_builder}.dart`, `lib/src/utils/error_code_mapper.dart`.

**Revision note:** an earlier draft of this spec was grounded against a *different, newer* copy of the same package (found in a sibling project, `quanitya`) that has a meaningfully different API — a static `ErrorPrivserver.captureError()` helper, no `toastBuilder`/`pageBuilder`/`ErrorBoxPageCubit`. Pocketcoder's actually-pinned commit has neither of those. This revision is grounded only against the real pinned source, corrected after an independent review pass caught the mismatch.

---

## 1. Why this exists

PocketCoder's README sells "fully self-hosted, no telemetry" as a differentiator against cloud/chat-bridge competitors. That rules out Sentry/PostHog-style hosted crash reporting by default (see conversation preceding this spec). But the team still wants visibility into what broke, without anything leaving the device automatically. The agreed shape: capture errors locally into an on-device inbox the user can review; reporting them out (a GitHub-issue deep link) is deliberately deferred to a follow-up — this spec covers capture + storage + inbox UI only.

## 2. Current state, verified directly from code

- **`flutter_error_privserver` is already a pinned dependency** (`pubspec.yaml:29-31`) and **already wired into the cubit layer**: `AppCubit` (`cubit_ui_flow_extension.dart:9-10`) extends `TryOperationCubit` `with ErrorPrivserverMixin<S>`. Every cubit's `tryOperation` failure path that goes through `AppCubit` already runs through `ErrorPrivserverMixin._captureError` (`error_privserver_cubit.dart:56-70,90-121`) — **provided the mixin has been configured**.
- **Not every cubit extends `AppCubit`.** `BillingCubit`, `ObservabilityCubit`, `NotificationRuleCubit`, `SandboxAgentCubit`, `McpCubit`, `SchedulerCubit`, `SkillsCubit`, `PocoCubit`, `StatusCubit`, and `ToolPermissionsCubit` extend `Cubit<S>` directly and bypass `ErrorPrivserverMixin` entirely — their failures will **not** appear in the inbox from this spec alone. Treated as a known gap, not fixed here (§3).
- **It has never been configured.** `bootstrap.dart:101-107`:
  ```dart
  void _configureErrorPrivserver() {
    // Note: Actual configuration requires repository implementations.
    // This is a placeholder for where you would wire up your error reporting.
    // See quanitya example for full implementation with ErrorBoxRepository.
    debugPrint('ErrorPrivserver: Initialization placeholder');
  }
  ```
  `ErrorPrivserverMixin.configure()` is never called, so `_config` stays `null` and `_captureError` no-ops. **Nothing is currently captured or stored anywhere.**
- **`tryMethod`** (repo/service layer, `try_operation.dart:76-97`) wraps any non-matching exception in `SafeExceptionCause` (`try_operation.dart:37-48`), whose `toString()` returns only the original exception's `Type` — no message, no user data — then throws a typed domain exception (`AuthException`, `ChatException`, etc.) built from `_createSafeErrorContext` (`try_operation.dart:57-59`, method name + type only). These typed exceptions are what a cubit's `tryOperation` ultimately catches, so **whatever reaches the capture point is already privacy-clean by construction** — no PII-scrubbing logic needs to be added at the capture layer.
- **`AppExceptionKeyMapper`** (`infrastructure/feedback/exception_mapper.dart:11`, registered `@LazySingleton(as: IExceptionKeyMapper)`) already maps the app's typed exceptions to localized `MessageKey`s for toasts — exactly the shape `ErrorPrivserverConfig.exceptionMapper` wants (`MessageKey? Function(Object error)`). Reusable via `getIt<IExceptionKeyMapper>()`, no new mapping logic needed.
- **No error inbox UI exists.** No screen, cubit, or repository under any `errors/` directory in `pocketcoder_flutter`.
- **`ErrorPrivserverConfig`'s real shape** (`error_privserver_config.dart:9-39`) is wider than the package's own doc-comment example suggests:
  ```dart
  const ErrorPrivserverConfig({
    required this.storage,
    required this.reporter,        // Future<void> Function(ErrorEntry) — NOT Future<bool>
    required this.errorCodeMapper,
    required this.exceptionMapper,
    this.showToast = true,
    required this.toastBuilder,    // ErrorToastBuilder — required but dead, see below
    required this.pageBuilder,     // ErrorBoxPageBuilder — required, and IS used
  });
  ```
  `showToast`/`toastBuilder` are accepted by the constructor but **never read anywhere else in the package** (confirmed by grep across `lib/`) — dead configuration in this pinned version, not wired to any automatic toast-on-capture behavior (the mixin's own doc comment even notes "Toast functionality removed since it requires BuildContext"). A concrete `ErrorToastBuilder` subclass is still required to satisfy the constructor, even though nothing will ever call its `.show()`. `pageBuilder`, by contrast, **is** used: `ErrorPrivserver.page(BuildContext)` (`error_privserver.dart:32-38`) returns `config.pageBuilder.build(context)` — the intended integration point for the inbox screen (§4.4).
- **The package already ships `ErrorBoxPageCubit`** (`error_box_page_cubit.dart:47-107`) — `loadErrors()`, `sendError(id)`, `sendAllErrors()`, `deleteError(id)`, reading `ErrorPrivserverMixin.config` directly (not DI-injected; instantiated directly by whatever builds the page, per the package's own doc comment). **This spec does not need a custom cubit** — see §4.3.
- **`ErrorBoxEntry`'s fields are nested, not flat** (`error_entry.dart:73-92`): `id`, `fingerprint`, `occurrenceCount`, `firstOccurred`, `lastOccurred`, `wasSent`, `sentAt` are on `ErrorBoxEntry` itself; `source`/`errorType`/`errorCode`/`stackTrace`/`timestamp`/`userMessage` are on the nested `errorData` (`ErrorEntry`) — i.e. `entry.errorData.stackTrace`, not `entry.stackTrace`.
- **Storage**: the package ships `SharedPrefsErrorBoxStorage` (`error_box_storage.dart:22-123`) implementing `ErrorBoxStorage` — save/list-unsent/get-by-id/mark-sent/delete/count, one JSON blob under a single `SharedPreferences` key, with fingerprint-based deduplication (same fingerprint while unsent → increments `occurrenceCount` instead of duplicating). Reused as-is per user decision — the data is small and short-lived, no Drift table needed. **No `deleteAll` method exists on the interface** — only `deleteError(id)` singular.
- **One swallowed error path in `bootstrap.dart` sits outside any cubit**: `bootstrap.dart:61-69` — `billingService.identify()` on session restore, caught (`catch (e)`) and only `debugPrint`'d. This is the only bootstrap-level catch-and-swallow in the file; the push/billing *initialization* calls (`bootstrap.dart:49-55`) have no try/catch of their own and are covered by the outer `bootstrap()` try/catch (`bootstrap.dart:44-86`), which rethrows and crashes startup — intentionally unchanged by this spec, since a startup failure there should stay loud. **This pinned package version has no `ErrorPrivserver.captureError()` convenience helper** (that only exists in the newer copy this spec was mistakenly first grounded against — see the revision note above). Capturing at this site means constructing an `ErrorEntry` and calling `storage.saveError(...)` directly against the same storage instance used in DI (§4.2), not calling a package-provided static helper.

## 3. Goal and explicit non-goals

**Goal:** every exception that currently either (a) reaches a cubit's `tryOperation` on an `AppCubit` subclass and only flips UI state to failure, or (b) is caught-and-`debugPrint`'d at the one bootstrap swallow site, is durably captured on-device (type, source, code, stack trace, timestamp, occurrence count) and visible to the user in a new Settings → Error Reports screen, where they can review and delete entries.

**Explicit non-goals (deferred to a follow-up spec or explicitly out of scope):**
- No network transmission of any kind. `reporter` is a stub that is never exercised by this build's UI.
- No GitHub-issue deep link / report action. That's the next spec once this lands.
- No opt-in/opt-out toggle — capture is local-only and always on, same trust posture as writing to a debug log, so there's nothing to consent to.
- No Drift migration — `SharedPrefsErrorBoxStorage` as shipped by the package is used unmodified.
- No auto-send / batching — `ErrorBoxPageCubit.sendError`/`sendAllErrors` exist in the package but this build's UI does not wire up "send" actions (§4.4), since `reporter` is a no-op.
- **No migration of the 10 non-`AppCubit` cubits** (§2) to use `ErrorPrivserverMixin`. Each of those is its own error-handling surface with its own base-class reasons for not extending `AppCubit`; retrofitting them is a separate, per-cubit decision outside this spec's scope. Their failures remain invisible to the inbox after this build ships — a real, acknowledged gap, not an oversight.

## 4. Components

### 4.1 `PocketCoderErrorCodeMapper` (new)

`lib/infrastructure/errors/error_code_mapper.dart`. A pure function `String mapError(Object error)` switching on `error.runtimeType` against the app's known domain exceptions (`AuthException`, `ChatException`, `ChatListException`, `PermissionException`, `AiException`, `ToolPermissionsException` — the same set `AppExceptionKeyMapper` already switches on) to short codes (`AUTH_001`, `CHAT_001`, ...), falling back to `'ERR_${error.runtimeType}'` for anything unmapped. No string-matching against `error.toString()` — unlike the package's own `ErrorCodeMapper.mapError` default, PocketCoder's exceptions are already type-only by construction (§2), so message-content heuristics would be dead code, not a safety net.

### 4.2 Bootstrap wiring (`bootstrap.dart`)

Register `SharedPrefsErrorBoxStorage` as a singleton `ErrorBoxStorage` (via the existing `@module`-style injectable provider pattern, e.g. `infrastructure/core/external_module.dart`), then replace `_configureErrorPrivserver()`'s body:

```dart
void _configureErrorPrivserver() {
  ErrorPrivserver.configure(
    ErrorPrivserverConfig(
      storage: getIt<ErrorBoxStorage>(),
      reporter: (_) async {}, // no-op: reporting is out of scope, see §3
      errorCodeMapper: PocketCoderErrorCodeMapper.mapError,
      exceptionMapper: (error) => getIt<IExceptionKeyMapper>().map(error),
      showToast: false, // dead field in this package version, set explicitly for clarity
      toastBuilder: const _NoopErrorToastBuilder(), // required by the constructor, never invoked
      pageBuilder: const PocketCoderErrorBoxPageBuilder(),
    ),
  );
}
```

`_NoopErrorToastBuilder` is a trivial private `ErrorToastBuilder` subclass with an empty `show()` body — it exists purely to satisfy the `required` constructor param; nothing in the package ever calls it (§2). This call must run after `configureDependencies()` (already the case — called at `bootstrap.dart:78`, after DI setup at line 46) so `getIt<IExceptionKeyMapper>()` resolves.

Also update the existing catch at `bootstrap.dart:61-69` to capture stack trace and save an entry directly:
```dart
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

### 4.3 `PocketCoderErrorBoxPageBuilder` (new)

`lib/presentation/errors/error_box_page_builder.dart`, `implements ErrorBoxPageBuilder`. `build(context)` returns a `BlocProvider(create: (_) => ErrorBoxPageCubit()..loadErrors(), child: ErrorInboxScreen())` — using the package's own `ErrorBoxPageCubit` directly rather than a new app cubit, since it already provides the exact `loadErrors`/`deleteError` surface this build needs (§2). No DI registration for the cubit itself (it isn't injectable, matching the package's intended usage).

### 4.4 Error Inbox screen (new)

`lib/presentation/errors/error_inbox_screen.dart`. Consumes `ErrorBoxPageCubit`'s `ErrorBoxPageState` (`unsentErrors`, `isLoading`, `error`). Renders a list of captured errors — `entry.errorData.source`, `.errorType`, `.errorCode`, `entry.occurrenceCount`, `entry.lastOccurred` — tap-to-expand for `entry.errorData.stackTrace`, per-entry delete calling `cubit.deleteError(entry.id)`. "Clear all" iterates `state.unsentErrors` calling `deleteError` per id (no batch method exists on the cubit or storage, §2). No "send" button — `sendError`/`sendAllErrors` exist on the cubit but are not wired to any UI control, since `reporter` is a no-op (§3). Empty state: "No errors captured" (localized `MessageKey`, per `client/CLAUDE.md`'s no-hardcoded-strings rule).

### 4.5 Settings entry point

One new row in `settings_screen.dart`, alongside the existing MCP/scheduler/skills/tool-permissions/agent-config/notification rows, navigating via GoRouter to a route that calls `ErrorPrivserver.page(context)` (or directly to `PocketCoderErrorBoxPageBuilder().build(context)` — equivalent, since `page()` just delegates to `config.pageBuilder.build(context)`, §2).

## 5. Data flow

- **Cubit-originated errors (`AppCubit` subclasses only, §3 non-goal for the rest):** `tryOperation` catches → `ErrorPrivserverMixin._captureError` (already wired, just previously inert) → `ErrorBoxStorage.saveError` → fingerprint-deduped entry in the shared-prefs blob. No new code on this path — it starts working the moment §4.2's `configure()` call lands.
- **Bootstrap-originated errors:** explicit `storage.saveError(...)` call at the one identified swallow site (§4.2), same storage instance.
- **Inbox screen:** `ErrorBoxPageCubit.loadErrors()` → `config.storage.getUnsentErrors()` (the storage's only "list" method; "unsent" is the package's own naming, not meaningful here since nothing is ever sent — every captured entry stays in this list until deleted).

## 6. Privacy

Nothing new to design here — carried, not invented. `SafeExceptionCause` (§2) already guarantees no PII reaches `tryOperation`'s catch clause, so the inbox is safe to render unredacted for the `AppCubit` path. The bootstrap-level capture site (§4.2) passes `e`/`stack` from a raw (non-`tryMethod`-wrapped) catch — `billingService.identify()` failures are not passed through `tryMethod` today, so this is a genuine, if narrow, gap in the "always privacy-clean by construction" guarantee for that one entry. Flagged, not blocked: capture is still strictly better than the current silent-drop behavior, and the exception here (a `BillingService` call) is not expected to carry user-entered data in practice.

## 7. Testing

- Unit test `PocketCoderErrorCodeMapper.mapError` against each known exception type plus an unmapped fallback case.
- Unit test the bootstrap-level capture call (billing-identify swallow site) saves an `ErrorEntry` with the expected fields.
- Widget test for `error_inbox_screen.dart`: populated list (via a fake `ErrorBoxStorage`), empty state, delete interaction — matching the existing `test/presentation/...` mirror-of-`lib/` convention.
- Manual: force a real cubit failure on an `AppCubit`-based flow (e.g. toggle airplane mode mid-request), confirm the entry appears in Settings → Error Reports, persists across app restart (proves `SharedPreferences` persistence), and that occurrence count increments on repeat.
