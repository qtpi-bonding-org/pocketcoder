# Linode OAuth Relay Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the real "LOGIN VIA LINODE" button work by routing
`LinodeOAuthService`'s OAuth exchange through the already-deployed
`oauth-relay` Worker, the same pattern already proven for GitHub.

**Architecture:** See
`docs/superpowers/specs/2026-08-02-linode-oauth-relay-migration-design.md`
for full rationale. Four independent bugs stack today: a dead Worker
base-URL constant, a Worker that never sent Linode-compatible
form-urlencoded bodies (until now) or a `/refresh` route at all, a
`LinodeOAuthService` that never actually launched a browser in
production, and that same service talking directly to Linode instead of
the Worker. This plan fixes all four, then deletes the now-dead
direct-to-Linode code.

**Tech Stack:** Dart/Flutter (`flutter_aeroform`, a separate git repo;
`pocketcoder_flutter`/`pocketcoder_pro` in this repo), Cloudflare Workers
(`workers/oauth-relay`, already deployed), `mocktail` for test doubles.

## Global Constraints

- No changes to `IOAuthService`'s public interface shape, `AuthCubit`, or
  `AuthScreen` — everything stays internal to `LinodeOAuthService`,
  `LinodeAPIClient`, and one new Worker route.
- The Worker relay's base URL is injected into `LinodeOAuthService` via
  `@Named('mcpOAuthRelayBaseUrl')`, exactly like `linodeClientId` was —
  `flutter_aeroform` must never hardcode `pocketcoder-oauth-relay`.
- `exchangeCode(String code)` keeps its exact signature; only its
  semantics change (Linode's raw code → the Worker's opaque
  `exchange_code`). Confirmed via repo-wide grep: its only callers today
  are `LinodeOAuthService.authenticate()` itself and this package's tests.
- Per-provider Worker flags (`usePkceUpstream`, `tokenBodyFormat`) must
  default to GitHub's exact current behavior when absent — GitHub's
  request shape must not change as a side effect of tuning Linode's.
- `flutter_aeroform` is a separate git repo
  (`qtpi-bonding-org/flutter_aeroform.git`), currently resolved in
  `client/pubspec.lock` at whatever `ref:` is in
  `client/packages/pocketcoder_pro/pubspec.yaml` at plan-start time.
  Changes there need their own commit/push before this repo's
  `pubspec.yaml`/`pubspec.lock` can pick up the new ref (same shape as
  the prior deploy-entry-point plan's Task 3).
- Two technical risks are not resolvable by code alone and require one
  manual, real-account verification pass before this plan is considered
  fully done — every other task's automated tests can pass while these
  remain open. That verification pass is Task 9 below (this plan's own
  final task); it also closes out task #11 in the standing project task
  tracker ("Test Linode OAuth consent flow end-to-end").
- `workers/oauth-relay` has no automated test suite today (confirmed:
  no `test/` directory exists under it). Tasks 2 and 3 ship
  `buildTokenRequestBody`/`handleRefresh` with curl-smoke-test-only
  coverage, not CI-enforced regression tests — a future change to this
  Worker should not assume these paths are protected by CI.

---

### Task 1: Fix the Worker relay base URL

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart:113-116`
- Test: `client/packages/pocketcoder_flutter/test/infrastructure/core/external_module_test.dart` (new file — none currently exists for this class)

**Interfaces:**
- Produces: `ExternalModule.mcpOAuthRelayBaseUrl` now returns
  `'https://pocketcoder-oauth-relay.gp-c53.workers.dev'`. Every later
  task in this plan depends on this being correct.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/infrastructure/core/external_module.dart';

void main() {
  test('mcpOAuthRelayBaseUrl points at the real deployed Worker', () {
    final module = ExternalModule();
    expect(
      module.mcpOAuthRelayBaseUrl,
      'https://pocketcoder-oauth-relay.gp-c53.workers.dev',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/core/external_module_test.dart`
Expected: FAIL — actual value is `https://pocketcoder-oauth-relay.workers.dev`.

- [ ] **Step 3: Fix the constant**

In `external_module.dart`, the real current text (confirm against the
file — it may carry an additional leading doc-comment line beyond what's
shown here) is:

```dart
  /// Base URL of workers/oauth-relay (Task 1). No trailing slash.
  /// TODO(mcp-oauth): replace with the real deployed Worker's custom
  /// domain once Task 1 Step 4's one-time `wrangler deploy` has run.
  @Named('mcpOAuthRelayBaseUrl')
  @lazySingleton
  String get mcpOAuthRelayBaseUrl =>
      'https://pocketcoder-oauth-relay.workers.dev';
```

Replace it with (drop the resolved TODO comment; keep the "Base URL of..."
line since it's still accurate description, not stale):

```dart
  /// Base URL of workers/oauth-relay. No trailing slash.
  @Named('mcpOAuthRelayBaseUrl')
  @lazySingleton
  String get mcpOAuthRelayBaseUrl =>
      'https://pocketcoder-oauth-relay.gp-c53.workers.dev';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/core/external_module_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart client/packages/pocketcoder_flutter/test/infrastructure/core/external_module_test.dart
git commit -m "fix(client): point mcpOAuthRelayBaseUrl at the real deployed Worker"
```

---

### Task 2: Worker — per-provider token-format flags + expiry/scope passthrough

**Files:**
- Modify: `workers/oauth-relay/src/index.js`
- Test: `workers/oauth-relay/test/index.test.js` if a test file already
  exists for this Worker — if none exists, this task's verification is
  the curl-based manual check in Step 4 (no local Worker test harness is
  set up in this repo today; do not introduce one as a side effect of
  this task).

**Interfaces:**
- Produces: `PROVIDERS.linode.tokenBodyFormat = 'form'`,
  `buildTokenRequestBody(format, fields)` helper,
  `handleCallback`/`handleClaim` now carrying `expires_in`/`scope`.
- Consumes: nothing new from earlier tasks.

- [ ] **Step 1: Add the per-provider flags to `PROVIDERS`**

```js
const PROVIDERS = {
	github: {
		displayName: 'GitHub',
		authorizeUrl: 'https://github.com/login/oauth/authorize',
		tokenUrl: 'https://github.com/login/oauth/access_token',
		scope: 'repo read:user',
	},
	linode: {
		displayName: 'Linode',
		authorizeUrl: 'https://login.linode.com/oauth/authorize',
		tokenUrl: 'https://login.linode.com/oauth/token',
		scope: 'linodes:read_write linodes:create images:read_write',
		// Confirmed via a direct curl during this investigation: Linode's
		// token endpoint parses form-urlencoded bodies. Whether it also
		// accepts JSON is untested -- default to the confirmed-working
		// format.
		tokenBodyFormat: 'form',
	},
};
```

- [ ] **Step 2: Add `buildTokenRequestBody` and wire it into `handleAuthorize`/`handleCallback`**

Add near the other helpers:

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

In `handleAuthorize`, guard the two PKCE params behind the new flag
(default `true` when absent, so GitHub is unaffected):

```js
	const usePkceUpstream = provider.usePkceUpstream !== false;
	const params = new URLSearchParams();
	params.set('client_id', clientId);
	params.set('response_type', 'code');
	params.set('redirect_uri', redirectUri);
	params.set('scope', provider.scope);
	params.set('state', state);
	if (usePkceUpstream) {
		params.set('code_challenge', codeChallenge);
		params.set('code_challenge_method', 'S256');
	}
```

In `handleCallback`, replace the existing hardcoded JSON `fetch` call:

```js
	const { body: reqBody, contentType } = buildTokenRequestBody(
		provider.tokenBodyFormat ?? 'json',
		{ client_id: clientId, client_secret: clientSecret, code, redirect_uri: redirectUri }
	);

	let tokenResp;
	try {
		tokenResp = await fetch(provider.tokenUrl, {
			method: 'POST',
			headers: { 'Content-Type': contentType, Accept: 'application/json' },
			body: reqBody,
		});
	} catch (e) {
		console.error('Token exchange request failed:', e.message);
		return redirectToApp({ error: 'token_exchange_failed' });
	}
```

- [ ] **Step 3: Pass `expires_in`/`scope` through the KV entry and `/claim` response**

In `handleCallback`'s KV write:

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

In `handleClaim`'s success response:

```js
	return json({
		access_token: entry.accessToken,
		refresh_token: entry.refreshToken,
		expires_in: entry.expiresIn,
		scope: entry.scope,
	}, 200);
```

- [ ] **Step 4: Deploy and smoke-test via the secrets daemon**

This Worker's deploy is gated behind the secrets daemon (per the
secrets-daemon skill) — invoke the existing `deploy_mcp_oauth_relay`
action (already wired, no new `actions.json` entry needed for this
change) rather than running `wrangler deploy` directly. After it
completes, verify GitHub's `/authorize` still produces its exact prior
redirect shape (no `code_challenge` regression) and Linode's does too:

```bash
CHALLENGE=$(python3 -c "import secrets,base64; print(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode().rstrip('='))")
curl -s -D - -o /dev/null "https://pocketcoder-oauth-relay.gp-c53.workers.dev/authorize?provider=github&code_challenge=$CHALLENGE"
curl -s -D - -o /dev/null "https://pocketcoder-oauth-relay.gp-c53.workers.dev/authorize?provider=linode&code_challenge=$CHALLENGE"
```

Expected: both return `302` with a `Location` header containing
`code_challenge=$CHALLENGE&code_challenge_method=S256` (confirms
`usePkceUpstream` defaulting to `true` didn't regress either provider).

Also run Verification Step 0 from the design spec now (independent of any
real login):

```bash
curl -s -X POST https://login.linode.com/oauth/token \
  -H 'Content-Type: application/json' \
  -d '{"grant_type":"authorization_code","code":"fake","client_id":"2e228314b0e8455ffc7f"}'
```

Record whether this returns a JSON `invalid_grant`-shaped error (JSON body
accepted — `tokenBodyFormat: 'form'` could later be relaxed, though there
is no need to) or a non-JSON/415 response (confirms `'form'` must stay).
This does not block the rest of this plan either way, since `'form'` is
already the default.

- [ ] **Step 5: Commit**

```bash
git add workers/oauth-relay/src/index.js
git commit -m "feat(workers): per-provider token-format flags + expiry/scope passthrough on oauth-relay"
```

---

### Task 3: Worker — new `POST /refresh` route

**Files:**
- Modify: `workers/oauth-relay/src/index.js`

**Interfaces:**
- Consumes: `buildTokenRequestBody` (Task 2).
- Produces: `POST /refresh` accepting `{provider, refresh_token}`,
  returning `{access_token, refresh_token, expires_in, scope}` on success
  or `{error}` with a non-200 status on failure. Task 6 (`flutter_aeroform`)
  calls this.

- [ ] **Step 1: Add the route dispatch**

In the `fetch` handler's route table:

```js
		if (request.method === 'POST' && url.pathname === '/refresh') {
			return handleRefresh(request, env);
		}
```

- [ ] **Step 2: Implement `handleRefresh`**

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
		{ client_id: clientId, client_secret: clientSecret, grant_type: 'refresh_token', refresh_token: refreshToken }
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

- [ ] **Step 3: Deploy and smoke-test with a deliberately-invalid refresh token**

Via the secrets daemon's `deploy_mcp_oauth_relay` action, then:

```bash
curl -s -X POST https://pocketcoder-oauth-relay.gp-c53.workers.dev/refresh \
  -H 'Content-Type: application/json' \
  -d '{"provider":"linode","refresh_token":"not-a-real-token"}'
```

Expected: `401` with a `{"error": "..."}` body (proves the route is live
and correctly rejects a bad token) — a *real* refresh token isn't
available until Task 11's manual verification.

- [ ] **Step 4: Commit**

```bash
git add workers/oauth-relay/src/index.js
git commit -m "feat(workers): add POST /refresh to oauth-relay for providers whose tokens expire"
```

---

### Task 4: flutter_aeroform — replace the fake web-auth launcher

**Files:**
- Modify: `lib/infrastructure/auth/linode_oauth_service.dart`
- Test: `test/infrastructure/auth/linode_oauth_service_test.dart`

**Interfaces:**
- Produces: `LinodeOAuthService.webAuthLauncher` (a `@visibleForTesting`
  `WebAuthLauncher` field, defaulting to `FlutterWebAuth2.authenticate`),
  replacing `authenticateWithWebAuth()`/`getFlutterWebAuth2()`/
  `importFlutterWebAuth2()`/`MockFlutterWebAuth2`.
- Consumes: `flutter_web_auth_2` (already a dependency, `pubspec.yaml:17`
  — never previously imported by this file).

This task is scoped narrowly to the launcher mechanism only — Task 5
rewrites `authenticate()`'s actual body (which URL it hits, how it parses
the callback). Doing them together as one commit is fine if working
directly; if dispatching to a fresh implementer, brief them on both
Tasks 4 and 5 together, since a passing test for `authenticate()` in
isolation requires both.

- [ ] **Step 1: Write the failing test**

```dart
test('authenticate uses the injected webAuthLauncher, not a hardcoded mock', () async {
  service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
    expect(callbackUrlScheme, 'pocketcoder');
    return 'pocketcoder://oauth-callback?exchange_code=abc&state=xyz';
  };
  // (Task 5's authenticate() rewrite is required for this to compile/pass
  // end-to-end — this test is written now and passes once both tasks land.)
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/infrastructure/auth/linode_oauth_service_test.dart`
Expected: FAIL (no `webAuthLauncher` field exists yet).

- [ ] **Step 3: Add the typedef and field, delete the fake mechanism**

Add near the top of `linode_oauth_service.dart`:

```dart
typedef WebAuthLauncher = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});
```

Add the import: `import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';`

Inside the class, add:

```dart
  /// Overridable in tests only — production code always uses the real
  /// FlutterWebAuth2.authenticate. Matches McpOAuthService's mechanism
  /// exactly (mcp_oauth_service.dart:50-51).
  @visibleForTesting
  WebAuthLauncher webAuthLauncher = FlutterWebAuth2.authenticate;
```

Delete `authenticateWithWebAuth()`, `getFlutterWebAuth2()`,
`importFlutterWebAuth2()`, and `MockFlutterWebAuth2` entirely (current
lines 89-107 and 207-220).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/infrastructure/auth/linode_oauth_service_test.dart`
Expected: still FAIL at this point if Task 5 hasn't landed yet (since
`authenticate()` doesn't call `webAuthLauncher` until Task 5) — that's
expected; proceed to Task 5 before expecting this test to pass. If doing
Tasks 4-5 as one combined change, this step becomes the final PASS check
after both are done.

- [ ] **Step 5: Commit** (fold into Task 5's commit if done together — see note above)

---

### Task 5: flutter_aeroform — rewrite `authenticate()` to use the Worker relay

**Files:**
- Modify: `lib/infrastructure/auth/linode_oauth_service.dart`
- Test: `test/infrastructure/auth/linode_oauth_service_test.dart`, `test/infrastructure/auth/linode_oauth_service_property_test.dart`

**Interfaces:**
- Consumes: `webAuthLauncher` (Task 4), `mcpOAuthRelayBaseUrl` (Task 1, via
  `@Named('mcpOAuthRelayBaseUrl')` injection).
- Produces: `authenticate()` now hits `$relayBaseUrl/authorize?provider=linode&code_challenge=...`
  and expects a `pocketcoder://oauth-callback?exchange_code=...&state=...`
  callback (not `?code=...`).

- [ ] **Step 1: Rewrite `setUp` and mock scaffolding first**

`linode_oauth_service_test.dart` today has no `MockHttpClient` and
constructs the service with the *old* 3-arg shape. Confirm against the
file, then:

- Delete `class MockCloudProviderAPIClient extends Mock implements ICloudProviderAPIClient {}`
  and its `mockApiClient` variable — no longer a constructor dependency.
- Add `class MockHttpClient extends Mock implements http.Client {}`
  (matching the existing convention already used in the sibling file
  `linode_api_client_test.dart:11`) and a `late MockHttpClient mockHttpClient;`.
- Change `setUp`'s service construction from
  `LinodeOAuthService(mockSecureStorage, mockApiClient, testClientId)` to
  `LinodeOAuthService(mockSecureStorage, 'https://relay.test', mockHttpClient)`,
  initializing `mockHttpClient = MockHttpClient();` alongside the other
  mocks.
- Register a fallback value for `Uri` if not already present
  (`registerFallbackValue(Uri.parse('https://example.com'))`), needed by
  `mocktail`'s `any()` matcher on `http.Client.post`'s first positional
  argument.

Apply the identical rewrite to
`linode_oauth_service_property_test.dart` — it has its own independent
`setUp` at lines 68-72 with the same old 3-arg construction, and its own
now-unused local `MockFlutterWebAuth2` fake class (lines 15-38, already
dead code today — not instantiated anywhere in that file) which should be
deleted in the same pass.

- [ ] **Step 2: Write the failing test**

```dart
test('authenticate builds the relay authorize URL and claims the exchange code', () async {
  service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
    expect(url, startsWith('https://relay.test/authorize?'));
    expect(Uri.parse(url).queryParameters['provider'], 'linode');
    final challenge = Uri.parse(url).queryParameters['code_challenge']!;
    final state = base64Url.encode(utf8.encode(jsonEncode({'p': 'linode', 'cc': challenge}))).replaceAll('=', '');
    return 'pocketcoder://oauth-callback?exchange_code=abc123&state=$state';
  };
  when(() => mockHttpClient.post(
        Uri.parse('https://relay.test/claim'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'access_token': 'tok', 'refresh_token': 'ref', 'expires_in': 7200}),
        200,
      ));
  when(() => mockSecureStorage.getCodeVerifier()).thenAnswer((_) async => 'verifier');

  await service.authenticate();

  verify(() => mockSecureStorage.storeAccessToken('tok')).called(1);
});

test('authenticate throws on state mismatch', () async {
  service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async =>
      'pocketcoder://oauth-callback?exchange_code=abc&state=${base64Url.encode(utf8.encode(jsonEncode({'p': 'linode', 'cc': 'wrong'})))}';

  expect(() => service.authenticate(), throwsA(isA<AuthenticationError>()));
});
```

(These snippets show the required assertions against the `mockHttpClient`/
`mockSecureStorage` fixtures set up in Step 1 above — adjust exact syntax
to match this file's other existing test conventions, e.g. matcher
helpers already in use.)

- [ ] **Step 3: Run test to verify it fails**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/infrastructure/auth/linode_oauth_service_test.dart`
Expected: FAIL — `authenticate()` still builds a direct-to-Linode URL.

- [ ] **Step 4: Rewrite the constructor and `authenticate()`**

Replace the constructor:

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
```

Add the `http` import: `import 'package:http/http.dart' as http;` and
`import 'dart:convert';` if not already present.

Replace `authenticate()`:

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

    final stateParam = callback.queryParameters['state'];
    final decodedState = stateParam == null ? null : decodeState(stateParam);
    if (decodedState == null ||
        decodedState['cc'] != codeChallenge ||
        decodedState['p'] != 'linode') {
      throw AuthenticationError('State mismatch');
    }

    await exchangeCode(workerExchangeCode);
  }

  @visibleForTesting
  static Map<String, dynamic>? decodeState(String stateParam) {
    try {
      final padded = base64Url.normalize(stateParam);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (e) {
      return null;
    }
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/infrastructure/auth/linode_oauth_service_test.dart`
Expected: PASS for the two new tests (Task 6 must land before the
*property* test file is fully green again — its Properties 3/39 and the
"code verifier cleared" test still reference the old flow until Task 6's
Step 6 rewrites them; that's expected and handled there, not here).

- [ ] **Step 6: Commit**

```bash
git add lib/infrastructure/auth/linode_oauth_service.dart test/infrastructure/auth/linode_oauth_service_test.dart test/infrastructure/auth/linode_oauth_service_property_test.dart
git commit -m "feat(flutter_aeroform): route LinodeOAuthService.authenticate() through the oauth-relay Worker"
```

---

### Task 6: flutter_aeroform — rewrite `exchangeCode()`/`refreshToken()`, delete dead direct-to-Linode code

**Files:**
- Modify: `lib/infrastructure/auth/linode_oauth_service.dart`
- Modify: `lib/domain/cloud_provider/i_cloud_provider_api_client.dart`
- Modify: `lib/infrastructure/cloud_provider/linode_api_client.dart`
- Modify: `lib/infrastructure/cloud_provider/cloud_provider_errors.dart`
- Modify: `pocketcoder/client/packages/pocketcoder_pro/lib/app.dart`
- Test: `test/infrastructure/auth/linode_oauth_service_test.dart`, `test/infrastructure/auth/linode_oauth_service_property_test.dart`, `test/infrastructure/cloud_provider/linode_api_client_test.dart`, `test/infrastructure/cloud_provider/linode_api_client_property_test.dart`, `test/integration/golden_path_provision_test.dart`

**Interfaces:**
- Consumes: `POST /refresh` (Task 3).
- Produces: `exchangeCode(String code)` now claims via `$relayBaseUrl/claim`;
  `refreshToken()` now refreshes via `$relayBaseUrl/refresh`.
  `ICloudProviderAPIClient`/`LinodeAPIClient` lose `exchangeAuthCode`/
  `refreshAccessToken`; `LinodeAPIClient`'s constructor becomes
  `LinodeAPIClient(http.Client, {LinodeBootTimeInstaller? bootTimeInstaller})`
  (no more clientId positional param). `OAuthError` is deleted.

- [ ] **Step 1: Write the failing tests**

Add to `linode_oauth_service_test.dart`:

```dart
test('exchangeCode claims via the relay and stores only what the response has', () async {
  when(() => mockSecureStorage.getCodeVerifier()).thenAnswer((_) async => 'verifier');
  when(() => mockHttpClient.post(
        Uri.parse('https://relay.test/claim'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'access_token': 'tok', 'refresh_token': 'ref', 'expires_in': 7200, 'scope': 'linodes:read_write'}),
        200,
      ));

  final token = await service.exchangeCode('worker-exchange-code');

  expect(token.accessToken, 'tok');
  verify(() => mockSecureStorage.storeAccessToken('tok')).called(1);
});

test('exchangeCode throws on a 200 with a missing access_token', () async {
  when(() => mockSecureStorage.getCodeVerifier()).thenAnswer((_) async => 'verifier');
  when(() => mockHttpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
      .thenAnswer((_) async => http.Response(jsonEncode({}), 200));

  expect(() => service.exchangeCode('x'), throwsA(isA<AuthenticationError>()));
});

test('refreshToken refreshes via the relay /refresh route', () async {
  when(() => mockSecureStorage.getRefreshToken()).thenAnswer((_) async => 'old-refresh');
  when(() => mockHttpClient.post(
        Uri.parse('https://relay.test/refresh'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((_) async => http.Response(
        jsonEncode({'access_token': 'new-tok', 'refresh_token': 'new-ref', 'expires_in': 3600}),
        200,
      ));

  final token = await service.refreshToken();

  expect(token.accessToken, 'new-tok');
});
```

The existing `group('getAccessToken')` (confirm exact lines against the
file — currently around lines 305-360) also references
`mockApiClient.refreshAccessToken` twice, and **these are not dead stubs
to delete** — they're the only coverage of `getAccessToken()`'s proactive
-refresh branch and must be rewritten, not removed:

- `'returns stored access token when not expired'`: has a
  `verifyNever(() => mockApiClient.refreshAccessToken(any()))` — rewrite
  as `verifyNever(() => mockHttpClient.post(Uri.parse('https://relay.test/refresh'), headers: any(named: 'headers'), body: any(named: 'body')))`.
- `'refreshes token when within 5 minutes of expiration'`: stubs
  `mockApiClient.refreshAccessToken(testRefreshToken)` to return a canned
  token — rewrite as a `mockHttpClient.post(Uri.parse('https://relay.test/refresh'), ...)`
  stub returning the new JSON shape (`{access_token, refresh_token,
  expires_in}`), keeping the same assertions on the result and on storage
  being updated.
- `'throws AuthenticationError when not authenticated'`: doesn't touch
  `mockApiClient` — no change needed.

Everywhere else in this file, delete `when(() =>
mockApiClient.exchangeAuthCode(...))`/`.refreshAccessToken(...)` stubs
that aren't part of the `getAccessToken` group above (they reference
methods about to be removed from `ICloudProviderAPIClient` with no
remaining assertion depending on them).

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test test/infrastructure/auth/linode_oauth_service_test.dart`
Expected: FAIL — `exchangeCode`/`refreshToken` still call `_apiClient`.

- [ ] **Step 3: Rewrite `exchangeCode()`/`refreshToken()`, add `_tokenFromClaimResponse`**

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
          ? DateTime.now().add(const Duration(hours: 2))
          : DateTime.now().add(Duration(seconds: expiresIn)),
      scopes: scopeStr == null ? _requiredScopes : scopeStr.split(' '),
    );
  }
```

Delete `_authUrl` (old line 26), `extractCodeFromCallback()` (old lines
114-117), the `_apiClient` field and its constructor param, and the now-
unused `import 'package:flutter_aeroform/domain/cloud_provider/i_cloud_provider_api_client.dart'`.

- [ ] **Step 4: Delete the dead direct-to-Linode OAuth methods**

In `i_cloud_provider_api_client.dart`, remove:

```dart
  Future<OAuthToken> exchangeAuthCode(String code, String codeVerifier);
  Future<OAuthToken> refreshAccessToken(String refreshToken);
```

In `linode_api_client.dart`, remove the `exchangeAuthCode()`,
`refreshAccessToken()`, and `_parseOAuthTokenResponse()` methods, the
`_oauthUrl` constant, the `_clientId` field, and its constructor
parameter — the constructor becomes:

```dart
  LinodeAPIClient(
    this._httpClient, {
    LinodeBootTimeInstaller? bootTimeInstaller,
  }) : _bootTimeInstaller = bootTimeInstaller ?? LinodeBootTimeInstaller(_httpClient);
```

(match whatever the existing default-instantiation shape for
`bootTimeInstaller` actually is in the current file — this shows the
parameter list change, not necessarily the exact default-value
expression.)

In `cloud_provider_errors.dart`, delete the `OAuthError` class entirely
(the class starts at line 80 — confirm the exact closing brace against
the file rather than trusting a hardcoded end line, since `wc -l`-style
counts can be off by one on a file with no trailing newline).

- [ ] **Step 5: Rewrite `linode_oauth_service_property_test.dart`'s remaining old-flow tests**

This file was already given the `setUp`/mock rewrite in Task 5 Step 1,
but three of its tests still assert against the deleted
`ICloudProviderAPIClient` methods and must be rewritten now that those
methods are gone (not just have their stubs deleted, since the
assertions themselves depend on the old flow):

- `'Property 3: Automatic token refresh on near expiration'`: stubs
  `mockApiClient.refreshAccessToken` and verifies it was called — rewrite
  to stub `mockHttpClient.post(Uri.parse('https://relay.test/refresh'), ...)`
  instead, verifying that POST happened.
- `'Property 39: New tokens replace old tokens in storage'`: same
  rewrite — stub the relay refresh endpoint instead of `mockApiClient`.
- `'Property: Code verifier is cleared after successful token exchange'`:
  stubs `mockApiClient.exchangeAuthCode` — rewrite to stub
  `mockHttpClient.post(Uri.parse('https://relay.test/claim'), ...)`
  returning a canned `{access_token, refresh_token, expires_in}` body,
  keeping the same assertion that `storeCodeVerifier('')` gets called
  afterward.
- `'Property: OAuth URL construction includes all required parameters'`:
  this test manually rebuilds a **direct-to-`login.linode.com`** authorize
  URL inline and asserts on `client_id`/`redirect_uri` params — it does
  not call any service method, so there's nothing to "migrate" here; this
  property no longer describes real behavior at all once `authenticate()`
  hits the relay instead (Task 5). Delete this test, or replace it with
  an equivalent assertion against the relay URL shape (`provider=linode`,
  `code_challenge` present, no `client_id`/`redirect_uri` at all — the
  Worker adds those server-side) if you want to keep the coverage under
  the same name.

- [ ] **Step 6: Fix every other call site the deleted methods/params break**

- `test/infrastructure/cloud_provider/linode_api_client_test.dart`: delete
  both the `exchangeAuthCode`/`refreshAccessToken` **success** test
  groups (confirm exact lines against the file — currently ~567-595,
  639-665) and the three `OAuthError` **failure** blocks (currently
  ~596-634, 666-683) — the full set of tests for the methods being
  deleted, not just the failure-path subset.
- `test/infrastructure/cloud_provider/linode_api_client_property_test.dart`:
  change `LinodeAPIClient(mockHttpClient, testClientId)` (confirm exact
  line, currently ~25) to `LinodeAPIClient(mockHttpClient)`; delete the
  property test that calls `client.refreshAccessToken(...)` (confirm
  exact line, currently ~226).
- `test/integration/golden_path_provision_test.dart`: both
  `LinodeAPIClient(...)` construction sites (confirm exact lines,
  currently ~104, ~414) drop their second positional clientId argument.
- `pocketcoder_pro/lib/app.dart`'s `preRegisterAeroformConfig()`: remove
  **both** now-unreferenced `linodeClientId` sites — the
  `AppConfig(linodeClientId: AppConfig.kLinodeClientId, ...)` constructor
  field (earlier in the same function) and the separate GetIt
  `instanceName: 'linodeClientId'` registration a few lines after it.
  Both become dead once `LinodeOAuthService`/`LinodeAPIClient` drop their
  `_clientId` params — confirm both locations against the file rather
  than assuming only one exists.

- [ ] **Step 7: Run the full test suite to verify everything passes**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && flutter test`
Expected: PASS, 0 failures (aside from any pre-existing unrelated
failures already present before this plan — verify via `git stash` +
re-run if anything unexpected fails, same discipline used in the prior
deploy-entry-point plan).

- [ ] **Step 8: Commit**

```bash
git add lib/ test/
git commit -m "feat(flutter_aeroform): finish LinodeOAuthService relay migration, delete dead direct-to-Linode OAuth code"
```

---

### Task 7: flutter_aeroform — regenerate DI, push

**Files:**
- Modify (generated): `lib/flutter_aeroform.module.dart`

**Interfaces:**
- Consumes: the constructor signature changes from Tasks 4-6.
- Produces: `flutter_aeroform.module.dart` correctly constructing
  `LinodeOAuthService(secureStorage, relayBaseUrl, httpClient)` and
  `LinodeAPIClient(httpClient, bootTimeInstaller: ...)`.

- [ ] **Step 1: Regenerate**

Run: `cd /Users/aicoder/Documents/flutter_aeroform && dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 2: Verify the regenerated file matches the new constructors**

Run: `grep -A5 "LinodeOAuthService(\|LinodeAPIClient(" lib/flutter_aeroform.module.dart`
Expected: no `linodeClientId`-named argument passed to either
constructor; `LinodeOAuthService` receives 3 positional args
(secureStorage, a `@Named('mcpOAuthRelayBaseUrl')`-resolved string,
httpClient); `LinodeAPIClient` receives 1 positional arg.

- [ ] **Step 3: Run the full test suite once more against the regenerated DI**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 4: Commit and push**

```bash
git add lib/flutter_aeroform.module.dart
git commit -m "chore(flutter_aeroform): regenerate DI module for the OAuth relay migration"
git push origin main
```

Record the resulting commit hash — Task 8 needs it.

---

### Task 8: pocketcoder — bump the `flutter_aeroform` pubspec ref

**Files:**
- Modify: `client/packages/pocketcoder_pro/pubspec.yaml`
- Modify (generated): `client/pubspec.lock`

**Interfaces:**
- Consumes: the commit hash from Task 7 Step 4.

- [ ] **Step 1: Bump the ref**

In `pocketcoder_pro/pubspec.yaml`, change the `flutter_aeroform` git
dependency's `ref:` to the short hash of Task 7's push.

- [ ] **Step 2: Regenerate the lockfile**

Run: `cd client && flutter pub get`

- [ ] **Step 3: Verify the resolved ref**

Run: `grep -A3 "flutter_aeroform" client/pubspec.lock | grep resolved-ref`
Expected: the full commit hash matches Task 7's push.

- [ ] **Step 4: Run pocketcoder_pro's and pocketcoder_flutter's test suites**

Run: `cd client/packages/pocketcoder_pro && flutter test && cd ../pocketcoder_flutter && flutter test`
Expected: PASS, 0 failures (pre-existing lint infos aside).

- [ ] **Step 5: Run `flutter analyze` on both packages**

Run: `cd client/packages/pocketcoder_pro && flutter analyze && cd ../pocketcoder_flutter && flutter analyze`
Expected: clean (pre-existing infos aside) — this is the point the whole
monorepo compiles again against the migrated `flutter_aeroform`.

- [ ] **Step 6: Commit**

```bash
git add client/packages/pocketcoder_pro/pubspec.yaml client/pubspec.lock
git commit -m "chore(client): bump flutter_aeroform to pick up the Linode OAuth relay migration"
```

---

### Task 9: Manual verification against real Linode — required before this is done

No files change in this task **unless** the PKCE fallback below turns out
to be needed. Follow the design spec's "Verification" section exactly:

- [ ] Step 0 (already run in Task 2 Step 4, re-confirm if not already
      done): direct curl to `login.linode.com/oauth/token` with a JSON
      body, confirm whether Linode parses JSON (informational only —
      `tokenBodyFormat: 'form'` stays regardless).
- [ ] Complete one real login through
      `https://pocketcoder-oauth-relay.gp-c53.workers.dev/authorize?provider=linode&code_challenge=<real PKCE challenge>`
      using a real Linode account, with DevTools Network (preserve log)
      open to inspect the `/callback` response's `Location` header
      directly.
- [ ] If it's `pocketcoder://oauth-callback?error=...`: this is a real
      code change, not just a retry — edit `workers/oauth-relay/src/index.js`'s
      `linode` `PROVIDERS` entry to add `usePkceUpstream: false`, redeploy
      via the secrets daemon's `deploy_mcp_oauth_relay` action (same
      mechanism as Task 2 Step 4/Task 3 Step 3 — never `wrangler deploy`
      directly), re-run Task 2 Step 4's GitHub-regression curl to confirm
      `usePkceUpstream` defaulting to `true` still leaves GitHub's
      redirect byte-for-byte unchanged, then commit:
      `git commit -m "fix(workers): disable PKCE upstream for Linode token exchange"`
      before retrying the real login.
- [ ] If it's `?exchange_code=...&state=...`: curl `/claim` with the
      captured values and confirm a real `access_token` comes back.
- [ ] Using the resulting `refresh_token`, curl `/refresh` and confirm a
      fresh `access_token` comes back.
- [ ] Once all of the above pass, do one real end-to-end run through the
      actual app (build and run on a device/simulator, tap "LOGIN VIA
      LINODE", complete the real consent screen, confirm it lands on
      `ConfigScreen` with a working, authenticated deployment flow) —
      this is task #11 in the standing task tracker, finally closed out
      for real.
