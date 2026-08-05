# MCP OAuth Provider Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all per-provider hardcoding (authorize URLs, OAuth scopes, `client_id`) from the Flutter client's `McpOAuthService` by moving that knowledge entirely into `workers/oauth-relay`, which gains two new routes — `GET /providers` (discovery, for UI gating) and `GET /authorize` (server-side authorize-URL construction) — so that adding a new OAuth provider (Linear, Notion, ...) becomes a Worker-only config change + deploy, never a Flutter code change or app release.

**Architecture:** `workers/oauth-relay`'s `PROVIDERS` map gains `displayName`/`authorizeUrl`/`scope` alongside the existing `tokenUrl`. `GET /providers` returns `{id, displayName}` for every provider with live secrets configured. `GET /authorize?provider=X&code_challenge=Y` looks `X` up server-side, builds `state` itself, and 302s straight to the provider's real authorize URL with `client_id`/`scope`/`redirect_uri` filled in — Flutter's `McpOAuthService.authenticate()` now just opens that Worker URL in `FlutterWebAuth2` instead of building a provider-specific URL locally. `McpCubit` exposes a thin passthrough to the new `supportedProviders()` call, and `McpManagementScreen`'s CONNECT button uses it (via `FutureBuilder`, fail-open while loading) to show "not yet configured" for a provider that isn't live yet, instead of launching a browser sheet that would fail after the fact.

**Tech Stack:** Cloudflare Workers (vanilla JS), Flutter/Dart (`pocketcoder_flutter` — Cubit, Freezed-style records, `@injectable`/`@lazySingleton` DI, `flutter_web_auth_2`, `mocktail`).

## Global Constraints

- Source of truth: `docs/superpowers/specs/2026-07-27-mcp-oauth-provider-discovery-design.md` (read it before touching any task below if anything here seems to contradict it — the spec wins on intent, this plan wins on mechanics). It is an addendum to `docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md`, which is already fully implemented on this branch (`goose-agui-refactor-plan`) — every file this plan modifies already exists from that prior work.
- **Security-review-required changes (Opus, folded into the design spec) are non-negotiable, not optional hardening:**
  1. Provider lookups (`/authorize`, and the pre-existing `/callback`) must use `Object.hasOwn(PROVIDERS, key)`, never a bare `PROVIDERS[key]` truthy check — plain JS object lookup walks the prototype chain, so `key = "constructor"`/`"toString"`/`"__proto__"` would otherwise pass a `!provider` guard.
  2. `/authorize`'s outgoing redirect URL is built from a **fresh** `URLSearchParams`, `.set()`-ing exactly the known keys (`client_id`, `response_type`, `redirect_uri`, `scope`, `state`, `code_challenge`, `code_challenge_method`) — **never** forward the inbound request's query string wholesale.
  3. `code_challenge_method` is hardcoded to `S256` server-side in `/authorize` (never taken from the client — `/claim` only ever checks S256). `code_challenge` itself is validated against `^[A-Za-z0-9_-]{43}$` before being embedded in the outgoing URL or written to KV.
  4. Flutter's `McpOAuthService` keeps a `decodeState` check: after the browser sheet returns, it asserts the returned `state` decodes to the same `code_challenge` (and `provider`) this client generated, before calling `/claim`. Defense in depth — PKCE's `/claim`-time verifier check is still the actual trust boundary — but it's free and restores the property `state` is normally for.
- Also adopted as stated invariants from the review: `Cache-Control: no-store` on the `/authorize` redirect response; `GET /providers`'s response shape is pinned to `{id, displayName}` and nothing else, forever (no `authorizeUrl`/`tokenUrl`/`scope`/`client_id`/secret-presence diagnostics); Flutter's `McpOAuthService` caches only *successful* `/providers` responses in memory (a transient fetch failure must not poison the app session with an empty list).
- Go style / Flutter style / commit conventions: unchanged from the base plan (`docs/superpowers/plans/2026-07-27-mcp-oauth-flow.md`'s Global Constraints) — no `!` operator in Dart, every public repo/service method wrapped in `tryMethod`, `@LazySingleton(as: I*)` DI pattern. This plan touches no Go/PocketBase files at all — Component 3 (`server/pocketbase/internal/api/mcp_oauth.go`) is explicitly out of scope per the design spec's "Out of scope" section.
- No new schema fields, no new PocketBase routes, no new l10n `.arb`-file structural changes beyond adding two plain string keys (`mcpOauthProviderNotConfiguredLabel` with one placeholder — same shape as the existing `mcpOauthRequiredLabel`).

---

## File Structure

**Worker — modified:**
- `workers/oauth-relay/src/index.js` — `PROVIDERS` map gains `displayName`/`authorizeUrl`/`scope`; new `handleProviders`/`handleAuthorize` functions; `handleCallback`'s provider lookup switches to `Object.hasOwn`; new `base64urlEncode` helper (mirrors the existing `base64urlDecode`).

**Flutter — modified:**
- `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart` — new `McpOAuthProvider` typedef, new `supportedProviders()` abstract method.
- `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart` — delete `_authorizeUrls`/`_scopes`/`_clientIds`/`encodeState`; add `_cachedProviders`/`supportedProviders()`/`decodeState`; `authenticate()` now opens `$relayBaseUrl/authorize?provider=...&code_challenge=...` instead of building a provider-specific URL locally, and verifies the returned `state` before calling `/claim`.
- `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart` — new `McpOAuthException.stateMismatch()` factory.
- `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart` — delete the `githubOAuthClientId` DI provider (dead once `McpOAuthService`'s constructor drops that parameter).
- `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart` — new `supportedOAuthProviders()` passthrough method.
- `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart` — CONNECT/RETRY block wrapped in a `FutureBuilder<List<McpOAuthProvider>>`; "not yet configured" state; `mcpOauthRequiredLabel` now shown with the provider's `displayName` when known.
- `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb` (+ regenerated localization files) — new `mcpOauthProviderNotConfiguredLabel` key.
- `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart` — rewritten for the new `/authorize`-based flow, `decodeState`, `supportedProviders` caching.
- `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart` — new case for `supportedOAuthProviders`.
- `client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart` — regenerated (`build_runner`) — drops the `githubOAuthClientId` DI registration, updates `McpOAuthService`'s constructor call.

---

### Task 1: Worker — `GET /providers` + `GET /authorize`

**Files:**
- Modify: `workers/oauth-relay/src/index.js`

**Interfaces:**
- Consumes: nothing new (standalone Worker; provider client credentials remain `wrangler secret put` values, same as the base design).
- Produces: `GET /providers` → `200 {"providers": [{"id": "github", "displayName": "GitHub"}]}` (only providers with both a `PROVIDERS` entry and live secrets); `GET /authorize?provider=X&code_challenge=Y` → `302` to the real provider authorize URL, or a `pocketcoder://oauth-callback?error=...` redirect on any failure (unknown provider, invalid `code_challenge`, missing `client_id`). Task 2's `McpOAuthService` is the only consumer of both.

This task follows the same no-automated-test-harness convention as the rest of `workers/` (see the base plan's Task 1) — verification is via `wrangler dev --local` + `curl`, run manually against the same `.dev.vars` file the base plan's Task 1 already created (`GITHUB_OAUTH_CLIENT_ID=test-client-id` / `GITHUB_OAUTH_CLIENT_SECRET=test-client-secret`, gitignored).

- [ ] **Step 1: Replace `workers/oauth-relay/src/index.js` in full**

```js
/**
 * PocketCoder MCP OAuth Relay
 *
 * Central-broker-with-HTTPS-callback shape informed by reading
 * docker/mcp-gateway (MIT, Copyright (c) 2025 Docker, Inc.) — see
 * docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, "Precedent
 * this design follows directly" / "Attribution & licensing". No code from
 * that project is copied or adapted here.
 *
 * One centrally-registered OAuth App's client_secret lives here (via
 * `wrangler secret put`), never in the app or any self-hosted deployment.
 * Every Aeroform-provisioned PocketCoder instance shares this one Worker.
 *
 * Flow (see
 * docs/superpowers/specs/2026-07-27-mcp-oauth-provider-discovery-design.md,
 * which supersedes the base spec's "app builds the authorize URL itself"
 * step — this Worker now builds it, so the Flutter client never hardcodes
 * a provider's authorize URL, scope, or client_id):
 *   1. App calls GET /authorize?provider=github&code_challenge=... (opened
 *      in a browser sheet via FlutterWebAuth2, not fetched directly). This
 *      Worker looks provider up in PROVIDERS, builds `state` itself
 *      (base64url({p: provider, cc: code_challenge})), and 302s straight
 *      to the provider's real authorize URL with client_id/scope/
 *      redirect_uri filled in server-side.
 *   2. Provider redirects here: GET /callback?code&state
 *   3. This Worker exchanges code -> {access_token, refresh_token} using
 *      its held client_secret, stashes the token in KV under a fresh
 *      one-time exchange_code (60s TTL), and 302s to
 *      pocketcoder://oauth-callback?exchange_code=...&state=...
 *   4. App calls POST /claim {exchange_code, code_verifier}. This Worker
 *      verifies S256(code_verifier) == the code_challenge it decoded from
 *      `state` back in step 3, and only then releases + deletes the KV
 *      entry. This is PKCE's entire purpose in this flow — without it, the
 *      verifier the app generated is never checked by anything.
 *
 * GET /providers lists which providers currently have both a PROVIDERS
 * entry and live secrets configured — {id, displayName} only, nothing
 * else (see the provider-discovery spec's security review: this response
 * shape is a stated invariant, not an accident).
 *
 * `state` carries {p, cc} in plaintext (code_challenge is not secret —
 * RFC 7636 §4.2), built server-side at /authorize time now (previously
 * client-side — see the provider-discovery spec's security review for why
 * that's still safe, and why the Flutter client independently re-verifies
 * the `cc`/`p` it gets back before calling /claim, as defense in depth).
 */

const PROVIDERS = {
	github: {
		displayName: 'GitHub',
		authorizeUrl: 'https://github.com/login/oauth/authorize',
		tokenUrl: 'https://github.com/login/oauth/access_token',
		scope: 'repo read:user',
	},
};

const EXCHANGE_TTL_SECONDS = 60;
const CODE_CHALLENGE_PATTERN = /^[A-Za-z0-9_-]{43}$/;

export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		if (request.method === 'GET' && url.pathname === '/authorize') {
			return handleAuthorize(url, env);
		}
		if (request.method === 'GET' && url.pathname === '/providers') {
			return handleProviders(env);
		}
		if (request.method === 'GET' && url.pathname === '/callback') {
			return handleCallback(url, env);
		}
		if (request.method === 'POST' && url.pathname === '/claim') {
			return handleClaim(request, env);
		}
		return json({ status: 'ok', service: 'pocketcoder-oauth-relay' }, 200);
	},
};

// ---------------------------------------------------------------------------
// GET /providers
// ---------------------------------------------------------------------------

async function handleProviders(env) {
	const providers = [];
	for (const id of Object.keys(PROVIDERS)) {
		const envPrefix = id.toUpperCase();
		const clientId = env[`${envPrefix}_OAUTH_CLIENT_ID`];
		const clientSecret = env[`${envPrefix}_OAUTH_CLIENT_SECRET`];
		if (clientId && clientSecret) {
			// Response shape is a stated invariant: {id, displayName} only —
			// never authorizeUrl/tokenUrl/scope/client_id or any secret-presence
			// diagnostic. See the provider-discovery spec's security review.
			providers.push({ id, displayName: PROVIDERS[id].displayName });
		}
	}
	return json({ providers }, 200, { 'Cache-Control': 'public, max-age=60' });
}

// ---------------------------------------------------------------------------
// GET /authorize
// ---------------------------------------------------------------------------

async function handleAuthorize(url, env) {
	// Read only the two known params — never forward the inbound query
	// string wholesale (see the provider-discovery spec's security review,
	// required change #2): a smuggled duplicate redirect_uri/scope/
	// client_id must not be able to reach the outgoing URL.
	const providerId = url.searchParams.get('provider');
	const codeChallenge = url.searchParams.get('code_challenge');

	// Object.hasOwn, not a bare `PROVIDERS[providerId]` truthy check: plain
	// property lookup walks the JS prototype chain, so providerId values
	// like "constructor"/"toString"/"__proto__" would otherwise pass a
	// `!provider` guard (required change #1).
	if (!providerId || !Object.hasOwn(PROVIDERS, providerId)) {
		return redirectToApp({ error: 'unknown_provider' });
	}
	if (!codeChallenge || !CODE_CHALLENGE_PATTERN.test(codeChallenge)) {
		return redirectToApp({ error: 'invalid_code_challenge' });
	}

	const provider = PROVIDERS[providerId];
	const envPrefix = providerId.toUpperCase();
	const clientId = env[`${envPrefix}_OAUTH_CLIENT_ID`];
	if (!clientId) {
		console.error(`Missing OAuth client_id for provider ${providerId}`);
		return redirectToApp({ error: 'server_misconfigured' });
	}

	const state = base64urlEncode(JSON.stringify({ p: providerId, cc: codeChallenge }));
	const redirectUri = `${url.origin}/callback`;

	// Fresh URLSearchParams, .set() on exactly these known keys — never
	// `new URLSearchParams(url.searchParams)` (that would forward whatever
	// the caller sent, including anything beyond provider/code_challenge).
	const params = new URLSearchParams();
	params.set('client_id', clientId);
	params.set('response_type', 'code');
	params.set('redirect_uri', redirectUri);
	params.set('scope', provider.scope);
	params.set('state', state);
	params.set('code_challenge', codeChallenge);
	// Hardcoded server-side, never taken from the client (required change
	// #3) — /claim only ever computes S256, so accepting a client-supplied
	// method here would just be a lie about what's actually checked later.
	params.set('code_challenge_method', 'S256');

	const target = `${provider.authorizeUrl}?${params.toString()}`;
	return new Response(null, {
		status: 302,
		headers: { Location: target, 'Cache-Control': 'no-store' },
	});
}

// ---------------------------------------------------------------------------
// GET /callback
// ---------------------------------------------------------------------------

async function handleCallback(url, env) {
	const code = url.searchParams.get('code');
	const stateParam = url.searchParams.get('state');
	const providerError = url.searchParams.get('error');

	if (providerError) {
		return redirectToApp({ error: providerError });
	}
	if (!code || !stateParam) {
		return redirectToApp({ error: 'missing_code_or_state' });
	}

	const state = parseState(stateParam);
	if (!state || !state.p || !state.cc) {
		return redirectToApp({ error: 'invalid_state' });
	}

	// Object.hasOwn, not a bare `PROVIDERS[state.p]` truthy check — same
	// reasoning as handleAuthorize above (required change #1, backported
	// here even though this route predates the provider-discovery review).
	if (!Object.hasOwn(PROVIDERS, state.p)) {
		return redirectToApp({ error: `unknown_provider:${state.p}` });
	}
	const provider = PROVIDERS[state.p];

	const envPrefix = state.p.toUpperCase();
	const clientId = env[`${envPrefix}_OAUTH_CLIENT_ID`];
	const clientSecret = env[`${envPrefix}_OAUTH_CLIENT_SECRET`];
	if (!clientId || !clientSecret) {
		console.error(`Missing OAuth client credentials for provider ${state.p}`);
		return redirectToApp({ error: 'server_misconfigured' });
	}

	// Must exactly match the redirect_uri /authorize sent to the provider
	// (RFC 6749 §4.1.3).
	const redirectUri = `${url.origin}/callback`;

	let tokenResp;
	try {
		tokenResp = await fetch(provider.tokenUrl, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Accept: 'application/json',
			},
			body: JSON.stringify({
				client_id: clientId,
				client_secret: clientSecret,
				code,
				redirect_uri: redirectUri,
			}),
		});
	} catch (e) {
		console.error('Token exchange request failed:', e.message);
		return redirectToApp({ error: 'token_exchange_failed' });
	}

	const tokenBody = await tokenResp.json().catch(() => null);
	if (!tokenResp.ok || !tokenBody || tokenBody.error || !tokenBody.access_token) {
		console.error('Token exchange rejected:', tokenResp.status, JSON.stringify(tokenBody));
		return redirectToApp({ error: (tokenBody && tokenBody.error) || 'token_exchange_rejected' });
	}

	const exchangeCode = crypto.randomUUID();
	await env.MCP_OAUTH_KV.put(
		`exchange:${exchangeCode}`,
		JSON.stringify({
			codeChallenge: state.cc,
			accessToken: tokenBody.access_token,
			refreshToken: tokenBody.refresh_token || null,
		}),
		{ expirationTtl: EXCHANGE_TTL_SECONDS }
	);

	// Tokens never ride in this redirect URL — only the one-time
	// exchange_code does. See the base spec's Component 1.
	return redirectToApp({ exchange_code: exchangeCode, state: stateParam });
}

// ---------------------------------------------------------------------------
// POST /claim
// ---------------------------------------------------------------------------

async function handleClaim(request, env) {
	let body;
	try {
		body = await request.json();
	} catch (e) {
		return json({ error: 'invalid_json' }, 400);
	}

	const exchangeCode = body.exchange_code;
	const codeVerifier = body.code_verifier;
	if (!exchangeCode || !codeVerifier) {
		return json({ error: 'missing_exchange_code_or_code_verifier' }, 400);
	}

	const kvKey = `exchange:${exchangeCode}`;
	const raw = await env.MCP_OAUTH_KV.get(kvKey);
	if (!raw) {
		return json({ error: 'expired_or_already_claimed' }, 404);
	}
	const entry = JSON.parse(raw);

	const computedChallenge = await sha256Base64url(codeVerifier);

	// Delete on every outcome (match or mismatch), not just on success: a
	// single exchange_code must never be claimable twice, even by a retried
	// wrong verifier. Fail closed — this check is PKCE's entire purpose in
	// this flow.
	await env.MCP_OAUTH_KV.delete(kvKey);

	if (computedChallenge !== entry.codeChallenge) {
		return json({ error: 'verifier_mismatch' }, 400);
	}

	return json({ access_token: entry.accessToken, refresh_token: entry.refreshToken }, 200);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function redirectToApp(params) {
	const target = new URL('pocketcoder://oauth-callback');
	for (const [k, v] of Object.entries(params)) {
		if (v !== undefined && v !== null) target.searchParams.set(k, v);
	}
	return Response.redirect(target.toString(), 302);
}

function parseState(stateParam) {
	try {
		return JSON.parse(base64urlDecode(stateParam));
	} catch (e) {
		return null;
	}
}

function base64urlDecode(str) {
	const padLen = (4 - (str.length % 4)) % 4;
	const padded = str.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat(padLen);
	return atob(padded);
}

function base64urlEncode(str) {
	return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

async function sha256Base64url(input) {
	const data = new TextEncoder().encode(input);
	const digest = await crypto.subtle.digest('SHA-256', data);
	return arrayBufferToBase64url(digest);
}

function arrayBufferToBase64url(buffer) {
	const bytes = new Uint8Array(buffer);
	let binary = '';
	for (let i = 0; i < bytes.length; i++) {
		binary += String.fromCharCode(bytes[i]);
	}
	return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function json(data, status = 200, extraHeaders = {}) {
	return new Response(JSON.stringify(data), {
		status,
		headers: { 'Content-Type': 'application/json', ...extraHeaders },
	});
}
```

- [ ] **Step 2: Sanity-check the file parses**

Run (cwd `workers/oauth-relay`):
```bash
node --check src/index.js && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Local verification with `wrangler dev --local`**

Run (background, cwd `workers/oauth-relay` — `.dev.vars` already exists from the base plan's Task 1 with `GITHUB_OAUTH_CLIENT_ID=test-client-id` / `GITHUB_OAUTH_CLIENT_SECRET=test-client-secret`):
```bash
npx wrangler dev --local --port 8788 &
sleep 3
```

Run and check each:

```bash
curl -s http://127.0.0.1:8788/providers
```
Expected: `{"providers":[{"id":"github","displayName":"GitHub"}]}` (both fake `.dev.vars` secrets are present, so github shows up as "configured" even though the values are fake — `/providers` only checks presence, not validity).

```bash
CC=$(python3 -c "print('A'*43)")
curl -s -i "http://127.0.0.1:8788/authorize?provider=constructor&code_challenge=$CC"
```
Expected: `302` with `Location: pocketcoder://oauth-callback?error=unknown_provider` — proves the `Object.hasOwn` prototype-pollution guard (required change #1) actually rejects `constructor` rather than silently proceeding.

```bash
curl -s -i "http://127.0.0.1:8788/authorize?provider=github&code_challenge=too-short"
```
Expected: `302` with `Location: pocketcoder://oauth-callback?error=invalid_code_challenge`.

```bash
curl -s -i "http://127.0.0.1:8788/authorize?provider=github&code_challenge=$CC&redirect_uri=https://evil.example&scope=evil-scope"
```
Expected: `302` with `Location` starting `https://github.com/login/oauth/authorize?...` — grep the `Location` header for `evil` and confirm **zero matches** (proves required change #2: the extra `redirect_uri`/`scope` query params on the *inbound* request never reach the *outgoing* URL, since `/authorize` only reads `provider`/`code_challenge` and builds every other param itself).

```bash
curl -s -i "http://127.0.0.1:8788/authorize?provider=github&code_challenge=$CC" | grep -o 'code_challenge_method=[^&]*'
```
Expected: `code_challenge_method=S256` (proves required change #3 — hardcoded server-side regardless of whether the client sent one).

Stop the dev server:
```bash
kill %1
```

- [ ] **Step 4: Commit**

```bash
git add workers/oauth-relay/src/index.js
git commit -m "feat(oauth-relay): add /providers + /authorize routes, remove per-provider Flutter hardcoding"
```

---

### Task 2: Flutter `McpOAuthService` — provider discovery + `/authorize`-based flow

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart`
- Modify: `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart`

**Interfaces:**
- Consumes: `GET $relayBaseUrl/providers`, `GET $relayBaseUrl/authorize?provider&code_challenge` (Task 1).
- Produces: `IMcpOAuthService.supportedProviders() -> Future<List<McpOAuthProvider>>` where `McpOAuthProvider = ({String id, String displayName})`; `IMcpOAuthService.authenticate(String provider)` unchanged in signature, changed in implementation. Task 3's `McpCubit` is the only consumer of `supportedProviders()`.

- [ ] **Step 1: Add `McpOAuthException.stateMismatch()`**

In `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`, add to the existing `McpOAuthException` class's factory list (after `claimFailed`):
```dart
  factory McpOAuthException.stateMismatch() => McpOAuthException._(
      'OAuth state mismatch — possible spoofed callback', isCancelled: false);
```

- [ ] **Step 2: Update the interface**

Replace `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart` in full:
```dart
/// Result of a completed OAuth exchange: the access token the target MCP
/// server will use as its bearer/PAT credential, and (if the provider
/// issued one) a refresh token. Ephemeral — never persisted client-side.
typedef McpOAuthTokenPair = ({String accessToken, String? refreshToken});

/// A provider workers/oauth-relay currently has configured (both a
/// PROVIDERS entry and live wrangler secrets) — see
/// docs/superpowers/specs/2026-07-27-mcp-oauth-provider-discovery-design.md.
/// `displayName` is human-facing ("GitHub"); `id` is the opaque string
/// stored in McpServer.oauthProvider and passed to authenticate().
typedef McpOAuthProvider = ({String id, String displayName});

/// Client-side half of the MCP OAuth flow (see
/// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, Component
/// 2, as refined by the provider-discovery addendum). Runs the PKCE
/// authorize/browser/claim dance against workers/oauth-relay and hands
/// back the resulting token pair. This service is a courier, not a
/// holder: callers are responsible for delivering the returned token to
/// this user's own PocketBase (Component 3, via
/// IMcpRepository.deliverOAuthToken) — McpOAuthService never stores it (no
/// flutter_secure_storage use here, unlike LinodeOAuthService's
/// provisioning token, which belongs to the app's own session — this
/// token belongs to the user's gateway).
///
/// Deliberately holds **no** per-provider knowledge (no authorize URLs,
/// no scopes, no client_ids) — the Worker holds all of that server-side
/// and builds the authorize URL itself at GET /authorize time. Adding a
/// new OAuth provider is therefore a Worker-only change (one PROVIDERS
/// entry + one `wrangler secret put`), never a Flutter code change or app
/// release. See the provider-discovery spec's Problem section.
abstract class IMcpOAuthService {
  /// Returns the list of providers the Worker currently has configured
  /// (PROVIDERS entry + live secrets). Cached in-memory for the app
  /// session after the first successful fetch — a transient network
  /// failure must not poison the app session with an empty list.
  ///
  /// Callers (McpCubit) use this to gate the CONNECT button: a server
  /// whose oauthProvider isn't in this list should show a "not yet
  /// configured" state instead of launching a browser sheet that would
  /// fail after the fact.
  Future<List<McpOAuthProvider>> supportedProviders();

  /// Runs the full authorize -> browser -> claim flow for [provider] (e.g.
  /// "github") and returns the resulting token pair.
  ///
  /// Throws [McpOAuthException] on any failure, with `isCancelled: true`
  /// when the user dismissed the browser sheet.
  Future<McpOAuthTokenPair> authenticate(String provider);
}
```

- [ ] **Step 3: Write the failing tests**

Replace `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart` in full:
```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_oauth_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

/// Builds a Worker-shaped `state` param the way
/// workers/oauth-relay/src/index.js's handleAuthorize does, for tests
/// that need to simulate a well-formed provider callback.
String _encodeStateForTest({required String provider, required String codeChallenge}) {
  final json = jsonEncode({'p': provider, 'cc': codeChallenge});
  return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
}

void main() {
  late McpOAuthService service;
  late MockHttpClient httpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    httpClient = MockHttpClient();
    service = McpOAuthService(httpClient, 'https://relay.example.com');
  });

  group('PKCE helpers', () {
    test('generateCodeVerifier produces a 64-char unreserved-charset string', () {
      final v = McpOAuthService.generateCodeVerifier();
      expect(v.length, 64);
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v), isTrue);
    });

    test('generateCodeChallenge is deterministic S256 of the verifier', () {
      const verifier = 'fixed-test-verifier-value-1234567890';
      final a = McpOAuthService.generateCodeChallenge(verifier);
      final b = McpOAuthService.generateCodeChallenge(verifier);
      expect(a, b);
      expect(a, isNot(contains('=')));
    });

    test('decodeState round-trips a Worker-shaped state param', () {
      final state = _encodeStateForTest(provider: 'github', codeChallenge: 'abc123');
      final decoded = McpOAuthService.decodeState(state);
      expect(decoded, {'p': 'github', 'cc': 'abc123'});
    });

    test('decodeState returns null for malformed input', () {
      expect(McpOAuthService.decodeState('not-valid-base64url-json'), isNull);
    });
  });

  group('McpOAuthService.supportedProviders', () {
    test('fetches and parses the provider list, then caches it', () async {
      when(() => httpClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'providers': [
              {'id': 'github', 'displayName': 'GitHub'},
            ],
          }),
          200,
        ),
      );

      final first = await service.supportedProviders();
      final second = await service.supportedProviders();

      expect(first, [(id: 'github', displayName: 'GitHub')]);
      expect(second, first);
      verify(() => httpClient.get(any())).called(1); // second call served from cache
    });

    test('does not cache a failed fetch — a later call retries', () async {
      when(() => httpClient.get(any())).thenAnswer((_) async => http.Response('', 500));

      await expectLater(() => service.supportedProviders(), throwsA(isA<McpOAuthException>()));

      when(() => httpClient.get(any())).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'providers': [
              {'id': 'github', 'displayName': 'GitHub'},
            ],
          }),
          200,
        ),
      );
      final result = await service.supportedProviders();

      expect(result, [(id: 'github', displayName: 'GitHub')]);
      verify(() => httpClient.get(any())).called(2); // first (failed) + second (succeeded)
    });
  });

  group('McpOAuthService.authenticate', () {
    test('cancelled browser sheet surfaces isCancelled=true', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) {
        throw PlatformException(code: 'CANCELED');
      };

      try {
        await service.authenticate('github');
        fail('expected McpOAuthException');
      } on McpOAuthException catch (e) {
        expect(e.isCancelled, isTrue);
      }
    });

    test('provider error in the callback URL surfaces as McpOAuthException', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        return 'pocketcoder://oauth-callback?error=access_denied';
      };

      await expectLater(
        () => service.authenticate('github'),
        throwsA(isA<McpOAuthException>().having((e) => e.isCancelled, 'isCancelled', isFalse)),
      );
    });

    test('opens relayBaseUrl/authorize with provider and code_challenge — no local provider knowledge', () async {
      String? openedUrl;
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        openedUrl = url;
        final uri = Uri.parse(url);
        final codeChallenge = uri.queryParameters['code_challenge'] ?? '';
        final state = _encodeStateForTest(provider: 'github', codeChallenge: codeChallenge);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(jsonEncode({'access_token': 'tok', 'refresh_token': 'ref'}), 200));

      final pair = await service.authenticate('github');

      final uri = Uri.parse(openedUrl!);
      expect(uri.host, 'relay.example.com');
      expect(uri.path, '/authorize');
      expect(uri.queryParameters['provider'], 'github');
      expect(uri.queryParameters['code_challenge'], isNotEmpty);
      expect(pair.accessToken, 'tok');
      expect(pair.refreshToken, 'ref');
    });

    test('happy path calls /claim with the generated code_verifier and returns the token pair', () async {
      String? capturedBody;
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        final codeChallenge = uri.queryParameters['code_challenge'] ?? '';
        final state = _encodeStateForTest(provider: 'github', codeChallenge: codeChallenge);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as String;
        return http.Response(jsonEncode({'access_token': 'tok', 'refresh_token': 'ref'}), 200);
      });

      final pair = await service.authenticate('github');

      expect(pair.accessToken, 'tok');
      expect(pair.refreshToken, 'ref');
      final sentBody = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(sentBody['exchange_code'], 'xyz');
      expect(sentBody['code_verifier'], isNotEmpty);
    });

    test('state mismatch throws before calling /claim', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        // state decodes to a code_challenge that doesn't match what this
        // client generated — simulates a spoofed/mismatched deep link.
        final state = _encodeStateForTest(provider: 'github', codeChallenge: 'not-the-real-challenge');
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };

      await expectLater(() => service.authenticate('github'), throwsA(isA<McpOAuthException>()));
      verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('missing state throws before calling /claim', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        return 'pocketcoder://oauth-callback?exchange_code=xyz';
      };

      await expectLater(() => service.authenticate('github'), throwsA(isA<McpOAuthException>()));
      verifyNever(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')));
    });

    test('/claim non-200 response throws McpOAuthException', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        final codeChallenge = uri.queryParameters['code_challenge'] ?? '';
        final state = _encodeStateForTest(provider: 'github', codeChallenge: codeChallenge);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=$state';
      };
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(jsonEncode({'error': 'verifier_mismatch'}), 400));

      await expectLater(() => service.authenticate('github'), throwsA(isA<McpOAuthException>()));
    });
  });
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run (cwd `client/packages/pocketcoder_flutter`):
```bash
flutter test test/infrastructure/mcp/mcp_oauth_service_test.dart
```
Expected: fails to compile — `McpOAuthService(httpClient, 'https://relay.example.com')` doesn't match the current 3-argument constructor; `McpOAuthService.decodeState`/`supportedProviders` undefined.

- [ ] **Step 5: Implement `McpOAuthService`**

Replace `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart` in full:
```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';

/// Shape of FlutterWebAuth2.authenticate, injected so tests can substitute
/// a fake without a real platform channel — same call shape as
/// flutter_aeroform's LinodeOAuthService.authenticate(), but injected
/// directly rather than via that file's dynamic-import mocking hack.
typedef WebAuthLauncher = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});

/// Cloudflare-Worker-backed OAuth client for locally-run MCP catalog
/// servers that need a real user identity (GitHub today) rather than a
/// static API key. See i_mcp_oauth_service.dart's doc comment and
/// docs/superpowers/specs/2026-07-27-mcp-oauth-provider-discovery-design.md.
///
/// `provider` is a per-call argument, not a constructor argument — this
/// class is a DI singleton (registered once via @LazySingleton below,
/// matching every other single-implementation infrastructure class in
/// this package, e.g. AuthRepository/FilesRepository), so it can't be
/// constructed fresh per provider. It holds no per-provider config at all
/// (see the provider-discovery spec) — the Worker's GET /authorize route
/// builds the real authorize URL server-side, so this class only ever
/// needs the opaque provider id string.
@LazySingleton(as: IMcpOAuthService)
class McpOAuthService implements IMcpOAuthService {
  static const _callbackScheme = 'pocketcoder';

  final http.Client _httpClient;
  final String _relayBaseUrl;

  McpOAuthService(
    this._httpClient,
    @Named('mcpOAuthRelayBaseUrl') this._relayBaseUrl,
  );

  /// Overridable in tests only — production code always uses the real
  /// FlutterWebAuth2.authenticate.
  @visibleForTesting
  WebAuthLauncher webAuthLauncher = FlutterWebAuth2.authenticate;

  /// In-memory cache, populated on first successful supportedProviders()
  /// call. Never populated from a failed fetch — a transient network
  /// failure must not poison the app session with an empty list that
  /// silently disables every CONNECT button until restart.
  List<McpOAuthProvider>? _cachedProviders;

  @override
  Future<List<McpOAuthProvider>> supportedProviders() {
    return tryMethod(() async {
      final cached = _cachedProviders;
      if (cached != null) return cached;

      final resp = await _httpClient.get(Uri.parse('$_relayBaseUrl/providers'));
      if (resp.statusCode != 200) {
        throw McpOAuthException('Failed to fetch supported providers: ${resp.statusCode}');
      }
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final rawList = body['providers'] as List<dynamic>? ?? const [];
      final providers = rawList.map((raw) {
        final map = raw as Map<String, dynamic>;
        return (id: map['id'] as String, displayName: map['displayName'] as String);
      }).toList();

      _cachedProviders = providers;
      return providers;
    }, McpOAuthException.new, 'supportedProviders');
  }

  @override
  Future<McpOAuthTokenPair> authenticate(String provider) {
    return tryMethod(() async {
      final codeVerifier = generateCodeVerifier();
      final codeChallenge = generateCodeChallenge(codeVerifier);

      final authorizeUri = Uri.parse('$_relayBaseUrl/authorize').replace(queryParameters: {
        'provider': provider,
        'code_challenge': codeChallenge,
      });

      String callbackUrl;
      try {
        callbackUrl = await webAuthLauncher(
          url: authorizeUri.toString(),
          callbackUrlScheme: _callbackScheme,
        );
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') {
          throw McpOAuthException.cancelled();
        }
        throw McpOAuthException('Web auth failed: ${e.code}', e);
      }

      final callback = Uri.parse(callbackUrl);
      final providerError = callback.queryParameters['error'];
      if (providerError != null) {
        throw McpOAuthException.providerError(providerError);
      }
      final exchangeCode = callback.queryParameters['exchange_code'];
      if (exchangeCode == null || exchangeCode.isEmpty) {
        throw McpOAuthException('Worker callback missing exchange_code');
      }

      // Defense in depth: the Worker now builds `state` itself (see the
      // provider-discovery spec), so this client-side check doesn't
      // protect anything /claim's own PKCE verifier check doesn't already
      // cover — but it's free, catches a spoofed deep-link one hop
      // earlier, and restores the property `state` is normally for
      // (RFC 6749 §10.12: the initiator verifies the response corresponds
      // to its own request).
      final stateParam = callback.queryParameters['state'];
      final decodedState = stateParam == null ? null : decodeState(stateParam);
      if (decodedState == null ||
          decodedState['cc'] != codeChallenge ||
          decodedState['p'] != provider) {
        throw McpOAuthException.stateMismatch();
      }

      return _claim(exchangeCode: exchangeCode, codeVerifier: codeVerifier);
    }, McpOAuthException.new, 'authenticate');
  }

  Future<McpOAuthTokenPair> _claim({
    required String exchangeCode,
    required String codeVerifier,
  }) async {
    final resp = await _httpClient.post(
      Uri.parse('$_relayBaseUrl/claim'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'exchange_code': exchangeCode,
        'code_verifier': codeVerifier,
      }),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw McpOAuthException.claimFailed(body['error']);
    }
    final accessToken = body['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw McpOAuthException.claimFailed('missing access_token in /claim response');
    }
    return (accessToken: accessToken, refreshToken: body['refresh_token'] as String?);
  }

  /// PKCE code_verifier per RFC 7636: 43-128 chars, unreserved charset.
  @visibleForTesting
  static String generateCodeVerifier() {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// S256 code_challenge: SHA-256 of the verifier, base64url without
  /// padding — the same transform workers/oauth-relay's /claim route
  /// re-derives from the verifier the app sends back.
  @visibleForTesting
  static String generateCodeChallenge(String codeVerifier) {
    final hash = sha256.convert(utf8.encode(codeVerifier));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }

  /// Decodes the `state` param the Worker's GET /authorize route built
  /// (base64url(JSON.stringify({p, cc}))) — see
  /// workers/oauth-relay/src/index.js's handleAuthorize. Returns null
  /// on any malformed input rather than throwing, since this is used for
  /// a defense-in-depth equality check, not a required-to-succeed parse.
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
}
```

- [ ] **Step 6: Delete the dead `githubOAuthClientId` DI provider**

In `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart`, delete this block (it was `McpOAuthService`'s third constructor parameter, which no longer exists):
```dart
  /// client_id of the centrally-registered GitHub OAuth App (not secret —
  /// safe to embed, same as Linode's `linodeClientId` in flutter_aeroform).
  /// TODO(mcp-oauth): replace with the real GitHub OAuth App's client_id
  /// once Task 1 Step 4's registration step has happened.
  @Named('githubOAuthClientId')
  @lazySingleton
  String get githubOAuthClientId => 'REPLACE_WITH_REAL_GITHUB_OAUTH_CLIENT_ID';
```

- [ ] **Step 7: Run tests to verify they pass**

Run (cwd `client/packages/pocketcoder_flutter`):
```bash
flutter test test/infrastructure/mcp/mcp_oauth_service_test.dart
```
Expected: all tests PASS.

- [ ] **Step 8: Regenerate DI wiring**

Run (cwd `client/packages/pocketcoder_flutter`):
```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0; `lib/app/bootstrap.config.dart` now constructs `McpOAuthService` with 2 arguments and no longer registers `githubOAuthClientId`.

- [ ] **Step 9: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart client/packages/pocketcoder_flutter/lib/domain/exceptions.dart client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart
git commit -m "feat(mcp): McpOAuthService drops all per-provider hardcoding, uses Worker /authorize + /providers"
```

---

### Task 3: `McpCubit` passthrough + CONNECT button gating

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb` (+ regenerated localization files)
- Modify: `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart`

**Interfaces:**
- Consumes: `IMcpOAuthService.supportedProviders()` (Task 2).
- Produces: `McpCubit.supportedOAuthProviders() -> Future<List<McpOAuthProvider>>`. Nothing downstream of this task's UI change — it's the final, user-visible piece of this plan.

- [ ] **Step 1: Add the cubit passthrough**

No new import is needed: `mcp_cubit.dart` already has a plain (unqualified)
`import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';`
for `IMcpOAuthService`, and a plain import exposes every top-level symbol
in that file — including the `McpOAuthProvider` typedef Task 2 added to
it.

Add this method to the `McpCubit` class (after `hasPendingOAuthDelivery`):
```dart
  /// Thin passthrough to IMcpOAuthService.supportedProviders() (which
  /// caches in-memory after the first success) — exposed here so the UI
  /// layer never reaches into the oauth service directly, matching how
  /// this cubit already encapsulates _repository.
  Future<List<McpOAuthProvider>> supportedOAuthProviders() =>
      _oauthService.supportedProviders();
```

- [ ] **Step 2: Write the failing cubit test**

In `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart`, add:
```dart
  group('McpCubit.supportedOAuthProviders', () {
    test('delegates to IMcpOAuthService.supportedProviders', () async {
      when(() => oauthService.supportedProviders())
          .thenAnswer((_) async => [(id: 'github', displayName: 'GitHub')]);

      final cubit = buildCubit();
      final result = await cubit.supportedOAuthProviders();

      expect(result, [(id: 'github', displayName: 'GitHub')]);
      verify(() => oauthService.supportedProviders()).called(1);
    });
  });
```

- [ ] **Step 3: Run to verify it fails**

Run (cwd `client/packages/pocketcoder_flutter`):
```bash
flutter test test/application/mcp/mcp_cubit_test.dart
```
Expected: compile error — `supportedOAuthProviders` undefined on `McpCubit`.

- [ ] **Step 4: Run to verify it passes**

(Step 1 already implements the method — this just confirms.) Run:
```bash
flutter test test/application/mcp/mcp_cubit_test.dart
```
Expected: all tests PASS, including the new one.

- [ ] **Step 5: Add the l10n key**

In `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`, add immediately after the existing `mcpOauthTokenEnvVarOptionalLabel` entry:
```json
  "mcpOauthTokenEnvVarOptionalLabel": "OAUTH TOKEN ENV VAR (OPTIONAL)",
  "mcpOauthProviderNotConfiguredLabel": "{provider} NOT YET CONFIGURED",
  "@mcpOauthProviderNotConfiguredLabel": {
    "placeholders": {
      "provider": { "type": "String" }
    }
  },
```
(the first line is the existing entry, shown for placement context — only the two new lines/block after it are additions.)

- [ ] **Step 6: Regenerate localization files**

Run (cwd `client/packages/pocketcoder_flutter`):
```bash
flutter gen-l10n
```
Expected: exits 0; `lib/l10n/app_localizations.dart`/`app_localizations_en.dart` now expose `mcpOauthProviderNotConfiguredLabel`.

- [ ] **Step 7: Wire the CONNECT/RETRY block to gate on `supportedOAuthProviders()`**

In `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart`, add this import (alongside the existing `mcp_cubit.dart`/`mcp_state.dart`/`mcp_server.dart` imports):
```dart
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
```

Replace this block (the `if (server.oauthProvider?.isNotEmpty == true) ...[` branch inside `_buildMcpItem`, currently spanning from its `VSpace.x1` opener through the `BlocBuilder<McpCubit, McpState>(...)` close and the branch's closing `],`):
```dart
          if (server.oauthProvider?.isNotEmpty == true) ...[
            VSpace.x1,
            TerminalText.mini(
              context.l10n.mcpOauthRequiredLabel(server.oauthProvider ?? ''),
              color: colors.primary,
              alpha: 0.8,
            ),
            VSpace.x1,
            BlocBuilder<McpCubit, McpState>(
              builder: (context, _) {
                final cubit = context.read<McpCubit>();
                final pendingRetry = cubit.hasPendingOAuthDelivery(server.id);
                return Row(
                  children: [
                    Expanded(
                      child: TerminalButton(
                        label: pendingRetry
                            ? context.l10n.mcpRetryDeliveryCap
                            : context.l10n.mcpConnectCap,
                        onTap: () => pendingRetry
                            ? cubit.retryOAuthDelivery(server.id)
                            : cubit.connectOAuth(server),
                      ),
                    ),
                    if (server.status != McpServerStatus.pending) ...[
                      HSpace.x2,
                      TerminalButton(
                        label: context.l10n.mcpRevoke,
                        onTap: () => cubit.deny(server.id),
                        color: colors.error,
                      ),
                    ],
                  ],
                );
              },
            ),
          ] else if (isPending) ...[
```
with:
```dart
          if (server.oauthProvider?.isNotEmpty == true) ...[
            VSpace.x1,
            FutureBuilder<List<McpOAuthProvider>>(
              future: context.read<McpCubit>().supportedOAuthProviders(),
              builder: (context, snapshot) {
                final providers = snapshot.data;
                McpOAuthProvider? matched;
                for (final p in providers ?? const <McpOAuthProvider>[]) {
                  if (p.id == server.oauthProvider) {
                    matched = p;
                    break;
                  }
                }
                // Fail open while loading/erroring: only treat a provider
                // as unsupported once we've heard back successfully and it
                // genuinely isn't in the list — never block on a slow or
                // failed /providers fetch. This gate is a UX nicety, not a
                // security boundary — every authoritative check still
                // happens server-side at /authorize time regardless. See
                // docs/superpowers/specs/2026-07-27-mcp-oauth-provider-discovery-design.md.
                final knownUnsupported = snapshot.connectionState == ConnectionState.done &&
                    providers != null &&
                    matched == null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TerminalText.mini(
                      context.l10n.mcpOauthRequiredLabel(matched?.displayName ?? server.oauthProvider ?? ''),
                      color: colors.primary,
                      alpha: 0.8,
                    ),
                    VSpace.x1,
                    if (knownUnsupported)
                      TerminalText.mini(
                        context.l10n.mcpOauthProviderNotConfiguredLabel(server.oauthProvider ?? ''),
                        color: colors.error,
                        alpha: 0.8,
                      )
                    else
                      BlocBuilder<McpCubit, McpState>(
                        builder: (context, _) {
                          final cubit = context.read<McpCubit>();
                          final pendingRetry = cubit.hasPendingOAuthDelivery(server.id);
                          return Row(
                            children: [
                              Expanded(
                                child: TerminalButton(
                                  label: pendingRetry
                                      ? context.l10n.mcpRetryDeliveryCap
                                      : context.l10n.mcpConnectCap,
                                  onTap: () => pendingRetry
                                      ? cubit.retryOAuthDelivery(server.id)
                                      : cubit.connectOAuth(server),
                                ),
                              ),
                              if (server.status != McpServerStatus.pending) ...[
                                HSpace.x2,
                                TerminalButton(
                                  label: context.l10n.mcpRevoke,
                                  onTap: () => cubit.deny(server.id),
                                  color: colors.error,
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ] else if (isPending) ...[
```

- [ ] **Step 8: Static analysis**

Run (cwd `client/packages/pocketcoder_flutter`):
```bash
flutter analyze lib/presentation/mcp/mcp_management_screen.dart lib/application/mcp/mcp_cubit.dart
```
Expected: `No issues found!`

- [ ] **Step 9: Full test suite for the MCP feature**

Run (cwd `client/packages/pocketcoder_flutter`):
```bash
flutter test test/application/mcp/ test/infrastructure/mcp/
```
Expected: all tests PASS (this task adds no new widget-test file, matching `McpManagementScreen`'s existing test coverage — manual verification is via the `run` skill against a live deployment once Task 1's Worker is redeployed).

- [ ] **Step 10: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart client/packages/pocketcoder_flutter/lib/l10n/app_en.arb client/packages/pocketcoder_flutter/lib/l10n/app_localizations.dart client/packages/pocketcoder_flutter/lib/l10n/app_localizations_en.dart client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart
git commit -m "feat(mcp): gate CONNECT button on Worker-reported provider support, show display names"
```
