# Linode OAuth Relay Migration — Design

> This is task #11 ("test the real production Linode OAuth consent
> flow end-to-end") actually getting resolved — investigation showed the
> flow was never wired to work, not just untested. See conversation
> history for the discovery trail; the short version is below.

**Goal:** Make the real "LOGIN VIA LINODE" button in `AuthScreen` actually
work, by routing Linode's OAuth exchange through the already-deployed
`oauth-relay` Worker instead of talking to Linode directly from the
app — the same pattern this Worker already uses successfully for GitHub.

**Why this is needed, not just "test it":** Four independent problems
stack up today, not one:

1. **What's actually wired and working**: the Worker's `/authorize` route
   has a real, deployed `linode` provider entry. Confirmed live:
   `GET https://pocketcoder-oauth-relay.gp-c53.workers.dev/authorize?provider=linode&code_challenge=<valid>`
   returns a 302 to `https://login.linode.com/oauth/authorize` with a real
   `client_id=2e228314b0e8455ffc7f` and `redirect_uri=https://pocketcoder-oauth-relay.gp-c53.workers.dev/callback`.
   The registered OAuth app's redirect_uri is this HTTPS Worker callback —
   confirmed by Linode not rejecting the `/authorize` redirect the Worker
   builds.
2. **What the app's real button actually calls**: `AuthCubit.authenticate()`
   → `LinodeOAuthService` (`flutter_aeroform`), which builds its own
   authorize URL **directly** to `login.linode.com`, using
   `redirect_uri: 'pocketcoder://oauth-callback'` (a custom URL scheme,
   not the Worker's HTTPS callback) and a client_id sourced from
   `AppConfig.kLinodeClientId = String.fromEnvironment('LINODE_CLIENT_ID', defaultValue: '')`
   — which no build script or CI config anywhere sets, so it's always
   empty today. Even fixing the empty client_id wouldn't make this work:
   Linode's real OAuth app was registered with the Worker's HTTPS
   redirect_uri, and `LinodeOAuthService` sends a different one — Linode
   would reject the mismatch. The two pieces were built for two different
   architectures and never reconciled. This spec reconciles them by
   rewriting `LinodeOAuthService`'s internals to match what was actually
   registered.
3. **Independent of both of the above**:
   `LinodeOAuthService.authenticateWithWebAuth()`
   (`linode_oauth_service.dart:90-107`) never actually launches a browser
   in production. `getFlutterWebAuth2()` calls `importFlutterWebAuth2()`,
   which unconditionally `throw`s (line 208-210), so the `catch` always
   fires and every real invocation gets `MockFlutterWebAuth2`, which
   returns a hardcoded `'$callbackUrlScheme://oauth-callback?code=test-code'`
   without ever opening anything. `flutter_web_auth_2: ^3.1.2` is a real
   dependency (`pubspec.yaml:17`) that this file never actually imports.
   Fixed in Component 4 below (an injected `WebAuthLauncher`, exactly
   `McpOAuthService`'s existing mechanism — not the same thing as the
   dynamic-import hack this class currently has, despite superficially
   similar names).
4. **Also independent**: the relay base URL this whole migration depends
   on is itself currently wrong. `external_module.dart:113-116`
   (`pocketcoder_flutter`) still registers `@Named('mcpOAuthRelayBaseUrl')`
   as `https://pocketcoder-oauth-relay.workers.dev` — dead placeholder
   text, not the real `https://pocketcoder-oauth-relay.gp-c53.workers.dev`
   this spec's own verification curls against. This is the same binding
   `McpOAuthService` (GitHub) already depends on, so GitHub's in-app MCP
   OAuth is *also* broken today for this exact reason — fixed in
   Component 1, which fixes both.

**Architecture:** `LinodeOAuthService` (`flutter_aeroform`) keeps its
existing `IOAuthService` interface and every existing call site in
`pocketcoder_pro` (`AuthCubit`, `AuthScreen`) untouched. Only its internals
change: `authenticate()` launches the Worker's `/authorize` (not Linode's)
and claims the result via the Worker's `/claim`, mirroring
`McpOAuthService`'s already-proven pattern for GitHub. The Worker gains
one new route, `POST /refresh`, since Linode's tokens genuinely expire and
need real refresh support (GitHub's classic OAuth tokens don't, which is
why no refresh route existed before this). `LinodeAPIClient`'s now-dead
direct-to-Linode OAuth methods are deleted.

**Tech Stack:** Same as the rest of this feature area — Dart/Flutter
(`flutter_aeroform`), Cloudflare Workers (`workers/oauth-relay`,
already deployed).

## Global Constraints

- No changes to `IOAuthService`'s public interface shape, `AuthCubit`, or
  `AuthScreen` — this migration is entirely internal to
  `LinodeOAuthService`/`LinodeAPIClient` plus one new Worker route.
- The Worker relay's base URL is injected into `LinodeOAuthService` by the
  consuming app (`@Named('mcpOAuthRelayBaseUrl')`, resolved from
  `pocketcoder_flutter`'s `ExternalModule`), exactly like `linodeClientId`
  already is today. `flutter_aeroform` must not hardcode or know about
  `pocketcoder-oauth-relay` specifically — it stays provider- and
  deployment-agnostic, matching how it's already built.
- `exchangeCode(String code)` (the `IOAuthService` interface method) keeps
  its exact signature — only its semantics change, from "Linode's raw
  authorization code" to "the Worker's opaque `exchange_code`." The only
  callers today are `LinodeOAuthService.authenticate()` itself and this
  package's own tests — confirmed via a repo-wide grep, so this is a safe
  internal redefinition, not a breaking change for any real caller.
- Two real technical risks must be verified empirically before this is
  considered done (see Verification) — this spec's code changes are
  necessary but their correctness against Linode's actual token endpoint
  is not yet proven. Both have per-provider fallback flags built into the
  design from the start (Component 2) precisely so resolving either one
  never means editing GitHub's already-working behavior:
  - **JSON vs. form-urlencoded body.** A direct `curl -X POST
    https://login.linode.com/oauth/token` during this investigation
    confirmed Linode's token endpoint parses a form-urlencoded body (got
    a proper `invalid_grant` JSON error back for a bad code — i.e. the
    request was understood, just the code was rejected). Whether it also
    accepts the Worker's current JSON body is untested, and is
    independently answerable in isolation (see Verification step 0) —
    it does not require a real login to check.
  - **Whether Linode requires the PKCE `code_verifier` at token-exchange
    time.** The Worker exchanges the authorization code using `client_id`
    + `client_secret` only — it never forwards the app's PKCE
    `code_verifier` to Linode's token endpoint (by design: the Worker is
    a confidential client to Linode; PKCE only secures the app↔Worker
    leg, via the `state`/`exchange_code` KV dance — this leg is
    unaffected by anything below, since `handleAuthorize` still builds
    `state` from the real `code_challenge` regardless). Whether Linode's
    token endpoint permits omitting the verifier when a `code_challenge`
    was present at `/authorize` time requires a real login to test (see
    Verification steps 1-3). If it doesn't, the fallback is a
    per-provider `usePkceUpstream: false` flag on `linode`'s `PROVIDERS`
    entry, read by `handleAuthorize` to skip sending
    `code_challenge`/`code_challenge_method` to Linode at all — never a
    global change to `handleAuthorize`, since GitHub's entry keeps
    whatever its current (untested but unrelated) behavior is.

---

## Components

### 1. Fix the Worker relay base URL (`client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart`)

**This must land before anything else in this spec can be tested at
all.** `external_module.dart:113-116` currently registers
`@Named('mcpOAuthRelayBaseUrl')` as
`https://pocketcoder-oauth-relay.workers.dev` — a dead placeholder,
still carrying a `TODO(mcp-oauth): replace with the real deployed
Worker's...` comment. The real, live URL, confirmed by this
investigation's own curl tests, is
`https://pocketcoder-oauth-relay.gp-c53.workers.dev` (Cloudflare's
free `workers.dev` routing includes the account subdomain). Update the
constant and remove the stale comment. This also fixes GitHub's in-app
MCP OAuth, which depends on the same binding and is equally broken today
for the same reason.

### 2. Worker: per-provider token-request format flags, expiry, and scope (`workers/oauth-relay/src/index.js`)

Add two optional per-provider flags to `PROVIDERS`, read but unused by
GitHub (defaults preserve its exact current behavior), and set on
`linode` from the start so Verification's fallback (if needed) is a
one-line config flip, never a shared-code-path edit:

```js
const PROVIDERS = {
  github: {
    displayName: 'GitHub',
    authorizeUrl: 'https://github.com/login/oauth/authorize',
    tokenUrl: 'https://github.com/login/oauth/access_token',
    scope: 'repo read:user',
    // usePkceUpstream/tokenBodyFormat default to true/'json' when absent
    // (see below) -- unset here deliberately, so GitHub's behavior can't
    // drift as a side effect of tuning Linode's flags.
  },
  linode: {
    displayName: 'Linode',
    authorizeUrl: 'https://login.linode.com/oauth/authorize',
    tokenUrl: 'https://login.linode.com/oauth/token',
    scope: 'linodes:read_write linodes:create images:read_write',
    // Confirmed via a direct curl during this investigation: Linode's
    // token endpoint parses form-urlencoded bodies. Whether it also
    // accepts JSON is untested -- default to the confirmed-working
    // format rather than assuming JSON works here just because it works
    // for GitHub.
    tokenBodyFormat: 'form',
  },
};
```

`handleAuthorize` reads `provider.usePkceUpstream !== false` to decide
whether to set `code_challenge`/`code_challenge_method` on the outgoing
URL (both `true` today by omission, so GitHub's request is byte-for-byte
unchanged). `handleCallback`/`handleRefresh` read
`provider.tokenBodyFormat ?? 'json'` and branch their `fetch` call's
`body`/`Content-Type` between `JSON.stringify(...)` and a
`new URLSearchParams(...).toString()` with
`'application/x-www-form-urlencoded'` accordingly — one shared helper
function, not duplicated per-route:

```js
function buildTokenRequestBody(format, fields) {
  if (format === 'form') {
    return {
      body: new URLSearchParams(fields).toString(),
      contentType: 'application/x-www-form-urlencoded',
    };
  }
  return { body: JSON.stringify(fields), contentType: 'application/json' };
}
```

`handleCallback`'s KV write (currently `{codeChallenge, accessToken,
refreshToken}`) gains two more fields read straight from the provider's
real token response, defaulting to `null` when absent (harmless for
GitHub, which won't have them):

```js
await env.MCP_OAUTH_KV.put(
  `exchange:${exchangeCode}`,
  JSON.stringify({
    codeChallenge: state.cc,
    accessToken: tokenBody.access_token,
    refreshToken: tokenBody.refresh_token || null,
    expiresIn: tokenBody.expires_in ?? null,
    scope: tokenBody.scope ?? null,
  }),
  { expirationTtl: EXCHANGE_TTL_SECONDS }
);
```

`handleClaim`'s response gains the same two fields:

```js
return json({
  access_token: entry.accessToken,
  refresh_token: entry.refreshToken,
  expires_in: entry.expiresIn,
  scope: entry.scope,
}, 200);
```

`McpOAuthTokenPair`/`McpOAuthService` (the GitHub-facing consumer of this
same response) already only reads `access_token`/`refresh_token` off the
JSON body — extra fields it doesn't look at are inert, so this is
backward-compatible with zero changes needed there.

`handleCallback`'s existing token-exchange `fetch` call (the one already
in this file, currently always JSON) is rewritten to use
`buildTokenRequestBody(provider.tokenBodyFormat ?? 'json', {client_id,
client_secret, code, redirect_uri})` the same way Component 3's
`handleRefresh` does, so both routes share one code path for this
decision instead of drifting independently.

### 3. Worker: new `POST /refresh` route (`workers/oauth-relay/src/index.js`)

```js
if (request.method === 'POST' && url.pathname === '/refresh') {
  return handleRefresh(request, env);
}
```

```js
// ---------------------------------------------------------------------------
// POST /refresh
// ---------------------------------------------------------------------------

async function handleRefresh(request, env) {
  let body;
  try {
    body = await request.json();
  } catch (e) {
    return json({ error: 'invalid_json' }, 400);
  }

  const providerId = body.provider;
  const refreshToken = body.refresh_token;
  if (!providerId || !Object.hasOwn(PROVIDERS, providerId) || !refreshToken) {
    return json({ error: 'invalid_request' }, 400);
  }

  const provider = PROVIDERS[providerId];
  const envPrefix = providerId.toUpperCase();
  const clientId = env[`${envPrefix}_OAUTH_CLIENT_ID`];
  const clientSecret = env[`${envPrefix}_OAUTH_CLIENT_SECRET`];
  if (!clientId || !clientSecret) {
    return json({ error: 'server_misconfigured' }, 500);
  }

  const { body: reqBody, contentType } = buildTokenRequestBody(
    provider.tokenBodyFormat ?? 'json',
    {
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
    }
  );

  let tokenResp;
  try {
    tokenResp = await fetch(provider.tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': contentType, Accept: 'application/json' },
      body: reqBody,
    });
  } catch (e) {
    return json({ error: 'refresh_request_failed' }, 502);
  }

  const tokenBody = await tokenResp.json().catch(() => null);
  if (!tokenResp.ok || !tokenBody || tokenBody.error || !tokenBody.access_token) {
    return json({ error: (tokenBody && tokenBody.error) || 'refresh_rejected' }, 401);
  }

  return json({
    access_token: tokenBody.access_token,
    refresh_token: tokenBody.refresh_token || refreshToken,
    expires_in: tokenBody.expires_in ?? null,
    scope: tokenBody.scope ?? null,
  }, 200);
}
```

This route needs no PKCE/KV dance — it's a direct, already-authenticated
server-to-server call (the caller must already hold a real refresh token,
same trust boundary a direct-to-provider refresh call would have had). It
is deliberately unauthenticated beyond "possession of a valid refresh
token" — the same trust boundary a direct-to-provider refresh call would
have had, not a new exposure this Worker introduces. `refresh_token:
tokenBody.refresh_token || refreshToken` preserves the existing token
when the provider doesn't rotate it on refresh (matches
`LinodeAPIClient._parseOAuthTokenResponse`'s current fallback behavior,
being replaced — see Component 6).

### 4. Replace the fake web-auth launcher, and rewrite `authenticate()` (`flutter_aeroform/lib/infrastructure/auth/linode_oauth_service.dart`)

**This must land in the same change as Component 5 — it is a separate,
independent bug from the redirect_uri/client_id mismatch, and without it
the button fails 100% of the time regardless of anything else in this
spec.** `authenticateWithWebAuth()`/`getFlutterWebAuth2()`/
`importFlutterWebAuth2()`/`MockFlutterWebAuth2` (current lines 89-107,
207-220) never launch a real browser in production —
`importFlutterWebAuth2()` unconditionally throws, so the `catch` always
returns the hardcoded mock. Delete all four and replace with the exact
mechanism `McpOAuthService` already uses successfully
(`mcp_oauth_service.dart:18-21,50-51`):

```dart
typedef WebAuthLauncher = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});
```

```dart
final ISecureStorage _secureStorage;
final String _relayBaseUrl;
final http.Client _httpClient;
final String _redirectUri;

LinodeOAuthService(
  this._secureStorage,
  @Named('mcpOAuthRelayBaseUrl') this._relayBaseUrl,
  this._httpClient,
) : _redirectUri = 'pocketcoder://oauth-callback';

/// Overridable in tests only — production code always uses the real
/// FlutterWebAuth2.authenticate. Matches McpOAuthService's mechanism
/// exactly (mcp_oauth_service.dart:50-51) — NOT the same thing as the
/// dynamic-import mock this class used to have.
@visibleForTesting
WebAuthLauncher webAuthLauncher = FlutterWebAuth2.authenticate;
```

`_clientId` is no longer used by this class at all (the Worker now builds
the real authorize URL server-side, same as `McpOAuthService` for GitHub)
— the constructor above already reflects its removal, alongside
`_apiClient` (no longer used once Component 5 lands — see Component 6).

`authenticate()` becomes, mirroring `McpOAuthService.authenticate()`:

```dart
@override
Future<void> authenticate() async {
  final codeVerifier = generateCodeVerifier();
  final codeChallenge = generateCodeChallenge(codeVerifier);
  await _secureStorage.storeCodeVerifier(codeVerifier);

  final authorizeUri = Uri.parse('$_relayBaseUrl/authorize').replace(queryParameters: {
    'provider': 'linode',
    'code_challenge': codeChallenge,
  });

  String callbackUrl;
  try {
    callbackUrl = await webAuthLauncher(
      url: authorizeUri.toString(),
      callbackUrlScheme: getCallbackScheme(),
    );
  } on PlatformException catch (e) {
    if (e.code == 'CANCELED') {
      throw AuthenticationError('Authentication cancelled by user', isCancelled: true);
    }
    throw AuthenticationError('Authentication failed: ${e.message}');
  }

  final callback = Uri.parse(callbackUrl);
  final providerError = callback.queryParameters['error'];
  if (providerError != null) {
    throw AuthenticationError('Authentication failed: $providerError');
  }
  final workerExchangeCode = callback.queryParameters['exchange_code'];
  if (workerExchangeCode == null || workerExchangeCode.isEmpty) {
    throw AuthenticationError('Worker callback missing exchange_code');
  }

  // Defense in depth, matching McpOAuthService's rationale exactly: the
  // Worker already verified S256(code_verifier) == code_challenge at
  // /claim time (below) — this just catches a spoofed deep-link one hop
  // earlier by confirming the state param echoes the request we made.
  final stateParam = callback.queryParameters['state'];
  final decodedState = stateParam == null ? null : decodeState(stateParam);
  if (decodedState == null ||
      decodedState['cc'] != codeChallenge ||
      decodedState['p'] != 'linode') {
    throw AuthenticationError('State mismatch');
  }

  // Named workerExchangeCode, not exchangeCode, specifically so this local
  // never shadows the exchangeCode(String) instance method called next —
  // a real bug in an earlier draft of this spec.
  await exchangeCode(workerExchangeCode);
}
```

`getCallbackScheme()` stays as-is (`Uri.parse(_redirectUri).scheme` →
`'pocketcoder'`). `decodeState` is a new static method (no leading
underscore, `@visibleForTesting` — matching `McpOAuthService.decodeState`'s
exact convention so its own tests can call it by name), identical in
behavior: base64url-decode, JSON parse, return `null` on any malformed
input. Duplicated rather than shared since these are two different
packages/repos with no existing code-sharing mechanism between them.

### 5. `LinodeOAuthService.exchangeCode()` / `refreshToken()` rewrite

```dart
@override
Future<OAuthToken> exchangeCode(String code) async {
  final codeVerifier = await _secureStorage.getCodeVerifier();
  if (codeVerifier == null) {
    throw AuthenticationError('Code verifier not found');
  }

  final resp = await _httpClient.post(
    Uri.parse('$_relayBaseUrl/claim'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'exchange_code': code, 'code_verifier': codeVerifier}),
  );
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  if (resp.statusCode != 200) {
    throw AuthenticationError('Claim failed: ${body['error']}');
  }

  final token = _tokenFromClaimResponse(body);

  await _secureStorage.storeAccessToken(token.accessToken);
  await _secureStorage.storeRefreshToken(token.refreshToken);
  await _secureStorage.storeTokenExpiration(token.expiresAt);
  await _secureStorage.storeCodeVerifier('');

  return token;
}

@override
Future<OAuthToken> refreshToken() async {
  final refreshToken = await _secureStorage.getRefreshToken();
  if (refreshToken == null) {
    throw AuthenticationError('No refresh token available');
  }

  final resp = await _httpClient.post(
    Uri.parse('$_relayBaseUrl/refresh'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({'provider': 'linode', 'refresh_token': refreshToken}),
  );
  final body = jsonDecode(resp.body) as Map<String, dynamic>;
  if (resp.statusCode != 200) {
    throw AuthenticationError('Refresh failed: ${body['error']}');
  }

  final token = _tokenFromClaimResponse(body);

  await _secureStorage.storeAccessToken(token.accessToken);
  await _secureStorage.storeRefreshToken(token.refreshToken);
  await _secureStorage.storeTokenExpiration(token.expiresAt);

  return token;
}

/// Throws AuthenticationError on a malformed 200 (missing/empty
/// access_token) rather than letting a raw TypeError escape — mirrors
/// McpOAuthService._claim's explicit null/empty check
/// (mcp_oauth_service.dart:151-154), which an earlier draft of this spec
/// missed.
OAuthToken _tokenFromClaimResponse(Map<String, dynamic> body) {
  final accessToken = body['access_token'] as String?;
  if (accessToken == null || accessToken.isEmpty) {
    throw AuthenticationError('missing access_token in relay response');
  }
  final expiresIn = body['expires_in'] as int?;
  final scopeStr = body['scope'] as String?;
  return OAuthToken(
    accessToken: accessToken,
    refreshToken: body['refresh_token'] as String? ?? '',
    expiresAt: expiresIn == null
        ? DateTime.now().add(const Duration(hours: 2)) // Linode's documented default token lifetime, used only if the response omits expires_in
        : DateTime.now().add(Duration(seconds: expiresIn)),
    scopes: scopeStr == null ? _requiredScopes : scopeStr.split(' '),
  );
}
```

`getAccessToken()`, `validateScopes()`, `logout()`, `providerName`,
`requiredScopes`, `generateCodeVerifier()`, `generateCodeChallenge()`, and
`getCallbackScheme()` all stay unchanged — this migration only touches how
the token is obtained, not how it's used or refreshed proactively
(`getAccessToken()`'s existing expiry check at
`linode_oauth_service.dart:167-181` keeps working exactly as documented in
the (now-superseded) reviewer-bypass spec's investigation).
`authenticateWithWebAuth()`/`getFlutterWebAuth2()`/
`importFlutterWebAuth2()`/`MockFlutterWebAuth2` do NOT stay unchanged —
see Component 4, which deletes and replaces all four.

### 6. Delete dead direct-to-Linode OAuth code (`flutter_aeroform`)

- `ICloudProviderAPIClient.exchangeAuthCode()` /
  `.refreshAccessToken()` (`lib/domain/cloud_provider/i_cloud_provider_api_client.dart:31,34`)
  — remove from the interface.
- `LinodeAPIClient.exchangeAuthCode()` / `.refreshAccessToken()` /
  `_parseOAuthTokenResponse()` (`lib/infrastructure/cloud_provider/linode_api_client.dart`)
  — remove the implementations. `_clientId` (line 27), its constructor
  param (line 37), and `_oauthUrl` (line 18) become unused once these are
  gone — confirmed via grep that nothing else in this class references
  them — remove all three too. `LinodeAPIClient`'s constructor becomes
  1-positional-arg (`http.Client`) plus its existing named
  `bootTimeInstaller` param — every call site passing a second positional
  clientId argument needs that argument dropped (see Testing).
- `OAuthError` (`lib/infrastructure/cloud_provider/cloud_provider_errors.dart`,
  the class starting at line 80 — confirm its exact closing brace against
  the file rather than a hardcoded end line, since `wc -l`-style counts
  can be off by one on a file with no trailing newline) — confirmed via
  repo-wide grep its only callers are the two methods just deleted and
  their own tests. Delete the class.
- In `linode_oauth_service.dart` itself: `_authUrl` (line 26) and
  `extractCodeFromCallback()` (lines 114-117) are also dead once
  Components 4-5 land — Linode's raw `code` param never reaches this
  class anymore, only the Worker's `exchange_code`. Delete both, plus the
  now-unused `import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart'`
  (line 8) if nothing else in the file needs it after `_apiClient` is
  removed.
- Tests that stub `ICloudProviderAPIClient.exchangeAuthCode`/
  `.refreshAccessToken` via mocktail (`extends Mock implements
  ICloudProviderAPIClient`, e.g. in `linode_oauth_service_test.dart`,
  `deployment_service_test.dart`, `custom_image_provisioning_strategy_test.dart`)
  are unaffected as mock *classes* — mocktail mocks don't need every
  interface method implemented. What breaks is each `when(() =>
  mockApiClient.exchangeAuthCode(...))`/`.refreshAccessToken(...)`
  **stub call site** referencing a method that no longer exists on the
  interface — those specific stub lines must be deleted, not the mock
  classes themselves (see Testing for the concrete files/line numbers).
- `preRegisterAeroformConfig()` in `pocketcoder_pro/lib/app.dart` has
  **two** separate `linodeClientId` references — the `AppConfig(linodeClientId:
  AppConfig.kLinodeClientId, ...)` constructor field earlier in the
  function, and a separate GetIt `instanceName: 'linodeClientId'`
  registration a few lines after it (`:396-399`). Both become
  unreferenced by anything once both `LinodeOAuthService` and
  `LinodeAPIClient` drop their `_clientId` params. Leaving them in place
  is harmless (nothing reads them, no error), but worth removing both —
  not just the one — so neither is left as a mystery for a future reader.
  Not required for correctness.

### 7. Regenerate DI wiring and ship the cross-repo change (`flutter_aeroform`, `pocketcoder`)

`LinodeOAuthService` and `LinodeAPIClient` are constructed by *generated*
code, not hand-written registrations: `flutter_aeroform.module.dart:55-72`
(`gh.lazySingleton<IOAuthService>(() => LinodeOAuthService(...))` /
`gh.lazySingleton<ICloudProviderAPIClient>(() => LinodeAPIClient(...))`).
Changing either constructor's parameter list requires:

1. `dart run build_runner build --delete-conflicting-outputs` inside
   `flutter_aeroform` to regenerate `flutter_aeroform.module.dart` (and any
   other generated file referencing these constructors) against the new
   signatures.
2. Commit and push in `flutter_aeroform` (a separate git repo,
   `qtpi-bonding-org/flutter_aeroform.git`) — same shape as the earlier
   "Deploy-entry plan Task 3" in this project's history.
3. Bump the `ref:` in `pocketcoder/client/packages/pocketcoder_pro/pubspec.yaml`
   to the new commit, then `flutter pub get` from `client/` and confirm
   `pubspec.lock`'s `resolved-ref:` matches.

DI ordering already works out without any change: `mcpOAuthRelayBaseUrl`
is registered by `bootstrap.config.dart` during `bootstrap()`
(`pocketcoder_flutter`'s `ExternalModule`), and `initializeAeroformDI()`
runs after `bootstrap()` completes (`client/apps/pocketcoder/lib/main.dart:22-25`)
— `flutter_aeroform` depending on a named binding a *different* package
registers is a new-in-this-migration relationship (previously only
`linodeClientId`, provided by `pocketcoder_pro`, crossed this same
boundary) but the existing app startup order already satisfies it.

---

## Error Handling

- Every failure path (`CANCELED` platform exception, provider error in the
  callback, missing `exchange_code`, state mismatch, non-200 from
  `/claim` or `/refresh`, missing `access_token` on a 200) throws the
  existing `AuthenticationError` type — no new exception types
  introduced. `AuthCubit.authenticate()`'s existing `tryOperation` wrapper
  and `_AuthView`'s existing error-message handling need no changes.
- `handleRefresh`'s `401` on a rejected refresh surfaces through
  `LinodeOAuthService.refreshToken()` as an `AuthenticationError`, which
  propagates up through `getAccessToken()` to whatever called it — same
  as today's behavior when a refresh fails for any reason (no new
  handling needed; a failed refresh has always been an unhandled
  exception path in this codebase).

## Testing

- `linode_oauth_service_test.dart` / `linode_oauth_service_property_test.dart`
  (existing files, rewritten): replace direct-to-Linode HTTP mocking with
  Worker-relay HTTP mocking, and replace any use of the deleted
  `MockFlutterWebAuth2` mechanism with overriding the new
  `webAuthLauncher` field directly. `authenticate()` hits
  `$relayBaseUrl/authorize` and expects `webAuthLauncher` to return
  `pocketcoder://oauth-callback?exchange_code=...&state=...` (not
  `?code=...`); `exchangeCode()` posts to `$relayBaseUrl/claim`;
  `refreshToken()` posts to `$relayBaseUrl/refresh`. Cover: successful
  claim populates `expiresAt` from `expires_in` when present, falls back
  to the 2-hour default when absent; state mismatch throws; a 200 with a
  missing/empty `access_token` throws (not a raw `TypeError`); refresh
  failure throws. Also delete every `when(() =>
  mockApiClient.exchangeAuthCode(...))`/`.refreshAccessToken(...)` stub
  call site in these files (the mock classes themselves stay valid, only
  the now-nonexistent-method stubs must go).
- `linode_api_client_test.dart` (existing file): delete both the
  `exchangeAuthCode`/`refreshAccessToken` success groups
  (`linode_api_client_test.dart:567-595,639-665`) and the three
  `OAuthError`-related failure blocks (`:596-634,666-683`) — the full set
  of tests for the methods being deleted, not just the error-path subset.
- `linode_api_client_property_test.dart` (existing file): update the
  `setUp`'s `LinodeAPIClient(mockHttpClient, testClientId)` (line 25) to
  drop the second argument, and delete the "Property ..." test at line
  ~226 that calls `client.refreshAccessToken(...)`.
- `test/integration/golden_path_provision_test.dart`: both
  `LinodeAPIClient(...)` construction sites (lines 104 and 414) pass a
  clientId as a second positional argument — drop it from both.
- Any other DI-registration test/smoke test that constructs
  `LinodeOAuthService` or `LinodeAPIClient` directly needs updating for
  the new/removed constructor parameters.

## Verification (must happen before this is considered done)

Resolve the two open risks **separately and in this order** — they are
independently answerable and conflating them (as an earlier draft of this
spec did) makes a single failure ambiguous between two causes.

**Step 0 — JSON vs. form-urlencoded, no app or real login needed:**
`curl -X POST https://login.linode.com/oauth/token -H 'Content-Type:
application/json' -d '{"grant_type":"authorization_code","code":"fake","client_id":"2e228314b0e8455ffc7f","client_secret":"<real secret>"}'`.
An `invalid_grant`-shaped JSON error means Linode parsed the JSON body
fine (this investigation already confirmed form-urlencoded works the same
way) — either format is safe and Component 2's `tokenBodyFormat: 'form'`
default can be revisited later if desired. A 415/HTML/malformed response
means JSON is rejected and confirms `tokenBodyFormat: 'form'` must stay.

**Steps 1-3 — the PKCE-at-exchange question, needs one real login:**
Complete one real login through the actual deployed Worker using a real
Linode account: open
`https://pocketcoder-oauth-relay.gp-c53.workers.dev/authorize?provider=linode&code_challenge=<real PKCE challenge>`
in a browser, log in and consent. Do not rely on reading the resulting
`pocketcoder://` redirect off the browser's address bar — most browsers
do not navigate to an unregistered custom scheme and will not display it
reliably. Instead, use DevTools' Network tab with "preserve log" enabled
and inspect the `/callback` request's response `Location` header directly
(or `curl -i` the `/callback` URL manually with the captured `code` and
`state` query params, which surfaces the Worker's own error body if the
token exchange failed).

1. If the `Location` header is `pocketcoder://oauth-callback?error=...`,
   the token exchange with Linode failed — given step 0 already ruled out
   the body-format question, this specifically means Linode rejected the
   missing `code_verifier`. Fallback: add `usePkceUpstream: false` to
   `linode`'s `PROVIDERS` entry (Component 2) so `handleAuthorize` stops
   sending `code_challenge`/`code_challenge_method` to Linode at all —
   this is a per-provider flag, never a change to `handleAuthorize`'s
   shared logic, so GitHub is unaffected either way.
2. If it's `pocketcoder://oauth-callback?exchange_code=...&state=...`,
   the exchange succeeded. Capture `exchange_code` and the real
   `code_verifier` used to build the original `code_challenge`, then
   `curl -X POST https://pocketcoder-oauth-relay.gp-c53.workers.dev/claim -d '{"exchange_code":"...","code_verifier":"..."}'`
   and confirm a real `access_token` (and, ideally, `expires_in`) comes
   back.
3. Using the `refresh_token` from step 2's response, `curl -X POST
   https://pocketcoder-oauth-relay.gp-c53.workers.dev/refresh -d
   '{"provider":"linode","refresh_token":"..."}'` and confirm a fresh
   `access_token` comes back — this is the one route in this migration
   with zero prior production evidence either way, and has its own
   independent risk of Linode requiring a body format or parameter this
   spec didn't anticipate.
