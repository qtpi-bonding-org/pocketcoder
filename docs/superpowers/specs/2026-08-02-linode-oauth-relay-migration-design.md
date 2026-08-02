# Linode OAuth Relay Migration — Design

> This is task #11 ("test the real production Linode OAuth consent
> flow end-to-end") actually getting resolved — investigation showed the
> flow was never wired to work, not just untested. See conversation
> history for the discovery trail; the short version is below.

**Goal:** Make the real "LOGIN VIA LINODE" button in `AuthScreen` actually
work, by routing Linode's OAuth exchange through the already-deployed
`mcp-oauth-relay` Worker instead of talking to Linode directly from the
app — the same pattern this Worker already uses successfully for GitHub.

**Why this is needed, not just "test it":** Two independent, disconnected
implementations exist today:

1. **What's actually wired and working**: the Worker's `/authorize` route
   has a real, deployed `linode` provider entry. Confirmed live:
   `GET https://pocketcoder-mcp-oauth-relay.gp-c53.workers.dev/authorize?provider=linode&code_challenge=<valid>`
   returns a 302 to `https://login.linode.com/oauth/authorize` with a real
   `client_id=2e228314b0e8455ffc7f` and `redirect_uri=https://pocketcoder-mcp-oauth-relay.gp-c53.workers.dev/callback`.
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
   empty today.

Even fixing the empty client_id wouldn't make this work: Linode's real
OAuth app was registered with the Worker's HTTPS redirect_uri, and
`LinodeOAuthService` sends a different one — Linode would reject the
mismatch. The two pieces were built for two different architectures and
never reconciled. This spec reconciles them by rewriting
`LinodeOAuthService`'s internals to match what was actually registered.

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
(`flutter_aeroform`), Cloudflare Workers (`workers/mcp-oauth-relay`,
already deployed).

## Global Constraints

- No changes to `IOAuthService`'s public interface shape, `AuthCubit`, or
  `AuthScreen` — this migration is entirely internal to
  `LinodeOAuthService`/`LinodeAPIClient` plus one new Worker route.
- The Worker relay's base URL is injected into `LinodeOAuthService` by the
  consuming app (`@Named('mcpOAuthRelayBaseUrl')`, resolved from
  `pocketcoder_flutter`'s `ExternalModule`), exactly like `linodeClientId`
  already is today. `flutter_aeroform` must not hardcode or know about
  `pocketcoder-mcp-oauth-relay` specifically — it stays provider- and
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
  is not yet proven:
  - The Worker's existing `handleCallback`/new `handleRefresh` send a
    **JSON** body to the provider's token URL. Confirmed working for
    GitHub already; Linode's actual acceptance of a JSON (vs.
    form-urlencoded) token request body is untested.
  - The Worker exchanges the authorization code using `client_id` +
    `client_secret` only — it never forwards the app's PKCE
    `code_verifier` to Linode's token endpoint (by design: the Worker is a
    confidential client to Linode; PKCE only secures the app↔Worker leg,
    via the `state`/`exchange_code` KV dance). Whether Linode's token
    endpoint permits this when a `code_challenge` was present at
    `/authorize` time is untested. If it doesn't, forwarding the app's
    verifier is not an option (the Worker never sees the app's real
    verifier until `/claim`, after the exchange already happened) —
    the fallback documented in Verification is to not send
    `code_challenge`/`code_challenge_method` to Linode's `/authorize` at
    all for a confidential client, relying solely on the app↔Worker PKCE
    leg for the "same party that started the flow" property.

---

## Components

### 1. Worker: pass through token expiry and scope (`workers/mcp-oauth-relay/src/index.js`)

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

### 2. Worker: new `POST /refresh` route (`workers/mcp-oauth-relay/src/index.js`)

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

  let tokenResp;
  try {
    tokenResp = await fetch(provider.tokenUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
      body: JSON.stringify({
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }),
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
same trust boundary a direct-to-provider refresh call would have had).
`refresh_token: tokenBody.refresh_token || refreshToken` preserves the
existing token when the provider doesn't rotate it on refresh (matches
`LinodeAPIClient._parseOAuthTokenResponse`'s current fallback behavior,
being replaced — see Component 5).

### 3. `LinodeOAuthService.authenticate()` rewrite (`flutter_aeroform/lib/infrastructure/auth/linode_oauth_service.dart`)

Constructor gains the injected relay URL and drops `_apiClient` (no
longer used once Components 3-4 land — see Component 5):

```dart
LinodeOAuthService(
  this._secureStorage,
  @Named('linodeClientId') this._clientId,
  @Named('mcpOAuthRelayBaseUrl') this._relayBaseUrl,
  this._httpClient,
) : _redirectUri = 'pocketcoder://oauth-callback';
```

`_clientId` is no longer used by this class either (the Worker now builds
the real authorize URL server-side, same as `McpOAuthService` for GitHub)
— drop it too. Final constructor:

```dart
final ISecureStorage _secureStorage;
final String _relayBaseUrl;
final http.Client _httpClient;

LinodeOAuthService(
  this._secureStorage,
  @Named('mcpOAuthRelayBaseUrl') this._relayBaseUrl,
  this._httpClient,
) : _redirectUri = 'pocketcoder://oauth-callback';
```

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

  String result;
  try {
    result = await authenticateWithWebAuth(authorizeUri.toString(), getCallbackScheme());
  } on PlatformException catch (e) {
    if (e.code == 'CANCELED') {
      throw AuthenticationError('Authentication cancelled by user', isCancelled: true);
    }
    throw AuthenticationError('Authentication failed: ${e.message}');
  }

  final callback = Uri.parse(result);
  final providerError = callback.queryParameters['error'];
  if (providerError != null) {
    throw AuthenticationError('Authentication failed: $providerError');
  }
  final exchangeCode = callback.queryParameters['exchange_code'];
  if (exchangeCode == null || exchangeCode.isEmpty) {
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

  await exchangeCode(exchangeCode);
}
```

`getCallbackScheme()` stays as-is (`Uri.parse(_redirectUri).scheme` →
`'pocketcoder'`). `decodeState` is a new private static method, identical
in behavior to `McpOAuthService.decodeState` (base64url-decode, JSON
parse, return `null` on any malformed input) — duplicated rather than
shared since these are two different packages/repos with no existing
code-sharing mechanism between them.

### 4. `LinodeOAuthService.exchangeCode()` / `refreshToken()` rewrite

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

OAuthToken _tokenFromClaimResponse(Map<String, dynamic> body) {
  final expiresIn = body['expires_in'] as int?;
  final scopeStr = body['scope'] as String?;
  return OAuthToken(
    accessToken: body['access_token'] as String,
    refreshToken: body['refresh_token'] as String? ?? '',
    expiresAt: expiresIn == null
        ? DateTime.now().add(const Duration(hours: 2)) // Linode's documented default token lifetime, used only if the response omits expires_in
        : DateTime.now().add(Duration(seconds: expiresIn)),
    scopes: scopeStr == null ? _requiredScopes : scopeStr.split(' '),
  );
}
```

`getAccessToken()`, `validateScopes()`, `logout()`, `providerName`,
`requiredScopes`, `generateCodeVerifier()`, `generateCodeChallenge()`,
`getCallbackScheme()`, `authenticateWithWebAuth()` all stay unchanged —
this migration only touches how the token is obtained, not how it's used
or refreshed proactively (`getAccessToken()`'s existing expiry check at
`linode_oauth_service.dart:167-181` keeps working exactly as documented in
the (now-superseded) reviewer-bypass spec's investigation).

### 5. Delete dead direct-to-Linode OAuth code (`flutter_aeroform`)

- `ICloudProviderAPIClient.exchangeAuthCode()` /
  `.refreshAccessToken()` (`lib/domain/cloud_provider/i_cloud_provider_api_client.dart:31,34`)
  — remove from the interface.
- `LinodeAPIClient.exchangeAuthCode()` / `.refreshAccessToken()` /
  `_parseOAuthTokenResponse()` (`lib/infrastructure/cloud_provider/linode_api_client.dart`)
  — remove the implementations. `_clientId` (line 27), its constructor
  param (line 37), and `_oauthUrl` (line 18) become unused once these are
  gone — confirmed via grep that nothing else in this class references
  them — remove all three too.
- `OAuthError` (`lib/infrastructure/cloud_provider/cloud_provider_errors.dart:80-128`)
  — confirmed via repo-wide grep its only callers are the two methods
  just deleted and their own tests. Delete the class.
- Any mock/fake `ICloudProviderAPIClient` implementation in tests that
  currently stubs these two methods needs them removed too, or the
  fake will fail to compile against the trimmed interface.

---

## Error Handling

- Every failure path (`CANCELED` platform exception, provider error in the
  callback, missing `exchange_code`, state mismatch, non-200 from
  `/claim` or `/refresh`) throws the existing `AuthenticationError` type —
  no new exception types introduced. `AuthCubit.authenticate()`'s existing
  `tryOperation` wrapper and `_AuthView`'s existing error-message handling
  need no changes.
- `handleRefresh`'s `401` on a rejected refresh surfaces through
  `LinodeOAuthService.refreshToken()` as an `AuthenticationError`, which
  propagates up through `getAccessToken()` to whatever called it — same
  as today's behavior when a refresh fails for any reason (no new
  handling needed; a failed refresh has always been an unhandled
  exception path in this codebase).

## Testing

- `linode_oauth_service_test.dart` / `linode_oauth_service_property_test.dart`
  (existing files, rewritten): replace direct-to-Linode HTTP mocking with
  Worker-relay HTTP mocking — `authenticate()` hits `$relayBaseUrl/authorize`
  (via the injected `webAuthLauncher`/`authenticateWithWebAuth` override
  already used for testing, returning a `pocketcoder://oauth-callback?exchange_code=...&state=...`
  URL instead of `?code=...`), `exchangeCode()` posts to `$relayBaseUrl/claim`,
  `refreshToken()` posts to `$relayBaseUrl/refresh`. Cover: successful
  claim populates `expiresAt` from `expires_in` when present, falls back
  to the 2-hour default when absent; state mismatch throws; refresh
  failure throws.
- `linode_api_client_test.dart` (existing file): delete the three
  `OAuthError`-related test blocks (`linode_api_client_test.dart:596-634,666-683`)
  along with the methods they tested.
- Any DI-registration test/smoke test that constructs `LinodeOAuthService`
  or `LinodeAPIClient` directly needs updating for the new/removed
  constructor parameters.

## Verification (must happen before this is considered done)

Both of the Global Constraints' open technical risks get resolved the
same way: complete one real login through the actual deployed Worker
using a real Linode account (a browser hitting
`https://pocketcoder-mcp-oauth-relay.gp-c53.workers.dev/authorize?provider=linode&code_challenge=<real PKCE challenge>`,
logging in and consenting, landing on the dead-end `pocketcoder://`
redirect — read the `exchange_code`/`state` off the browser's address bar
manually, no app needed for this part), then:

1. Check whether `handleCallback`'s exchange to Linode actually succeeded
   (it will have, by the time the dead-end redirect happens — a failure
   redirects to `pocketcoder://oauth-callback?error=...` instead, which is
   itself the answer to "does Linode accept a JSON token request body").
2. `curl -X POST https://pocketcoder-mcp-oauth-relay.gp-c53.workers.dev/claim`
   with the captured `exchange_code` and the real code_verifier used to
   build the original `code_challenge`, and confirm a real `access_token`
   (and, ideally, `expires_in`) comes back.

If step 1's redirect carries an error, that's the answer to both open
risks in the Global Constraints at once (a token-exchange failure at that
point most likely means either the JSON body or the missing
`code_verifier` was rejected) — the fallback is to stop sending
`code_challenge`/`code_challenge_method` to Linode's `/authorize` for this
confidential-client flow, and/or switch `handleCallback`/`handleRefresh`'s
request to Linode specifically to `application/x-www-form-urlencoded`
(the format already confirmed to work via a direct curl test against
Linode's real token endpoint during this investigation).
