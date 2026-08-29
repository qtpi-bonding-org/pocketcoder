// End-to-end tests for the actual `fetch` handler: real signed
// credentials/proofs hitting mocked R2/RevenueCat/Supabase, so these catch
// wiring bugs (wrong header checked, gate skipped, cache used wrong) that
// unit tests on verify.ts alone cannot see.
import { describe, expect, it, vi } from 'vitest';
import worker from '../src/index.ts';
import { rfc7638Thumbprint } from '../src/crypto.ts';
import { generateP256Pair, signCompactJws, type Jwk } from './helpers.ts';

const AUDIENCE = 'https://images.relay.pocketcoder.org';

class FakeCache {
	store = new Map<string, Response>();
	async match(req: Request | string): Promise<Response | undefined> {
		const url = typeof req === 'string' ? req : req.url;
		const hit = this.store.get(url);
		return hit ? hit.clone() : undefined;
	}
	async put(req: Request | string, res: Response): Promise<void> {
		const url = typeof req === 'string' ? req : req.url;
		this.store.set(url, res.clone());
	}
}

function makeEnv(overrides: Partial<{ isPremium: boolean; revoked: boolean; r2Body: string | null }> = {}) {
	const isPremium = overrides.isPremium ?? true;
	const revoked = overrides.revoked ?? false;
	const r2Body = overrides.r2Body === undefined ? 'fake-object-bytes' : overrides.r2Body;

	const IMAGES = {
		async get(key: string) {
			if (r2Body === null) return null;
			return { body: r2Body, size: r2Body.length, httpEtag: '"etag"' };
		},
		async head(key: string) {
			if (r2Body === null) return null;
			return { size: r2Body.length, httpEtag: '"etag"' };
		},
	};

	return {
		IMAGES,
		SUPABASE_URL: 'https://fake.supabase.co',
		SUPABASE_SERVICE_KEY: 'fake-service-key',
		REVENUECAT_SECRET_KEY: 'fake-rc-key',
		REVENUECAT_PROJECT_ID: 'proj_fake',
		__isPremium: isPremium,
		__revoked: revoked,
	} as unknown as Parameters<typeof worker.fetch>[1] & { __isPremium: boolean; __revoked: boolean };
}

function installFetchMock(env: ReturnType<typeof makeEnv>) {
	const recordedRevocations: string[] = [];
	vi.stubGlobal(
		'fetch',
		vi.fn(async (input: RequestInfo | URL, init?: RequestInit) => {
			const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : (input as Request).url;
			if (url.includes('api.revenuecat.com') && url.includes('/entitlements')) {
				return new Response(JSON.stringify({ items: [{ id: 'ent_premium', lookup_key: 'PocketCoder Pro' }] }), { status: 200 });
			}
			if (url.includes('api.revenuecat.com') && url.includes('/active_entitlements')) {
				if (!(env as any).__isPremium) return new Response(JSON.stringify({ items: [] }), { status: 200 });
				return new Response(
					JSON.stringify({ items: [{ entitlement_id: 'ent_premium', expires_at: null }] }),
					{ status: 200 },
				);
			}
			if (url.includes('image_relay_revocations') && (!init || init.method === undefined || init.method === 'GET')) {
				return new Response(JSON.stringify((env as any).__revoked ? [{ jti: 'x' }] : []), { status: 200 });
			}
			if (url.includes('image_relay_revocations') && init?.method === 'POST') {
				recordedRevocations.push(JSON.parse(init.body as string).jti);
				return new Response('{}', { status: 201 });
			}
			throw new Error(`Unmocked fetch: ${url}`);
		}),
	);
	return recordedRevocations;
}

async function buildCredentialAndProof(opts: { method: string; url: string; selfIssued?: boolean }) {
	const root = await generateP256Pair();
	const box = opts.selfIssued ? root : await generateP256Pair();
	const rootThumbprint = await rfc7638Thumbprint(root.jwk);

	const credHeader = { alg: 'ES256', typ: 'pocketcoder-box-cert+jwt', jwk: root.jwk };
	const credClaims = {
		iss: rootThumbprint,
		aud: AUDIENCE,
		iat: 1735689600,
		jti: 'dGVzdC1jcmVkLWp0aQ',
		cnf: { jwk: box.jwk },
	};
	const credential = await signCompactJws(root.privateKey, credHeader, credClaims);

	const proofHeader = { alg: 'ES256', typ: 'dpop+jwt', jwk: box.jwk };
	async function buildProof(jti: string, targetJti?: string) {
		const claims: Record<string, unknown> = { htm: opts.method, htu: opts.url, iat: Math.floor(Date.now() / 1000), jti };
		if (targetJti) claims.target_jti = targetJti;
		return signCompactJws(box.privateKey, proofHeader, claims);
	}

	return { credential, buildProof, rootThumbprint, boxJwk: box.jwk as Jwk };
}

describe('fetch handler: GET object', () => {
	it('serves a listed object when credential+proof+entitlement all check out', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv({ isPremium: true });
		installFetchMock(env);
		const url = `${AUDIENCE}/v1/channels/stable.json`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'GET', url });
		const req = new Request(url, {
			headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': await buildProof('dGVzdC1wcm9vZi1qdGk-1') },
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(200);
	});

	it('rejects with 401 when both auth headers are missing', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv();
		const res = await worker.fetch(new Request(`${AUDIENCE}/v1/channels/stable.json`), env);
		expect(res.status).toBe(401);
	});

	it('rejects with 401 on a credential with an invalid signature', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv();
		installFetchMock(env);
		const url = `${AUDIENCE}/v1/channels/stable.json`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'GET', url });
		const tampered = credential.slice(0, -4) + 'XXXX';
		const req = new Request(url, {
			headers: { 'Pocketcoder-Credential': tampered, 'Pocketcoder-Proof': await buildProof('dGVzdC1wcm9vZi1qdGk-2') },
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(401);
	});

	it('rejects with 403 when the credential jti is revoked', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv({ revoked: true });
		installFetchMock(env);
		const url = `${AUDIENCE}/v1/channels/stable.json`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'GET', url });
		const req = new Request(url, {
			headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': await buildProof('dGVzdC1wcm9vZi1qdGk-3') },
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(403);
	});

	it('rejects with 403 when RevenueCat reports no active entitlement (not subscribed)', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv({ isPremium: false });
		installFetchMock(env);
		const url = `${AUDIENCE}/v1/channels/stable.json`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'GET', url });
		const req = new Request(url, {
			headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': await buildProof('dGVzdC1wcm9vZi1qdGk-4') },
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(403);
	});

	it('fails closed (denies) when the RevenueCat entitlement lookup itself errors', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv();
		vi.stubGlobal(
			'fetch',
			vi.fn(async (input: RequestInfo | URL) => {
				const url = typeof input === 'string' ? input : (input as URL | Request).toString();
				if (url.includes('api.revenuecat.com')) return new Response('boom', { status: 500 });
				if (url.includes('image_relay_revocations')) return new Response('[]', { status: 200 });
				throw new Error(`Unmocked fetch: ${url}`);
			}),
		);
		const url = `${AUDIENCE}/v1/channels/stable.json`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'GET', url });
		const req = new Request(url, {
			headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': await buildProof('dGVzdC1wcm9vZi1qdGk-5') },
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(403);
	});

	it('rejects a replayed proof jti on the second request for the same box key', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv({ isPremium: true });
		installFetchMock(env);
		const url = `${AUDIENCE}/v1/channels/stable.json`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'GET', url });
		const proof = await buildProof('dGVzdC1wcm9vZi1qdGk-6');
		const first = await worker.fetch(
			new Request(url, { headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': proof } }),
			env,
		);
		expect(first.status).toBe(200);
		const second = await worker.fetch(
			new Request(url, { headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': proof } }),
			env,
		);
		expect(second.status).toBe(401);
	});

	it('returns 404 for a path resolveV1ObjectPath does not recognize', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv();
		const res = await worker.fetch(new Request(`${AUDIENCE}/v1/not-a-real-endpoint`), env);
		expect(res.status).toBe(404);
	});

	it('answers OPTIONS preflight with CORS headers and no auth required', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv();
		const res = await worker.fetch(new Request(`${AUDIENCE}/v1/channels/stable.json`, { method: 'OPTIONS' }), env);
		expect(res.status).toBe(200);
		expect(res.headers.get('Access-Control-Allow-Origin')).toBe('*');
	});
});

describe('fetch handler: POST /v1/revoke', () => {
	it('allows revocation when the presented credential is self-issued (a root revoking its own)', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv({ isPremium: true });
		const revoked = installFetchMock(env);
		const url = `${AUDIENCE}/v1/revoke`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'POST', url, selfIssued: true });
		const proof = await buildProof('dGVzdC1wcm9vZi1qdGk-7', 'target-to-revoke');
		const req = new Request(url, {
			method: 'POST',
			headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': proof, 'Content-Type': 'application/json' },
			body: JSON.stringify({ jti: 'target-to-revoke' }),
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(200);
		expect(revoked).toContain('target-to-revoke');
	});

	it('rejects revocation when the presented credential is a box credential, not a root/self-issued one', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv({ isPremium: true });
		installFetchMock(env);
		const url = `${AUDIENCE}/v1/revoke`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'POST', url, selfIssued: false });
		const proof = await buildProof('dGVzdC1wcm9vZi1qdGk-8', 'target-to-revoke');
		const req = new Request(url, {
			method: 'POST',
			headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': proof, 'Content-Type': 'application/json' },
			body: JSON.stringify({ jti: 'target-to-revoke' }),
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(403);
	});

	it('rejects revocation when the body jti does not match the proof-signed target_jti (prevents revoking an arbitrary jti under someone else’s freshness-bound signature)', async () => {
		vi.stubGlobal('caches', { default: new FakeCache() });
		const env = makeEnv({ isPremium: true });
		installFetchMock(env);
		const url = `${AUDIENCE}/v1/revoke`;
		const { credential, buildProof } = await buildCredentialAndProof({ method: 'POST', url, selfIssued: true });
		const proof = await buildProof('dGVzdC1wcm9vZi1qdGk-9', 'target-to-revoke');
		const req = new Request(url, {
			method: 'POST',
			headers: { 'Pocketcoder-Credential': credential, 'Pocketcoder-Proof': proof, 'Content-Type': 'application/json' },
			body: JSON.stringify({ jti: 'a-DIFFERENT-target' }),
		});
		const res = await worker.fetch(req, env);
		expect(res.status).toBe(400);
	});
});
