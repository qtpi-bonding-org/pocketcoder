# Reviewer-Bypass Mechanism — Design

> **SUPERSEDED, not implemented.** Replaced by a much simpler operational
> approach: a dedicated real Linode account with a spend-capped virtual
> card, real credentials handed to reviewers via App Store Connect's
> "Notes for Review" field, real (unmodified) OAuth login — no bypass
> code, no Worker route, no PAT-vending, no sentinel email, at all. See
> sub-project 3 in `2026-08-02-apple-review-linode-access-overview.md`
> for the current design. This document is kept only for the reasoning
> trail (why the bypass approach was considered and what its actual risks
> were) — do not implement anything below.

> Sub-project 3 of `2026-08-02-apple-review-linode-access-overview.md`.
> Depends on sub-project 1+2
> (`2026-08-02-deploy-entry-point-and-admin-credentials-design.md`), which
> is already implemented — the DEPLOY-mode Email field this spec keys off
> of already exists and is already a plain, unrestricted text field.

**Goal:** Let Apple App Review reviewers and Shipaton judges complete the
real "deploy your own server" flow — including the Linode step — without
needing their own Linode account or incurring real third-party charges,
while keeping the mechanism narrowly scoped and disclosed rather than a
genuinely hidden feature.

**Architecture:** A single hardcoded, hashed sentinel email is checked
client-side when the reviewer taps "LOGIN VIA LINODE" on `AuthScreen`. On
match, the app calls a new password-gated Cloudflare Worker route instead
of running the real Linode OAuth flow. The Worker verifies the password
against a stored hash and, on success, returns a Linode Personal Access
Token scoped to `Linodes:Read/Write` only, on a **dedicated Linode account
that holds no real infrastructure**. The app preseeds that token into
secure storage exactly where a real OAuth token would go, then proceeds
through the existing post-auth flow unchanged. Client-side cost caps
prevent runaway spend once the bypass is active. The whole mechanism ships
in the normal production app — there is no separate reviewer build.

**Tech Stack:** Flutter/Dart (`pocketcoder_pro`, `flutter_aeroform`'s
existing `ISecureStorage`/`IOAuthService` contracts), Cloudflare Workers
(`workers/oauth-relay`, already deployed — this adds one route to it),
Web Crypto (`crypto.subtle.digest`) for server-side password hashing.

## Global Constraints

- No separate build, build flag, or `--dart-define` secret. The bypass
  code path ships in the same binary every user gets; it stays inert for
  everyone who never types the sentinel email.
- The sentinel email is a SHA-256 hash of a normalized (trimmed,
  lowercased) email string, hardcoded client-side — never plaintext in the
  client. The password is never present in the client at all, in any form.
- The password is a 20+ character random string, generated once and
  handed to reviewers only via App Store Connect's "Notes for Review"
  field. It is never memorized or typed from memory — always copy-pasted.
- **The vended PAT lives on a dedicated Linode account created solely for
  this purpose, holding no other real infrastructure.** `Linodes:Read/Write`
  is account-wide — it lets its holder list, create, resize, or delete
  *any* Linode on the token's account, not just ones it created itself.
  Client-side cost caps (below) only constrain usage that goes through
  this app's UI; a holder of the raw PAT calling Linode's API directly
  isn't bound by them. Putting the PAT on an account with nothing else on
  it is what actually bounds the blast radius of a leaked/brute-forced
  token — no plan-type or label filtering on the client side is a
  substitute for this. This account is created once (not per review
  cycle) and never accumulates real infrastructure.
- The preseeded token must never cause `LinodeOAuthService.refreshToken()`
  to fire automatically. This holds as long as `storeTokenExpiration` is
  never called for the bypass path — `getAccessToken()`
  (`flutter_aeroform/lib/infrastructure/auth/linode_oauth_service.dart:167-181`)
  only calls `refreshToken()` when `getTokenExpiration()` returns non-null.
  Once the PAT is revoked post-review, the stored token becomes permanently
  dead (every Linode call 401s, with no refresh path) until the user logs
  out — acceptable since this only ever applies to the reviewer's own
  session, never a real user's.
- This mechanism must be explicitly disclosed in App Store Connect's
  "Notes for Review" field at submission time — this is what keeps it a
  sanctioned demo mode (Guideline 2.1) rather than an undisclosed hidden
  feature (Guideline 2.3.1). Out of scope for implementation tasks, but a
  hard requirement before ever submitting a build that includes this code.
- The vended PAT is scoped to `Linodes:Read/Write` only — confirmed
  sufficient (no `Images:Read` needed) via the earlier live scope test
  documented in `LINODE_REVIEWER_ACCESS_TODO.md`.
- The real `LINODE_REVIEWER_PAT` value only exists in the vault for the
  duration of an actual review/judging window — generated shortly before
  submission, revoked in Linode's dashboard shortly after. This is an
  operational step, not something any task below implements in code.
- IAP/paywall interaction is out of scope for this spec.
  `DeployPickerScreen` gates on `billing.hasDeployAccess()`
  (`deploy_picker_screen.dart:146`). Official Apple App Review devices run
  IAP against Apple's StoreKit sandbox automatically, so real App Review
  should already pass this gate with no charge — no dart-define or
  `USE_TEST_STORE` flag needed for that path. Shipaton judges installing
  the live public build would hit a real purchase; resolving that is a
  separate, already-tracked concern, not part of this spec.
- This spec **supersedes and obsoletes** the build-time approach recorded
  earlier in `LINODE_REVIEWER_ACCESS_TODO.md` (`scripts/build-reviewer-ipa.sh`,
  the `build_pocketcoder_reviewer_ipa` daemon action, and
  `secrets/linode-reviewer-build.enc.yaml`). The PAT now lives only in
  `secrets/oauth-relay.enc.yaml` (see Component 4) and is fetched at
  runtime, not baked in at build time. Task 6 below removes the obsolete
  script; the obsolete action and secrets file are the user's own vault
  cleanup (per the secrets-daemon skill), not an implementation task.

---

## Components

### 1. Fix the Worker base URL (`client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart`)

**This must land before Component 3 can work at all.**
`external_module.dart:113-116` currently registers `@Named('mcpOAuthRelayBaseUrl')`
as `https://pocketcoder-oauth-relay.workers.dev`, still carrying a
`TODO(mcp-oauth): replace with the real deployed Worker's...` comment. The
actually-deployed Worker lives at
`https://pocketcoder-oauth-relay.gp-c53.workers.dev` (Cloudflare's free
`workers.dev` routing includes the account subdomain) — recorded as the
"THIRD CORRECTION" in `LINODE_REVIEWER_ACCESS_TODO.md`. Update the constant
to the real URL and remove the stale TODO comment. Without this fix, every
call in Component 3 fails with the same generic network-failure message a
wrong password would produce — indistinguishable, and undiagnosable from
inside the app.

### 2. Sentinel check (`client/packages/pocketcoder_pro/lib/presentation/auth/reviewer_bypass.dart`, new file)

A small, isolated file — deliberately separate from `auth_screen.dart` so
the whole mechanism can be deleted in one file removal plus a few call-site
reverts if it's ever decommissioned.

```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// SHA-256 of the normalized (trimmed, lowercased) reviewer sentinel
/// email. The plaintext value is never stored in this repo — only its
/// hash, generated once and handed to Apple/Shipaton via App Store
/// Connect's "Notes for Review" field.
const String kReviewerSentinelEmailHash = '<sha256 hex, filled in at setup time>';

bool isReviewerSentinelEmail(String? email) {
  if (email == null) return false;
  final normalized = email.trim().toLowerCase();
  final hash = sha256.convert(utf8.encode(normalized)).toString();
  return hash == kReviewerSentinelEmailHash;
}
```

`isReviewerSentinelEmail` takes a nullable `String?` directly (rather than
callers doing `credentials != null && isReviewerSentinelEmail(credentials!.email)`)
specifically so call sites never need the `!` operator, which
`client/CLAUDE.md` forbids outright.

`crypto` is **not currently a direct dependency of `pocketcoder_pro`**
(confirmed against its `pubspec.yaml`) — add it there. It's already a
transitive dependency via `flutter_aeroform` (used for PKCE in
`LinodeOAuthService`), so this only adds a `pubspec.yaml` line, no new
package to vet.

### 3. `AuthScreen` / `AuthCubit` (`client/packages/pocketcoder_pro/lib/presentation/auth/auth_screen.dart`, `lib/application/auth/auth_cubit.dart`)

`_AuthView`'s "LOGIN VIA LINODE" `TerminalAction.onTap` becomes:

```dart
onTap: state.isLoading
    ? () {}
    : () => isReviewerSentinelEmail(credentials?.email)
        ? authCubit.reviewerBypass(credentials?.password ?? '')
        : authCubit.authenticate(),
```

`AuthCubit` gains a new constructor dependency,
`IReviewerBypassClient _reviewerBypassClient` (see Component 4), and a new
method:

```dart
Future<void> reviewerBypass(String password) async {
  return tryOperation(() async {
    final pat = await _reviewerBypassClient.exchangePassword(password);

    await _secureStorage.storeAccessToken(pat);
    // Deliberately no storeRefreshToken / storeTokenExpiration call —
    // see Global Constraints: this is what keeps refreshToken() from
    // ever firing against a token that has none.

    // Scopes intentionally omit 'linodes:create' / 'images:read_write' —
    // this token only ever needs Linodes:Read/Write (confirmed via the
    // live scope test in LINODE_REVIEWER_ACCESS_TODO.md). validateScopes()
    // is never actually called anywhere in either repo today, so this has
    // no runtime effect, but keep it accurate for future readers.
    return state.copyWith(
      status: UiFlowStatus.success,
      token: OAuthToken(
        accessToken: pat,
        refreshToken: '',
        expiresAt: DateTime.now().add(const Duration(days: 365)),
        scopes: const ['linodes:read_write'],
      ),
      isAuthenticated: true,
    );
  }, emitLoading: true);
}
```

The existing `BlocListener` in `_AuthView` already navigates to
`RouteNames.config` on `state.isSuccess && state.isAuthenticated == true` —
unchanged, since this emits the same shape of success state the real path
does.

On failure (`ReviewerBypassException`, wrong password), `tryOperation`
already produces the existing generic failure state/messaging — no new
error-handling code needed, and no distinct message that would hint at
what failed.

### 4. `IReviewerBypassClient` / `ReviewerBypassClient` (`client/packages/pocketcoder_pro/lib/domain/auth/i_reviewer_bypass_client.dart`, `lib/infrastructure/auth/reviewer_bypass_client.dart`, new files)

```dart
abstract class IReviewerBypassClient {
  /// Exchanges the reviewer password for a scoped Linode PAT via the
  /// Worker. Throws [ReviewerBypassException] on any non-200 response.
  Future<String> exchangePassword(String password);
}

class ReviewerBypassException implements Exception {
  final String message;
  ReviewerBypassException(this.message);
}
```

Implementation follows the same shape as
`pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart`'s
`http.Client` + `@Named` base-URL-injection pattern — reuses the same
`mcpOAuthRelayBaseUrl` DI binding registered in `external_module.dart`
(fixed in Component 1), since the Worker route lives on the same
`oauth-relay` deployment:

```dart
class ReviewerBypassClient implements IReviewerBypassClient {
  final http.Client _httpClient;
  final String _relayBaseUrl;

  ReviewerBypassClient(this._httpClient, this._relayBaseUrl);

  @override
  Future<String> exchangePassword(String password) async {
    final resp = await _httpClient.post(
      Uri.parse('$_relayBaseUrl/reviewer/linode-token'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'password': password}),
    );
    if (resp.statusCode != 200) {
      throw ReviewerBypassException('reviewer bypass failed: ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final token = body['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw ReviewerBypassException('missing access_token in response');
    }
    return token;
  }
}
```

**DI wiring** — `pocketcoder_pro` has no `injectable` code generation;
`AuthCubit`/`ConfigCubit`/`DeploymentCubit` are all hand-registered in
`initializeAeroformDI()` at `client/packages/pocketcoder_pro/lib/app.dart:415`.
The `@LazySingleton` annotation pattern from other components in this repo
does not apply here — register manually instead:

```dart
getIt.registerLazySingleton<IReviewerBypassClient>(
  () => ReviewerBypassClient(getIt<http.Client>(), getIt<String>(instanceName: 'mcpOAuthRelayBaseUrl')),
);
```

placed alongside `pocketcoder_pro`'s other manual registrations in
`initializeAeroformDI()`, and the existing `AuthCubit` factory registration
in the same function must be updated to pass the new third constructor
argument. The `mcpOAuthRelayBaseUrl` binding is registered in
`pocketcoder_flutter`'s `ExternalModule` and is reachable from the shared
`GetIt.instance` as long as `bootstrap()` has already run — true for every
real app entry point, so no ordering change needed.

### 5. Worker route (`workers/oauth-relay/src/index.js`)

New route, `POST /reviewer/linode-token`:

- Body: `{"password": "<string>"}`.
- Hash the incoming password with `crypto.subtle.digest('SHA-256', ...)`,
  hex-encode it, and compare against the `REVIEWER_TOKEN_PASSWORD_HASH`
  secret using a constant-time comparison (XOR every byte and OR the
  results together, rather than an early-exit `===`/`.every()` loop — this
  Worker has no `crypto.timingSafeEqual` equivalent built in).
- Match → `200 {"access_token": "<LINODE_REVIEWER_PAT>"}`.
- No match → `401`, generic `{"error": "unauthorized"}` body — nothing
  that would help distinguish "wrong password" from "unknown route" or
  reveal anything about the check.
- Add a Cloudflare Rate Limiting rule scoped to this route (dashboard or
  `wrangler.toml` binding — whichever this Worker's existing rules, if
  any, already use as precedent) capping it to a small number of requests
  per minute per IP. This is configuration, not application code, and
  costs nothing to include.

Both `REVIEWER_TOKEN_PASSWORD_HASH` and `LINODE_REVIEWER_PAT` are new keys
in the existing `secrets/oauth-relay.enc.yaml` vault file — no new
`actions.json` entry needed, since `set_mcp_oauth_relay_secrets` and
`deploy_mcp_oauth_relay` already cover this file. This is a vault-editing
step for the user to do themselves (per the secrets-daemon skill), not an
implementation task below.

### 6. Delete obsolete build-time scaffolding (`scripts/build-reviewer-ipa.sh`)

Delete this script — it's superseded by Component 5's runtime approach
(see Global Constraints). It is a plain repo file (not a secret), safe to
remove directly. Leave a one-line note in the commit message pointing at
this spec, since the corresponding `secrets/linode-reviewer-build.enc.yaml`
vault file and `build_pocketcoder_reviewer_ipa` daemon action are the
user's own cleanup to do (never touch `actions.json` or vault files
directly).

### 7. Cost caps (`client/packages/pocketcoder_pro/lib/presentation/deployment/config_screen.dart`, `lib/application/deployment/deployment_cubit.dart`)

**Plan lock (`config_screen.dart`)**: `ConfigScreen` already receives
`DeployCredentials? credentials` (sub-project 1+2). It gains a derived
`bool get _isReviewerMode => isReviewerSentinelEmail(credentials?.email);`.
When true, the plan picker only renders/allows `g6-nanode-1` — no other
plan is selectable, regardless of what `loadPlansAndRegions()` returns.
This part is pure rendering logic already in scope of `_ConfigViewState`,
no new dependencies needed.

**Instance cap (`deployment_cubit.dart`)**: `ConfigScreen` has no
`IDeploymentService` in scope (only `ConfigCubit` and `DeploymentCubit`),
so the cap check belongs inside `DeploymentCubit.deploy()`, which already
holds `_deploymentService`, not inside `ConfigScreen`. `deploy()` gains a
new required parameter:

```dart
Future<void> deploy(
  DeploymentConfig config, {
  required String adminPassword,
  bool isReviewerMode = false,
}) async {
  return tryOperation(() async {
    if (isReviewerMode) {
      final existing = await _deploymentService.getExistingInstances();
      if (existing.length >= 3) {
        throw DeploymentValidationException(
          'Reviewer mode instance cap reached (3 instances already exist)',
        );
      }
    }

    // ...existing validateConfig / deploy(...) body, unchanged...
  }, emitLoading: true);
}
```

`getExistingInstances()` (`flutter_aeroform/lib/infrastructure/deployment/deployment_service.dart:238-250`)
already filters to this app's own PocketCoder-labeled instances — it does
not see unrelated infrastructure on the account at all. Combined with the
dedicated reviewer-only Linode account (Global Constraints), there is no
"real infra on this account" scenario left to filter around, so the cap is
a plain count with no plan-type filtering: **3 existing PocketCoder-labeled
instances blocks a 4th**, full stop. (An earlier draft of this cap filtered
by `planType == 'g6-nanode-1'` to protect hypothetical unrelated
infrastructure on a shared account — moot now that the account is
dedicated, and the label filter already made that filtering unnecessary
even before that change.)

`ConfigScreen._deploy()` passes `isReviewerMode: _isReviewerMode` through
to `deploymentCubit.deploy(...)`.

**Surfacing the failure**: `ConfigScreen`'s `UiFlowListener` currently
wraps only `ConfigCubit` (`config_screen.dart:36`) — `DeploymentCubit`
failures, including this new one, are not currently shown to the user at
all (a pre-existing gap: even a real `DeploymentValidationException` today
produces no visible feedback). Wrap `DeploymentCubit` in a nested
`UiFlowListener<DeploymentCubit, DeploymentState>` alongside the existing
one so this (and any other `DeploymentCubit` failure) surfaces as the
same automatic toast/error feedback `cubit_ui_flow` already provides
elsewhere in this app. This is required infrastructure for the reviewer
cap to be visible at all, not optional polish.

No new methods needed on `IDeploymentService` — `getExistingInstances()`
already exists and already does exactly what's needed.

---

## Error Handling

- Wrong password at the Worker: `401`, generic body, surfaces through
  `AuthCubit`'s existing failure-state path with the same generic message
  a real OAuth failure would show. Never reveals that a bypass path exists
  or was attempted.
- Network failure calling the Worker (including if Component 1's URL fix
  were somehow wrong): same `tryOperation` failure path, same generic
  messaging — no special-casing needed.
- Reviewer mode + instance cap hit: `DeploymentValidationException`
  through `DeploymentCubit`'s existing `tryOperation` failure path,
  surfaced via the `UiFlowListener` wiring added in Component 7 — same
  treatment as any other deployment validation failure, not a bespoke
  error UI.

## Testing

- `reviewer_bypass_test.dart` (new file): `isReviewerSentinelEmail` returns
  true for the exact sentinel (any case, with surrounding whitespace) and
  false for near-misses (test a deliberately *wrong* email hashes
  differently, not that case-sensitivity breaks it), `null`, and empty
  string.
- `auth_cubit_test.dart` (existing file, new test group): tests for
  `reviewerBypass()` — success path stores only the access token (mock
  `ISecureStorage`, assert `storeRefreshToken`/`storeTokenExpiration` are
  never called), emits `isAuthenticated: true`; failure path (mock client
  throws `ReviewerBypassException`) emits the existing failure state.
- `reviewer_bypass_client_test.dart` (new file): mocked `http.Client`,
  asserts the request body shape, 200/401 handling, and the
  missing-`access_token` edge case.
- `deployment_cubit_test.dart` (existing file, new test group): `deploy()`
  with `isReviewerMode: true` and a mocked `getExistingInstances()`
  returning 3+ instances throws `DeploymentValidationException` without
  calling `_deploymentService.deploy(...)`; the same call with fewer than
  3 existing instances proceeds normally. `isReviewerMode: false` (the
  default) skips the check entirely regardless of instance count —
  existing behavior for real users is unaffected.
- `config_screen_test.dart` (new file — no widget tests exist yet for this
  screen, so this stands up new scaffolding, not an addition to an
  existing suite): reviewer-mode credentials lock the plan picker to
  `g6-nanode-1`; non-reviewer credentials leave the existing plan picker
  behavior untouched.

No integration test drives the real Worker route or a real Linode
account — that's exercised manually, once, before each actual submission
(see Global Constraints on the vault lifecycle).
