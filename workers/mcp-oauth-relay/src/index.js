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
 * Flow (see the spec's Architecture diagram):
 *   1. App builds an authorize URL itself (this Worker never does) with a
 *      PKCE code_challenge folded into `state` and redirect_uri = this
 *      Worker's own /callback URL, then opens it in a browser sheet.
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
 * No `/start` route: `state` opaquely carries the code_challenge in
 * plaintext (it is not secret — RFC 7636 §4.2), decoded only here, at
 * /callback time. See this plan's Global Constraints, Decision 1, for why
 * that's safe and why it avoids an extra pre-redirect round trip.
 */

const PROVIDERS = {
	github: {
		tokenUrl: 'https://github.com/login/oauth/access_token',
	},
};

const EXCHANGE_TTL_SECONDS = 60;

export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		if (request.method === 'GET' && url.pathname === '/callback') {
			return handleCallback(url, env);
		}
		if (request.method === 'POST' && url.pathname === '/claim') {
			return handleClaim(request, env);
		}
		return json({ status: 'ok', service: 'pocketcoder-mcp-oauth-relay' }, 200);
	},
};

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

	const provider = PROVIDERS[state.p];
	if (!provider) {
		return redirectToApp({ error: `unknown_provider:${state.p}` });
	}

	const envPrefix = state.p.toUpperCase();
	const clientId = env[`${envPrefix}_OAUTH_CLIENT_ID`];
	const clientSecret = env[`${envPrefix}_OAUTH_CLIENT_SECRET`];
	if (!clientId || !clientSecret) {
		console.error(`Missing OAuth client credentials for provider ${state.p}`);
		return redirectToApp({ error: 'server_misconfigured' });
	}

	// Must exactly match the redirect_uri the app sent to the provider at
	// authorize time (RFC 6749 §4.1.3) — the app builds it the same way:
	// `${relayBaseUrl}/callback`.
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
	// exchange_code does. See the spec's Component 1.
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

function json(data, status = 200) {
	return new Response(JSON.stringify(data), {
		status,
		headers: { 'Content-Type': 'application/json' },
	});
}