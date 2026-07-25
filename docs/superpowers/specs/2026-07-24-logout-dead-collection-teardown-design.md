# Logout + Dead Collection Teardown — Design

## 1. Why this exists

Two unrelated but small, mechanical gaps, bundled into one spec because both are cheap:

**a) No logout.** `IAuthRepository.logout()` (`lib/infrastructure/auth/auth_repository.dart:51-54`) has existed since the auth system was built, but nothing in the app calls it. There is no way to sign out of PocketCoder short of reinstalling the app or clearing secure storage.

**b) Five dead PocketBase collections.** A multi-agent wiring audit (`audit/pb-flutter-wiring/`, gitignored) traced every PocketBase collection against Goose, the MCP gateway, cognee, and PocketBase's own backend hooks — not just Flutter UI wiring. Five collections have **zero consumers anywhere** in the live system:

| Collection | Verdict | Evidence |
|---|---|---|
| `proposals` | Write-only, human-only, zero Goose integration | `audit/pb-flutter-wiring/04-sop-goose-wiring.md` |
| `sops` | Sealed by a PocketBase hook on proposal approval, but nothing ever reads the sealed content back — not into agent prompts, not into anything | `audit/pb-flutter-wiring/05-sop-consumption.md` |
| `questions` | Elicitation is handled entirely in-memory via the ACP coordinator; never persisted here | `audit/pb-flutter-wiring/06-questions-harness_auth-notifications-sandbox_configs.md` |
| `harness_auth` | Planned for OAuth/credential storage, never implemented — no DAO, no backend reader/writer | same file |
| `sandbox_configs` | Not in Goose's config-pipeline watched collections (`goose_config.go`'s watch list), no DAO, no UI | same file |

Each of these five has a Flutter `@freezed` model (generated, unused) and a schema entry, but no DAO, no repository, no cubit, and no screen — except `proposals`/`sops`, which have a full (but pointless) data layer: `SopCubit`, `SopDao`/`ProposalDao`, `EvolutionRepository`, and a hardcoded-data `SopManagementScreen` (`lib/presentation/sop/sop_management_screen.dart`) that was never actually bound to that data layer.

**Explicitly kept** (confirmed live, or deliberately dormant/speculative rather than dead — see audit files 06-09 for full evidence):
- `healthchecks`, `ssh_keys`, `sandbox_agents` — no live backend writer today, but kept as speculative/dormant infrastructure (matches existing "preserved for a future Goose tool" precedent in `docs/pruning-audit/00-SUMMARY.md`).
- `harnesses` — backend's Goose config builder bypasses its FK relation (uses a denormalized `harness_model_id` field instead), but the collection itself is live catalog data actively rendering `provider_screen.dart`'s harness/CLI picker. Not a teardown candidate.
- Everything else in the original 22-collection audit (`chats`, `mcp_servers`, `poco_configs`, `prompts`, `provider_keys`, `models`, `harness_models`, `tool_permissions`, `devices`, `notification_rules`, `goose_sessions`, `schedule_owners`, `cognee_config`, `users`) — confirmed live.

## 2. Scope

### 2a. Logout

Add `AuthCubit.logout()`, wire it to a new "ACCOUNT" section in Settings with a confirm dialog, redirect to onboarding on success.

### 2b. Full teardown: `proposals`, `sops`, `questions`, `harness_auth`, `sandbox_configs`

Remove every trace — schema, backend hook, Flutter models/DAOs/repository/cubit/screen/route/settings entry/ARB keys — and regenerate via the Model Generation Pipeline (root `CLAUDE.md`).

Out of scope: `healthchecks`, `ssh_keys`, `sandbox_agents`, `harnesses` (all explicitly kept, see §1).

## 3. Architecture

### 3.1 Logout

**`AuthCubit.logout()`** (`lib/application/system/auth_cubit.dart`) — mirrors the existing `login()` method exactly:

```dart
Future<void> logout() async {
  return tryOperation(() async {
    await _authRepository.logout();
    return createSuccessState();
  });
}
```

No new exception type needed — `_authRepository.logout()` (`auth_repository.dart:51-54`) just clears the auth store and secure storage; it doesn't throw in normal operation, and `tryOperation` already handles the unexpected-error path generically.

**Settings UI** (`lib/presentation/settings/settings_screen.dart`) — add a new section to `_sections()`:

```dart
(context.l10n.settingsAccountSection, [
  ('LOGOUT', '[SIGN OUT]', 'logout'),
]),
```

`SettingsScreen` becomes a `StatelessWidget` wrapped in `BlocProvider(create: (_) => getIt<AuthCubit>())` (it currently has no cubit provider of its own — only consumes `McpCubit` from an ancestor). Wrap the existing `BlocBuilder<McpCubit, McpState>` body in `UiFlowListener<AuthCubit, AuthState>`, matching the pattern already used in `onboarding_screen.dart`:

```dart
UiFlowListener<AuthCubit, AuthState>(
  onSuccess: (context, state) {
    if (context.mounted) context.goNamed(RouteNames.onboarding);
  },
  child: BlocBuilder<McpCubit, McpState>(...),
)
```

Tapping the LOGOUT tile opens a `TerminalDialog` confirm, matching the archive/delete confirm pattern already established in `lib/presentation/chat/chat_list_screen.dart:113-130`:

```dart
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
          context.read<AuthCubit>().logout();
        },
        child: Text(context.l10n.settingsLogoutConfirm),
      ),
    ],
  ),
);
```

New ARB keys (dot-notation source → camelCase generated, per `client/CLAUDE.md`): `settings.account_section` → `settingsAccountSection`, `settings.logout_confirm_title` → `settingsLogoutConfirmTitle`, `settings.logout_confirm_body` → `settingsLogoutConfirmBody`, `settings.logout_cancel` → `settingsLogoutCancel`, `settings.logout_confirm` → `settingsLogoutConfirm`.

### 3.2 Dead collection teardown

**Backend (`services/pocketbase/`):**
- `pb_migrations/schema.json` — remove the `proposals`, `sops`, `questions`, `harness_auth`, `sandbox_configs` collection definitions entirely (including their indexes).
- Delete `internal/hooks/sops.go` (the `RegisterSopHooks`/`SealProposal` functions — both become unreachable once `proposals`/`sops` don't exist).
- `main.go:58` — remove the `hooks.RegisterSopHooks(app)` call site.
- Run the Model Generation Pipeline (root `CLAUDE.md`): `docker compose build pocketbase goose` → `docker compose up -d pocketbase goose` → `scripts/export_schema.sh` → `python3 scripts/generate_models.py` (from `client/packages/pocketcoder_flutter`) → `dart run build_runner build --delete-conflicting-outputs`. The generate step will itself delete the now-orphaned `question.dart`/`harness_auth.dart`/`sandbox_config.dart`/`proposal.dart`/`sop.dart` models (and their `.g.dart`/`.freezed.dart`) since it regenerates from the new schema — confirm this in Task order rather than hand-deleting them first, to avoid the generator recreating stale files from a cached schema.

**Flutter (`client/packages/pocketcoder_flutter/`), hand-deleted (not model-generator output):**
- `lib/presentation/sop/sop_management_screen.dart`
- `lib/application/sop/sop_cubit.dart`, `sop_state.dart` (+ generated `sop_state.freezed.dart`)
- `lib/domain/evolution/i_evolution_repository.dart`
- `lib/infrastructure/evolution/evolution_repository.dart`, `evolution_daos.dart` (`ProposalDao`, `SopDao`)
- `lib/domain/exceptions/sop_exception.dart`
- `lib/domain/models/collections.dart` — remove `proposals`, `sops`, `questions`, `harnessAuth`, `sandboxConfigs` entries (both the constant and the enum-list entry) — though this file gets regenerated by `generate_models.py`, so this may be automatic; verify.

**Routing/Settings:**
- `lib/app_router.dart` — remove the `SopManagementScreen` import, the `/sop` legacy redirect (line 48), the `GoRoute` at `AppRoutes.configureSop` (lines 160-167), and the `configureSop`/`sopManagement` route constants (lines 245, 256, 287, 297).
- `lib/presentation/settings/settings_screen.dart` — remove the `('SOP MANAGEMENT', ...)` tile and its `case 'configureSop':` navigation branch.
- `lib/l10n/app_en.arb` — remove `sopTitle`, `sopProjectProcedures`, `sopNewProposal`, `sopActiveProcedures`, `sopDraftProposals`, `sopPendingSignature` (lines 387-392).

No `AppExceptionKeyMapper` changes needed — `SOPException` was never registered there (confirmed: zero matches for `Sop`/`Evolution` in `exception_mapper.dart`), so there's nothing to remove on that front.

## 4. Data flow

**Logout:** user taps LOGOUT → confirm dialog → `AuthCubit.logout()` → `tryOperation` sets loading → `IAuthRepository.logout()` clears `PocketBase.authStore` + secure storage → `AuthState.status = success` → `UiFlowListener.onSuccess` fires → `context.goNamed(RouteNames.onboarding)`. No drift cache invalidation needed — the local drift cache is keyed by collection, not by auth session, and the next login re-authenticates against the same cached-then-revalidated data (matching how `refreshToken()` already works in `boot_screen.dart`).

**Teardown:** no runtime data flow — this is deletion. The one behavior change: a `proposals.status` update to `"approved"` no longer triggers `SealProposal`, but since the collection itself is gone, this is moot (the collection can't exist to be updated).

## 5. Error handling

Logout failure (e.g. secure storage write fails) surfaces via `AuthState.error` → the existing `UiFlowListener` error-toast path already wired for `AuthCubit` (same mechanism `login()` failures already use) — no new exception-mapper case needed since `AuthCubit` doesn't throw a typed exception, it just sets `state.error` directly (matching `login()`'s existing `throw 'ACCESS DENIED...'` string-based pattern).

## 6. Testing

- `auth_cubit_test.dart` (extend existing file): `logout()` calls `_authRepository.logout()` once and emits `status: success`; `logout()` failure (repository throws) emits `status: failure` with `error` set.
- `settings_screen_test.dart` (new or extend if one exists): tapping LOGOUT opens a `TerminalDialog`; tapping confirm calls `AuthCubit.logout()`; tapping cancel does not.
- Teardown has no new test surface (pure deletion) — verification is: `flutter analyze` clean, `dart run build_runner build` clean, `go build ./... && go vet ./...` clean, existing test suite green (no test currently references the five deleted collections' DAOs/cubits/screens — verify via grep before deleting, not after).

## 7. Out of scope

- `healthchecks`, `ssh_keys`, `sandbox_agents`, `harnesses` — explicitly kept, no changes.
- Any new settings feature beyond logout (server-URL change, account management) — not addressed here.
- Re-implementing SOP governance with real agent consumption (e.g. injecting sealed SOPs into system prompts) — if this becomes wanted later, it's a new feature spec, not a revival of the deleted code.
