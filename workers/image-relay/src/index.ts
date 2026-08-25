/**
 * PocketCoder Image Relay Worker
 *
 * Serves the /v1/* release-distribution API.
 */

import { verifyCredential, verifyProof } from './verify.ts';
import { rfc7638Thumbprint } from './crypto.ts';

interface Env {
	IMAGES: R2Bucket;
	SUPABASE_URL: string;
	SUPABASE_SERVICE_KEY: string;
	REVENUECAT_SECRET_KEY: string;
	REVENUECAT_PROJECT_ID: string;
}

const CORS_HEADERS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
	'Access-Control-Allow-Headers': 'Content-Type, Pocketcoder-Credential, Pocketcoder-Proof',
};

const PREMIUM_LOOKUP_KEY = 'PocketCoder Pro';
let entitlementIdCache: { id: string | null; expiry: number } = { id: null, expiry: 0 };

async function getPremiumEntitlementId(env: Env): Promise<string> {
	if (entitlementIdCache.id && Date.now() < entitlementIdCache.expiry) return entitlementIdCache.id;
	const resp = await fetch(
		`https://api.revenuecat.com/v2/projects/${env.REVENUECAT_PROJECT_ID}/entitlements`,
		{ headers: { Authorization: `Bearer ${env.REVENUECAT_SECRET_KEY}`, 'Content-Type': 'application/json' } },
	);
	if (!resp.ok) throw new Error(`Failed to list RevenueCat entitlements: ${resp.status}`);
	const data = (await resp.json()) as { items?: { id: string; lookup_key: string }[] };
	const entitlement = (data.items || []).find((e) => e.lookup_key === PREMIUM_LOOKUP_KEY);
	if (!entitlement) throw new Error(`No RevenueCat entitlement with lookup_key "${PREMIUM_LOOKUP_KEY}"`);
	entitlementIdCache = { id: entitlement.id, expiry: Date.now() + 3_600_000 };
	return entitlement.id;
}

async function checkSubscription(userId: string, env: Env): Promise<boolean> {
	const cacheKey = new Request(`https://ir-cache-v1.internal/${encodeURIComponent(userId)}`);
	const cache = (caches as unknown as { default: Cache }).default;
	const cached = await cache.match(cacheKey);
	if (cached) return ((await cached.json()) as { isPremium: boolean }).isPremium;
	if (!env.REVENUECAT_SECRET_KEY) {
		console.error('REVENUECAT_SECRET_KEY is not configured -- denying');
		return false;
	}
	try {
		const premiumEntitlementId = await getPremiumEntitlementId(env);
		const resp = await fetch(
			`https://api.revenuecat.com/v2/projects/${env.REVENUECAT_PROJECT_ID}/customers/${encodeURIComponent(userId)}/active_entitlements`,
			{ headers: { Authorization: `Bearer ${env.REVENUECAT_SECRET_KEY}`, 'Content-Type': 'application/json' } },
		);
		if (resp.status === 404) return false;
		if (!resp.ok) {
			console.error(`RevenueCat returned ${resp.status} for user ${userId}`);
			return false;
		}
		const data = (await resp.json()) as { items?: { entitlement_id: string; expires_at: number | null }[] };
		const isPremium = (data.items || []).some(
			(e) => e.entitlement_id === premiumEntitlementId && (e.expires_at == null || e.expires_at > Date.now()),
		);
		await cache.put(cacheKey, new Response(JSON.stringify({ isPremium }), {
			headers: { 'Content-Type': 'application/json', 'Cache-Control': 'max-age=300' },
		}));
		return isPremium;
	} catch (e) {
		console.error('RevenueCat check failed:', (e as Error).message);
		return false;
	}
}

async function isRevoked(jti: string, env: Env): Promise<boolean> {
	const cacheKey = new Request(`https://ir-revoke-cache-v1.internal/${encodeURIComponent(jti)}`);
	const cache = (caches as unknown as { default: Cache }).default;
	const cached = await cache.match(cacheKey);
	if (cached) return ((await cached.json()) as { revoked: boolean }).revoked;
	const resp = await fetch(
		`${env.SUPABASE_URL}/rest/v1/image_relay_revocations?jti=eq.${encodeURIComponent(jti)}&select=jti`,
		{ headers: { apikey: env.SUPABASE_SERVICE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}` } },
	);
	if (!resp.ok) {
		console.error(`Revocation lookup failed: HTTP ${resp.status}`);
		return true;
	}
	const rows = (await resp.json()) as unknown[];
	const revoked = rows.length > 0;
	await cache.put(cacheKey, new Response(JSON.stringify({ revoked }), {
		headers: { 'Content-Type': 'application/json', 'Cache-Control': 'max-age=300' },
	}));
	return revoked;
}

async function recordRevocation(jti: string, env: Env): Promise<void> {
	const resp = await fetch(`${env.SUPABASE_URL}/rest/v1/image_relay_revocations`, {
		method: 'POST',
		headers: { apikey: env.SUPABASE_SERVICE_KEY, Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`, 'Content-Type': 'application/json', Prefer: 'resolution=ignore-duplicates' },
		body: JSON.stringify({ jti }),
	});
	if (!resp.ok) throw new Error(`Failed to record revocation: HTTP ${resp.status}`);
}

async function checkAndRecordProofJti(keyThumbprint: string, proofJti: string): Promise<boolean> {
	const cacheKey = new Request(`https://ir-replay-cache-v1.internal/${keyThumbprint}/${proofJti}`);
	const cache = (caches as unknown as { default: Cache }).default;
	if (await cache.match(cacheKey)) return false;
	await cache.put(cacheKey, new Response('1', { headers: { 'Cache-Control': 'max-age=120' } }));
	return true;
}

const TRUSTED_ORIGIN = 'https://images.relay.pocketcoder.org';
async function authorizeRequest(request: Request, env: Env): Promise<
	{ ok: true; iss: string; boxJwk: import('./crypto.ts').P256PublicJwk; proofJti: string; targetJti?: string } |
	{ ok: false; status: number; error: string }
> {
	const credentialHeader = request.headers.get('Pocketcoder-Credential');
	const proofHeader = request.headers.get('Pocketcoder-Proof');
	if (!credentialHeader || !proofHeader) return { ok: false, status: 401, error: 'Missing credential or proof' };
	let credential;
	try { credential = await verifyCredential(credentialHeader); }
	catch (e) { return { ok: false, status: 401, error: `Invalid credential: ${(e as Error).message}` }; }
	if (await isRevoked(credential.jti, env)) return { ok: false, status: 403, error: 'Credential revoked' };
	const expectedUrl = `${TRUSTED_ORIGIN}${new URL(request.url).pathname}`;
	let proof;
	try { proof = await verifyProof(proofHeader, credential.boxJwk, request.method, expectedUrl, Math.floor(Date.now() / 1000)); }
	catch (e) { return { ok: false, status: 401, error: `Invalid proof: ${(e as Error).message}` }; }
	const boxThumbprint = await rfc7638Thumbprint(credential.boxJwk);
	if (!(await checkAndRecordProofJti(boxThumbprint, proof.jti))) return { ok: false, status: 401, error: 'Proof jti already used (replay)' };
	if (!(await checkSubscription(credential.iss, env))) return { ok: false, status: 403, error: 'Subscription required' };
	return { ok: true, iss: credential.iss, boxJwk: credential.boxJwk, proofJti: proof.jti, targetJti: proof.targetJti };
}

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		if (request.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS });

		const url = new URL(request.url);
		if (url.pathname === '/v1/health' && request.method === 'GET') {
			return json({ status: 'ok', service: 'pocketcoder-image-relay', apiVersion: 1 });
		}
		if (request.method === 'GET' || request.method === 'HEAD') {
			const objectPath = resolveV1ObjectPath(url.pathname);
			if (objectPath) {
				const auth = await authorizeRequest(request, env);
				if (!auth.ok) return json({ error: auth.error }, auth.status);
				return handleV1Object(env, objectPath, request.method === 'HEAD');
			}
		}
		if (url.pathname === '/v1/revoke' && request.method === 'POST') {
			const auth = await authorizeRequest(request, env);
			if (!auth.ok) return json({ error: auth.error }, auth.status);
			const credentialHeader = request.headers.get('Pocketcoder-Credential')!;
			const credential = await verifyCredential(credentialHeader);
			if (!credential.isSelfIssued) return json({ error: 'Only a root credential may revoke' }, 403);
			let body: { jti?: string };
			try {
				body = (await request.json()) as { jti?: string };
			} catch {
				return json({ error: 'Invalid JSON body' }, 400);
			}
			if (!body.jti || body.jti !== auth.targetJti) {
				return json({ error: 'target_jti in proof must match jti in body' }, 400);
			}
			await recordRevocation(body.jti, env);
			return json({ status: 'revoked' }, 200);
		}
		if (url.pathname === '/health' && request.method === 'GET') {
			return json({ status: 'ok', service: 'pocketcoder-image-relay' });
		}
		return json({ error: 'Not found' }, 404);
	},
};

type ReleaseObject = {
	key: string;
	contentType: string;
	immutable: boolean;
};

function resolveV1ObjectPath(pathname: string): ReleaseObject | null {
	// The `-testing` suffix is a separate, parallel channel-pointer path for
	// the staging branch pipeline (see internal/release/resolver.go's
	// ChannelPath) -- kept as its own literal alternative, not a generic
	// suffix pattern, since GitHubVerifier.Verify only ever trusts
	// attestations published from "main" or "staging".
	const mutable = [
		/^\/v1\/channels\/(stable|beta|nightly)(-testing)?\.json$/,
		/^\/v1\/revocations\/releases\.json$/,
	];
	const immutable = [
		/^\/v1\/attestations\/channels\/(stable|beta|nightly)(-testing)?\/[1-9][0-9]*\.sigstore\.json$/,
		/^\/v1\/releases\/[0-9a-f]{64}\.json$/,
		/^\/v1\/attestations\/releases\/[0-9a-f]{64}\.sigstore\.json$/,
		/^\/v1\/attestations\/revocations\/releases\/[1-9][0-9]*\.sigstore\.json$/,
		/^\/v1\/documents\/[0-9a-f]{64}\.(?:json|txt|sh|go)$/,
		/^\/v1\/artifacts\/[0-9a-f]{64}\.(?:tar\.gz|img\.gz)$/,
	];

	if (mutable.some((pattern) => pattern.test(pathname))) {
		return {
			key: pathname.slice('/v1/'.length),
			contentType: 'application/json',
			immutable: false,
		};
	}
	if (immutable.some((pattern) => pattern.test(pathname))) {
		return {
			key: pathname.slice('/v1/'.length),
			contentType: contentTypeFor(pathname),
			immutable: true,
		};
	}
	return null;
}

function contentTypeFor(pathname: string): string {
	if (pathname.endsWith('.sh')) return 'text/x-shellscript; charset=utf-8';
	if (pathname.endsWith('.go')) return 'text/x-go; charset=utf-8';
	if (pathname.endsWith('.txt')) return 'text/plain; charset=utf-8';
	if (pathname.endsWith('.tar.gz') || pathname.endsWith('.img.gz')) {
		return 'application/gzip';
	}
	return 'application/json';
}

// headOnly uses R2's own head() (metadata only, no body transfer) rather
// than fetching and discarding get()'s body -- this is what publish/
// promotion tooling polls with to confirm an object is live without
// paying for a multi-GB download each check.
function objectHeaders(path: ReleaseObject, object: R2Object): HeadersInit {
	return {
		...CORS_HEADERS,
		'Content-Type': path.contentType,
		'Content-Length': object.size.toString(),
		'Cache-Control': path.immutable
			? 'public, max-age=31536000, immutable'
			: 'public, max-age=300, must-revalidate',
		ETag: object.httpEtag,
	};
}

async function handleV1Object(
	env: Env,
	path: ReleaseObject,
	headOnly: boolean,
): Promise<Response> {
	if (headOnly) {
		const object = await env.IMAGES.head(path.key);
		if (!object) return json({ error: 'Release object unavailable' }, 404);
		return new Response(null, { status: 200, headers: objectHeaders(path, object) });
	}

	const object = await env.IMAGES.get(path.key);
	if (!object) return json({ error: 'Release object unavailable' }, 404);
	return new Response(object.body, { status: 200, headers: objectHeaders(path, object) });
}

function json(data: unknown, status = 200): Response {
	return new Response(JSON.stringify(data), {
		status,
		headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
	});
}
