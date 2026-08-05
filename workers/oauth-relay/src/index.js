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
	linode: {
		displayName: 'Linode',
		authorizeUrl: 'https://login.linode.com/oauth/authorize',
		tokenUrl: 'https://login.linode.com/oauth/token',
		// Matches flutter_aeroform's LinodeOAuthService._requiredScopes --
		// keep these in sync if that list ever changes.
		scope: 'linodes:read_write linodes:create images:read_write',
		// Confirmed via a direct curl during this investigation: Linode's
		// token endpoint parses form-urlencoded bodies. Whether it also
		// accepts JSON is untested -- default to the confirmed-working
		// format.
		tokenBodyFormat: 'form',
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
		if (request.method === 'POST' && url.pathname === '/refresh') {
			return handleRefresh(request, env);
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

	// Default to true when absent (GitHub currently relies on PKCE; we don't
	// want to silently regress it). A provider that explicitly sets
	// usePkceUpstream: false opts out of upstream-side PKCE params.
	const usePkceUpstream = provider.usePkceUpstream !== false;

	// Fresh URLSearchParams, .set() on exactly these known keys — never
	// `new URLSearchParams(url.searchParams)` (that would forward whatever
	// the caller sent, including anything beyond provider/code_challenge).
	const params = new URLSearchParams();
	params.set('client_id', clientId);
	params.set('response_type', 'code');
	params.set('redirect_uri', redirectUri);
	params.set('scope', provider.scope);
	params.set('state', state);
	if (usePkceUpstream) {
		params.set('code_challenge', codeChallenge);
		// Hardcoded server-side, never taken from the client (required change
		// #3) — /claim only ever computes S256, so accepting a client-supplied
		// method here would just be a lie about what's actually checked later.
		params.set('code_challenge_method', 'S256');
	}

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

	const tokenBody = await tokenResp.json().catch(() => null);
	if (!tokenResp.ok || !tokenBody || tokenBody.error || !tokenBody.access_token) {
		console.error('Token exchange rejected:', tokenResp.status, JSON.stringify(tokenBody));
		return redirectToApp({ error: (tokenBody && tokenBody.error) || 'token_exchange_rejected' });
	}

	const exchangeCode = crypto.randomUUID();
	await env.OAUTH_RELAY_KV.put(
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
	const raw = await env.OAUTH_RELAY_KV.get(kvKey);
	if (!raw) {
		return json({ error: 'expired_or_already_claimed' }, 404);
	}
	const entry = JSON.parse(raw);

	const computedChallenge = await sha256Base64url(codeVerifier);

	// Delete on every outcome (match or mismatch), not just on success: a
	// single exchange_code must never be claimable twice, even by a retried
	// wrong verifier. Fail closed — this check is PKCE's entire purpose in
	// this flow.
	await env.OAUTH_RELAY_KV.delete(kvKey);

	if (computedChallenge !== entry.codeChallenge) {
		return json({ error: 'verifier_mismatch' }, 400);
	}

	return json({
		access_token: entry.accessToken,
		refresh_token: entry.refreshToken,
		expires_in: entry.expiresIn,
		scope: entry.scope,
	}, 200);
}

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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function buildTokenRequestBody(format, fields) {
	if (format === 'form') {
		return {
			body: new URLSearchParams(fields).toString(),
			contentType: 'application/x-www-form-urlencoded',
		};
	}
	return { body: JSON.stringify(fields), contentType: 'application/json' };
}

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
