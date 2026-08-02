# Reviewer-Bypass Mechanism — Design

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
Token scoped to `Linodes:Read/Write` only. The app preseeds that token into
secure storage exactly where a real OAuth token would go, then proceeds
through the existing post-auth flow unchanged. Client-side cost caps
prevent runaway spend once the bypass is active. The whole mechanism ships
in the normal production app — there is no separate reviewer build.

**Tech Stack:** Flutter/Dart (`pocketcoder_pro`, `flutter_aeroform`'s
existing `ISecureStorage`/`IOAuthService` contracts), Cloudflare Workers
(`workers/mcp-oauth-relay`, already deployed — this adds one route to it),
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
- The preseeded token must never cause `LinodeOAuthService.refreshToken()`
  to fire automatically. This holds as long as `storeTokenExpiration` is
  never called for the bypass path — `getAccessToken()`
  (`flutter_aeroform/lib/infrastructure/auth/linode_oauth_service.dart:167-181`)
  only calls `refreshToken()` when `getTokenExpiration()` returns non-null.
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

---

## Components

### 1. Sentinel check (`packages/pocketcoder_pro/lib/presentation/auth/reviewer_bypass.dart`, new file)

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

bool isReviewerSentinelEmail(String email) {
  final normalized = email.trim().toLowerCase();
  final hash = sha256.convert(utf8.encode(normalized)).toString();
  return hash == kReviewerSentinelEmailHash;
}
```

`crypto` is already a transitive dependency (used by `flutter_aeroform`'s
`LinodeOAuthService` for PKCE) — confirm it's a direct dependency of
`pocketcoder_pro` too before importing it there.

### 2. `AuthScreen` / `AuthCubit` (`packages/pocketcoder_pro/lib/presentation/auth/auth_screen.dart`, `lib/application/auth/auth_cubit.dart`)

`_AuthView`'s "LOGIN VIA LINODE" `TerminalAction.onTap` becomes:

```dart
onTap: state.isLoading
    ? () {}
    : () => (credentials != null && isReviewerSentinelEmail(credentials!.email))
        ? authCubit.reviewerBypass(credentials!.password)
        : authCubit.authenticate(),
```

`AuthCubit` gains:

```dart
Future<void> reviewerBypass(String password) async {
  return tryOperation(() async {
    final pat = await _reviewerBypassClient.exchangePassword(password);

    await _secureStorage.storeAccessToken(pat);
    // Deliberately no storeRefreshToken / storeTokenExpiration call —
    // see Global Constraints: this is what keeps refreshToken() from
    // ever firing against a token that has none.

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

`AuthCubit`'s constructor gains one new dependency,
`IReviewerBypassClient _reviewerBypassClient` (see Component 3).

### 3. `IReviewerBypassClient` / `ReviewerBypassClient` (`packages/pocketcoder_pro/lib/domain/auth/i_reviewer_bypass_client.dart`, `lib/infrastructure/auth/reviewer_bypass_client.dart`, new files)

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
`mcpOAuthRelayBaseUrl` DI binding already registered in
`external_module.dart` (the Worker route lives on the same
`mcp-oauth-relay` deployment):

```dart
@LazySingleton(as: IReviewerBypassClient)
class ReviewerBypassClient implements IReviewerBypassClient {
  final http.Client _httpClient;
  final String _relayBaseUrl;

  ReviewerBypassClient(
    this._httpClient,
    @Named('mcpOAuthRelayBaseUrl') this._relayBaseUrl,
  );

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

### 4. Worker route (`workers/mcp-oauth-relay/src/index.js`)

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
in the existing `secrets/mcp-oauth-relay.enc.yaml` vault file — no new
`actions.json` entry needed, since `set_mcp_oauth_relay_secrets` and
`deploy_mcp_oauth_relay` already cover this file. This is a vault-editing
step for the user to do themselves (per the secrets-daemon skill), not an
implementation task below.

### 5. Cost caps (`packages/pocketcoder_pro/lib/presentation/deployment/config_screen.dart`, `lib/application/deployment/deployment_cubit.dart`)

`ConfigScreen` already receives `DeployCredentials? credentials`
(sub-project 1+2). It gains a derived `bool get _isReviewerMode =>
credentials != null && isReviewerSentinelEmail(credentials!.email);`.

When `_isReviewerMode` is true:

- The plan picker only renders/allows `g6-nanode-1` — no other plan is
  selectable, regardless of what `loadPlansAndRegions()` returns.
- Before calling `deploymentCubit.deploy(...)`, call
  `deploymentService.getExistingInstances()` (already exposed via
  `IDeploymentService`, `flutter_aeroform/lib/domain/deployment/i_deployment_service.dart:20`),
  filter to instances where `planType == 'g6-nanode-1'`, and block the
  deploy with an inline error if that filtered count is already ≥ 3. The
  cap counts cheap-tier instances only, not the account's total instance
  count — the reviewer PAT's own Linode account may carry real,
  unrelated infrastructure on larger plans, and that must not count
  against or be affected by this cap. This check only runs in reviewer
  mode — real users are unaffected and keep today's unlimited-instances
  behavior.

No new methods needed on `IDeploymentService` — this is entirely new
logic inside `ConfigScreen`'s existing `_deploy()` method, gated on
`_isReviewerMode`.

---

## Error Handling

- Wrong password at the Worker: `401`, generic body, surfaces through
  `AuthCubit`'s existing failure-state path with the same generic message
  a real OAuth failure would show. Never reveals that a bypass path exists
  or was attempted.
- Network failure calling the Worker: same `tryOperation` failure path,
  same generic messaging — no special-casing needed.
- Reviewer mode + instance cap hit: an inline validation-style error in
  `ConfigScreen`, not a thrown exception — same treatment as any other
  client-side pre-deploy validation failure already in that screen.

## Testing

- `reviewer_bypass_test.dart`: `isReviewerSentinelEmail` returns true for
  the exact sentinel (any case, with surrounding whitespace) and false for
  near-misses (wrong case handled correctly since normalization happens
  before hashing — test a deliberately *wrong* email hashes differently,
  not that case-sensitivity breaks it) and empty string.
- `auth_cubit_test.dart`: new tests for `reviewerBypass()` — success path
  stores only the access token (mock `ISecureStorage`, assert
  `storeRefreshToken`/`storeTokenExpiration` are never called), emits
  `isAuthenticated: true`; failure path (mock client throws
  `ReviewerBypassException`) emits the existing failure state.
- `reviewer_bypass_client_test.dart`: mocked `http.Client`, asserts the
  request body shape, 200/401 handling, and the missing-`access_token`
  edge case.
- `config_screen_test.dart`: new tests — reviewer-mode credentials lock
  the plan picker to `g6-nanode-1`; a mocked `getExistingInstances()`
  returning 3+ `g6-nanode-1` instances blocks the deploy action with a
  visible error; a mock returning fewer than 3 `g6-nanode-1` instances
  plus any number of other-plan instances (simulating pre-existing real
  infra on the account) does NOT block the deploy. Non-reviewer
  credentials leave existing behavior untouched.

No integration test drives the real Worker route or a real Linode
account — that's exercised manually, once, before each actual submission
(see Global Constraints on the vault lifecycle).
