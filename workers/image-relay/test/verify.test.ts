import { beforeAll, describe, expect, it } from 'vitest';
import { VerificationError, verifyCredential, verifyProof } from '../src/verify.ts';
import { base64urlEncode } from '../src/crypto.ts';
import { generateP256Pair, signCompactJws, type Jwk } from './helpers.ts';
import vectors from '../scripts/test-vectors.json' with { type: 'json' };

const AUDIENCE = 'https://images.relay.pocketcoder.org';
const FIXED_IAT = 1735689600;
const PROOF_URL = `${AUDIENCE}/v1/channels/stable.json`;

// --- Fixed cross-language corpus: pins verify.ts against the exact bytes
// Go, Dart, and the shell installer all validate against too. If this
// breaks, one of those implementations has silently drifted. ---
describe('verifyCredential / verifyProof against the fixed cross-language corpus', () => {
	it('accepts the fixed valid credential vector', async () => {
		const result = await verifyCredential(vectors.credential);
		expect(result.iss).toBe(vectors.iss);
		expect(result.boxJwk).toEqual(vectors.boxJwk);
		expect(result.isSelfIssued).toBe(false);
	});

	it('rejects the fixed bad-signature credential vector', async () => {
		await expect(verifyCredential(vectors.credentialBadSignature)).rejects.toThrow(VerificationError);
	});

	it('accepts the fixed valid proof vector bound to its credential', async () => {
		const result = await verifyProof(vectors.proof, vectors.boxJwk, 'GET', PROOF_URL, FIXED_IAT);
		expect(result.jti).toBeTruthy();
	});

	it('rejects the fixed bad-signature proof vector', async () => {
		await expect(
			verifyProof(vectors.proofBadSignature, vectors.boxJwk, 'GET', PROOF_URL, FIXED_IAT),
		).rejects.toThrow(VerificationError);
	});

	it('rejects the fixed wrong-method proof claims', () => {
		expect(vectors.proofWrongMethod.htm).toBe('POST');
	});

	it('rejects a JWK carrying an off-curve point on import', async () => {
		const { importP256PublicJwk } = await import('../src/crypto.ts');
		await expect(importP256PublicJwk(vectors.offCurveJwk as Jwk)).rejects.toThrow();
	});

	it('rejects the fixed wrong-alg header', async () => {
		await expect(verifyProof(reheader(vectors.proof, vectors.wrongAlgHeader), vectors.boxJwk, 'GET', PROOF_URL, FIXED_IAT)).rejects.toThrow(
			/alg must be ES256/,
		);
	});

	it('rejects the fixed wrong-typ header', async () => {
		await expect(verifyProof(reheader(vectors.proof, vectors.wrongTypHeader), vectors.boxJwk, 'GET', PROOF_URL, FIXED_IAT)).rejects.toThrow(
			/wrong typ/,
		);
	});
});

// --- Dynamically-signed fixtures: real signatures over crafted claims, so
// these prove the *specific semantic check* fires, not just that a garbled
// signature is rejected. ---
describe('verifyCredential semantics (real signatures, crafted claims)', () => {
	let root: Awaited<ReturnType<typeof generateP256Pair>>;
	let box: Awaited<ReturnType<typeof generateP256Pair>>;
	let rootThumbprint: string;

	beforeAll(async () => {
		root = await generateP256Pair();
		box = await generateP256Pair();
		const { rfc7638Thumbprint } = await import('../src/crypto.ts');
		rootThumbprint = await rfc7638Thumbprint(root.jwk);
	});

	function credHeader(jwk: Jwk, overrides: Record<string, unknown> = {}) {
		return { alg: 'ES256', typ: 'pocketcoder-box-cert+jwt', jwk, ...overrides };
	}
	function credClaims(overrides: Record<string, unknown> = {}) {
		return {
			iss: rootThumbprint,
			aud: AUDIENCE,
			iat: FIXED_IAT,
			jti: 'dGVzdC1jcmVkLWp0aQ',
			cnf: { jwk: box.jwk },
			...overrides,
		};
	}

	it('accepts a validly-signed credential and returns the correct identity', async () => {
		const jws = await signCompactJws(root.privateKey, credHeader(root.jwk), credClaims());
		const result = await verifyCredential(jws);
		expect(result.iss).toBe(rootThumbprint);
		expect(result.boxJwk).toEqual(box.jwk);
		expect(result.isSelfIssued).toBe(false);
	});

	it('marks a root-issued-to-itself credential as isSelfIssued', async () => {
		const jws = await signCompactJws(root.privateKey, credHeader(root.jwk), credClaims({ cnf: { jwk: root.jwk } }));
		const result = await verifyCredential(jws);
		expect(result.isSelfIssued).toBe(true);
	});

	it('rejects a credential whose iss claim does not match the header jwk thumbprint (a forged identity)', async () => {
		const jws = await signCompactJws(root.privateKey, credHeader(root.jwk), credClaims({ iss: 'someone-elses-thumbprint' }));
		await expect(verifyCredential(jws)).rejects.toThrow(/iss does not match/);
	});

	it('rejects a credential validly signed by the WRONG root key entirely (a different account entirely)', async () => {
		const other = await generateP256Pair();
		// signed by `other`, but header advertises `root`'s jwk -- signature
		// verification itself must fail, since it verifies against the
		// declared header key, not the actual signer.
		const jws = await signCompactJws(other.privateKey, credHeader(root.jwk), credClaims());
		await expect(verifyCredential(jws)).rejects.toThrow(/signature invalid/);
	});

	it('rejects an audience for a different service (aud confusion)', async () => {
		const jws = await signCompactJws(root.privateKey, credHeader(root.jwk), credClaims({ aud: 'https://evil.example.com' }));
		await expect(verifyCredential(jws)).rejects.toThrow(/aud mismatch/);
	});

	it('rejects a credential whose cnf.jwk carries a private "d" member (leaked private key shape)', async () => {
		const jws = await signCompactJws(root.privateKey, credHeader(root.jwk), credClaims({ cnf: { jwk: { ...box.jwk, d: 'leaked' } } }));
		await expect(verifyCredential(jws)).rejects.toThrow(/unexpected member/);
	});

	it('rejects a credential with jti shorter than 16 characters (weak/guessable revocation target)', async () => {
		const jws = await signCompactJws(root.privateKey, credHeader(root.jwk), credClaims({ jti: 'short' }));
		await expect(verifyCredential(jws)).rejects.toThrow(/jti missing or too short/);
	});

	it('rejects a credential missing jti entirely', async () => {
		const { jti, ...rest } = credClaims();
		const jws = await signCompactJws(root.privateKey, credHeader(root.jwk), rest);
		await expect(verifyCredential(jws)).rejects.toThrow(/jti missing or too short/);
	});
});

describe('verifyProof semantics (real signatures, crafted claims)', () => {
	let box: Awaited<ReturnType<typeof generateP256Pair>>;

	beforeAll(async () => {
		box = await generateP256Pair();
	});

	function proofHeader(jwk: Jwk, overrides: Record<string, unknown> = {}) {
		return { alg: 'ES256', typ: 'dpop+jwt', jwk, ...overrides };
	}
	function proofClaims(overrides: Record<string, unknown> = {}) {
		return { htm: 'GET', htu: PROOF_URL, iat: FIXED_IAT, jti: 'dGVzdC1wcm9vZi1qdGk', ...overrides };
	}

	it('accepts a validly-signed proof matching the expected credential key/method/url', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims());
		const result = await verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT);
		expect(result.jti).toBe('dGVzdC1wcm9vZi1qdGk');
	});

	it('rejects a proof presented with a different box key than the credential vouches for (key-substitution attack)', async () => {
		const attacker = await generateP256Pair();
		const jws = await signCompactJws(attacker.privateKey, proofHeader(attacker.jwk), proofClaims());
		// Worker calls verifyProof with the credential's box.jwk as
		// `expectedJwk` -- an attacker's own valid self-signed proof must
		// still be rejected because it doesn't match that expected key.
		await expect(verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT)).rejects.toThrow(
			/does not match credential/,
		);
	});

	it('rejects a stale proof (iat far in the past -- a captured-and-replayed-later signature)', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims({ iat: FIXED_IAT - 10_000 }));
		await expect(verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT)).rejects.toThrow(/freshness window/);
	});

	it('rejects a proof from the future (iat ahead of server clock, beyond tolerance)', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims({ iat: FIXED_IAT + 10_000 }));
		await expect(verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT)).rejects.toThrow(/freshness window/);
	});

	it('rejects a proof bound to a different path (cannot be replayed against a neighboring endpoint)', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims({ htu: `${AUDIENCE}/v1/channels/beta.json` }));
		await expect(verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT)).rejects.toThrow(/htu mismatch/);
	});

	it('accepts htu differing only by RFC 3986-normalizable casing/default port', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims({ htu: `HTTPS://IMAGES.RELAY.POCKETCODER.ORG:443/v1/channels/stable.json` }));
		await expect(verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT)).resolves.toBeTruthy();
	});

	// normalizeHtu strips query/fragment from BOTH sides of the comparison
	// before matching -- so a signed htu carrying a query string still
	// matches a query-less expected URL. This is intentional (RFC 9449
	// excludes query/fragment from htu entirely) and symmetric, not a gap:
	// document the actual behavior rather than assert a rejection this
	// layer deliberately does not implement.
	it('tolerates (and ignores) a query/fragment on the signed htu, since both sides are normalized identically', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims({ htu: `${PROOF_URL}?x=1#frag` }));
		await expect(verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT)).resolves.toBeTruthy();
	});

	it('rejects htu whose PATH differs, even if case of an unrelated path segment changes (paths are case-sensitive, unlike host)', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims({ htu: `${AUDIENCE}/v1/Channels/stable.json` }));
		await expect(verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT)).rejects.toThrow(/htu mismatch/);
	});

	it('forwards target_jti when present (used by the revoke endpoint to bind proof to body)', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims({ target_jti: 'the-jti-to-revoke' }));
		const result = await verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT);
		expect(result.targetJti).toBe('the-jti-to-revoke');
	});

	it('leaves targetJti undefined when absent', async () => {
		const jws = await signCompactJws(box.privateKey, proofHeader(box.jwk), proofClaims());
		const result = await verifyProof(jws, box.jwk, 'GET', PROOF_URL, FIXED_IAT);
		expect(result.targetJti).toBeUndefined();
	});
});

function reheader(original: string, header: Record<string, unknown>): string {
	const [, c, s] = original.split('.');
	const encoded = base64urlEncode(new TextEncoder().encode(JSON.stringify(header)));
	return `${encoded}.${c}.${s}`;
}
