# Error Catcher Inbox — Design Spec

**Date:** 2026-08-02
**Status:** DESIGN — ready for review
**Grounded against (code, not docs):** `client/packages/pocketcoder_flutter/lib/app/bootstrap.dart`, `lib/support/extensions/cubit_ui_flow_extension.dart`, `lib/core/try_operation.dart`, `lib/infrastructure/feedback/exception_mapper.dart`, `lib/presentation/settings/settings_screen.dart`, `pubspec.yaml`, and the `flutter_error_privserver` package (git dependency, pinned at `git@github.com:qtpi-bonding-org/flutter_error_privserver.git`) — specifically `lib/src/error_privserver.dart`, `lib/src/cubits/error_privserver_cubit.dart`, `lib/src/config/error_privserver_config.dart`, `lib/src/storage/error_box_storage.dart`, `lib/src/utils/error_code_mapper.dart`.

---

## 1. Why this exists

PocketCoder's README sells "fully self-hosted, no telemetry" as a differentiator against cloud/chat-bridge competitors. That rules out Sentry/PostHog-style hosted crash reporting by default (see conversation preceding this spec). But the team still wants visibility into what broke, without anything leaving the device automatically. The agreed shape: capture errors locally into an on-device inbox the user can review; reporting them out (a GitHub-issue deep link) is deliberately deferred to a follow-up — this spec covers capture + storage + inbox UI only.

## 2. Current state, verified directly from code

- **`flutter_error_privserver` is already a pinned dependency** (`pubspec.yaml:29-31`) and **already wired into the cubit layer**: `AppCubit` (`cubit_ui_flow_extension.dart:9-10`) extends `TryOperationCubit` `with ErrorPrivserverMixin<S>`. Every cubit in the app extends `AppCubit`, so every cubit's `tryOperation` failure path already runs through `ErrorPrivserverMixin._captureError` (`error_privserver_cubit.dart:52-56,73-94`) — **provided the mixin has been configured**.
- **It has never been configured.** `bootstrap.dart:101-107`:
  ```dart
  void _configureErrorPrivserver() {
    // Note: Actual configuration requires repository implementations.
    // This is a placeholder for where you would wire up your error reporting.
    // See quanitya example for full implementation with ErrorBoxRepository.
    debugPrint('ErrorPrivserver: Initialization placeholder');
  }
  ```
  `ErrorPrivserverMixin.configure()` is never called, so `_config` stays `null` and `_captureError` no-ops (`error_privserver_cubit.dart:74`, `error_privserver.dart` static guards throughout). **Nothing is currently captured or stored anywhere.**
- **`tryMethod`** (repo/service layer, `try_operation.dart:76-97`) wraps any non-matching exception in `SafeExceptionCause` (`try_operation.dart:37-48`), whose `toString()` returns only the original exception's `Type` — no message, no user data — then throws a typed domain exception (`AuthException`, `ChatException`, etc.) whose own message is built from `_createSafeErrorContext` (`try_operation.dart:57-59`, method name + type only). These typed exceptions propagate up and are what a cubit's `tryOperation` ultimately catches, so **whatever reaches the capture point is already privacy-clean by construction** — no PII-scrubbing logic needs to be added at the capture layer.
- **`AppExceptionKeyMapper`** (`infrastructure/feedback/exception_mapper.dart:11`, registered `@LazySingleton(as: IExceptionKeyMapper)`) already maps the app's typed exceptions to localized `MessageKey`s for toasts. This is exactly the shape `ErrorPrivserverConfig.exceptionMapper` wants (`error_privserver_config.dart:27-28`: `MessageKey? Function(Object error)`) — it can be reused via `getIt<IExceptionKeyMapper>()`, no new mapping logic needed.
- **No error inbox UI exists.** No screen, cubit, or repository under any `errors/` directory in `pocketcoder_flutter`.
- **`ErrorPrivserverConfig` requires a `reporter`** (`Future<bool> Function(ErrorEntry)`, `error_privserver_config.dart:21-22`) — a hard requirement of the package's config object, even though this spec doesn't build a report path. It is only ever invoked by `ErrorPrivserver.sendError`/`sendAllErrors` (`error_privserver.dart:52-60,107-126`), which this spec's UI will not call.
- **Storage**: the package ships `SharedPrefsErrorBoxStorage` (`error_box_storage.dart:22-123`) implementing `ErrorBoxStorage` — save/list-unsent/get-by-id/mark-sent/delete/count, one JSON blob under a single `SharedPreferences` key, with fingerprint-based deduplication (same fingerprint while unsent → increments `occurrenceCount` instead of duplicating, `error_box_storage.dart:31-53`). Confirmed via user decision: reuse this as-is rather than building a Drift table — the data is small and short-lived.
- **One swallowed error path in `bootstrap.dart` sits outside any cubit**, so `ErrorPrivserverMixin`'s auto-capture never sees it: `bootstrap.dart:61-69` — `billingService.identify()` on session restore, caught (`catch (e)`) and only `debugPrint`'d. This is the only bootstrap-level catch-and-swallow in the file; the push/billing *initialization* calls (`bootstrap.dart:49-55`) have no try/catch of their own and are covered by the outer `bootstrap()` try/catch (`bootstrap.dart:44-86`), which rethrows and crashes startup — that behavior is intentionally unchanged by this spec, since a startup failure there should stay loud, not get silently captured and swallowed.

## 3. Goal and explicit non-goals

**Goal:** every exception that currently either (a) silently reaches a cubit's `tryOperation` and only flips UI state to failure, or (b) is caught-and-`debugPrint`'d at bootstrap and otherwise vanishes, is durably captured on-device (type, source, code, stack trace, timestamp, occurrence count) and visible to the user in a new Settings → Error Reports screen, where they can review and delete entries.

**Explicit non-goals (deferred to a follow-up spec):**
- No network transmission of any kind. `reporter` is a stub that is never exercised by this build's UI.
- No GitHub-issue deep link / report action. That's the next spec once this lands.
- No opt-in/opt-out toggle — capture is local-only and always on, same trust posture as writing to a debug log, so there's nothing to consent to.
- No Drift migration — `SharedPrefsErrorBoxStorage` as shipped by the package is used unmodified.
- No auto-send / batching — the `sendOne`/`sendAll`/`markAsSent` surface of `ErrorPrivserver`'s static API is not used by this build (it exists in the package but nothing here calls it).

## 4. Components

### 4.1 `PocketCoderErrorCodeMapper` (new)

`lib/infrastructure/errors/error_code_mapper.dart`. A pure function `String mapError(Object error)` switching on `error.runtimeType` against the app's known domain exceptions (`AuthException`, `ChatException`, `ChatListException`, `PermissionException`, `AiException`, `ToolPermissionsException` — the same set `AppExceptionKeyMapper` already switches on) to short codes (`AUTH_001`, `CHAT_001`, ...), falling back to `'ERR_${error.runtimeType}'` for anything unmapped. No string-matching against `error.toString()` — unlike the package's own `ErrorCodeMapper.mapError` default, PocketCoder's exceptions are already type-only by construction (§2), so message-content heuristics would be dead code, not a safety net.

### 4.2 Bootstrap wiring (`bootstrap.dart`)

Replace `_configureErrorPrivserver()`'s body with a real `ErrorPrivserver.configure(...)` call:

```dart
ErrorPrivserver.configure(
  ErrorPrivserverConfig(
    storage: getIt<ErrorBoxStorage>(),
    reporter: (_) async => false, // no-op: reporting is out of scope, see §3
    errorCodeMapper: PocketCoderErrorCodeMapper.mapError,
    exceptionMapper: (error) => getIt<IExceptionKeyMapper>().map(error),
  ),
);
```

`ErrorBoxStorage` (the abstract type) is registered via a `@module`-style injectable provider returning `SharedPrefsErrorBoxStorage()`, so the inbox repository (§4.3) and this config share one instance. This call must run **after** `configureDependencies()` (already the case — `_configureErrorPrivserver()` is called at `bootstrap.dart:78`, after DI setup at line 46) so `getIt<IExceptionKeyMapper>()` resolves.

Also wrap `bootstrap.dart:61-69`'s existing catch body with an additional call:
```dart
await ErrorPrivserver.captureError(e, stack, source: 'Bootstrap.billingIdentify');
```
(requires capturing `stack` in that catch clause, which it doesn't currently do — `catch (e)` becomes `catch (e, stack)`).

### 4.3 `ErrorBoxRepository` (new, thin wrapper)

`lib/infrastructure/errors/error_box_repository.dart`, `@lazySingleton`, wraps the injected `ErrorBoxStorage` so `ErrorsCubit` depends on an app-owned repository interface rather than calling the package's static `ErrorPrivserver` API directly — consistent with the rest of the codebase's repository pattern (e.g. `chat_list_repository.dart`, `healthcheck_repository.dart`). Exposes: `Future<List<ErrorBoxEntry>> getAll()`, `Future<void> delete(String id)`, `Future<void> deleteAll()`. (No `markAsSent`/`sendOne` surface — not needed since there's no send path.)

### 4.4 `ErrorsCubit` / `ErrorsState` (new)

`lib/application/errors/errors_cubit.dart`, `@injectable`, extends `AppCubit<ErrorsState>`. `ErrorsState` is a `@freezed` class with `List<ErrorBoxEntry> entries` alongside the required `UiFlowStatus status` / `Object? error` (per `client/CLAUDE.md`'s state-management rules). Methods: `load()`, `deleteError(String id)`, `deleteAll()` — each via `tryOperation`, same shape as every other cubit in the app.

### 4.5 Error Inbox screen (new)

`lib/presentation/errors/error_inbox_screen.dart`. A list of captured errors (source, error type, code, occurrence count, last-occurred timestamp), tap-to-expand for the full stack trace, swipe-or-button delete per entry, and a "Clear all" action. Empty state: "No errors captured" (localized `MessageKey`, per `client/CLAUDE.md`'s no-hardcoded-strings rule).

### 4.6 Settings entry point

One new row in `settings_screen.dart`, alongside the existing MCP/scheduler/skills/tool-permissions/agent-config/notification rows, navigating to the inbox screen via the existing GoRouter setup.

## 5. Data flow

- **Cubit-originated errors (the common case):** any cubit's `tryOperation` catches → `ErrorPrivserverMixin._captureError` (already wired, just previously inert) → `ErrorBoxStorage.saveError` → fingerprint-deduped entry in the shared-prefs blob. No new code on this path — it starts working the moment §4.2's `configure()` call lands.
- **Bootstrap-originated errors:** explicit `ErrorPrivserver.captureError(...)` call at the one identified swallow site (§4.2), same storage.
- **Inbox screen:** `ErrorsCubit.load()` → `ErrorBoxRepository.getAll()` → `ErrorBoxStorage.getUnsentErrors()` (the storage's only "list" method; "unsent" is the package's own naming, not meaningful here since nothing is ever sent — every captured entry is always in this list until deleted).

## 6. Privacy

Nothing new to design here — carried, not invented. `SafeExceptionCause` (§2) already guarantees no PII reaches `tryOperation`'s catch clause, so the inbox is safe to render unredacted. The one thing to verify at implementation time: confirm no call site anywhere passes a raw, non-`tryMethod`-wrapped exception into a cubit's `tryOperation` in a way that could carry a raw message (e.g. a third-party package throwing directly) — if any exist, note them but do not block this spec on fixing them; capture is still strictly better than the current silent-drop behavior even if one or two entries end up less clean than the common case.

## 7. Testing

- Unit test `PocketCoderErrorCodeMapper.mapError` against each known exception type plus an unmapped fallback case.
- Unit test `ErrorsCubit` (`load`/`deleteError`/`deleteAll`) against a fake `ErrorBoxRepository`.
- Widget test for `error_inbox_screen.dart`: populated list, empty state, delete interaction.
- Manual: force a real cubit failure (e.g. toggle airplane mode mid-request), confirm the entry appears in Settings → Error Reports, persists across app restart (proves `SharedPreferences` persistence), and that occurrence count increments on repeat.
