import { describe, expect, it } from 'vitest';
import { parseCompactJws } from '../src/jwt.ts';
import vectors from '../scripts/test-vectors.json' with { type: 'json' };

describe('parseCompactJws', () => {
	it('parses the fixed credential vector into header/claims/signingInput/signature', () => {
		const parsed = parseCompactJws(vectors.credential);
		expect(parsed.header.alg).toBe('ES256');
		expect(parsed.header.typ).toBe('pocketcoder-box-cert+jwt');
		expect(parsed.claims.iss).toBe(vectors.iss);
		expect(parsed.claims.aud).toBe('https://images.relay.pocketcoder.org');
		const [h, c, s] = vectors.credential.split('.');
		expect(parsed.signingInput).toBe(`${h}.${c}`);
		expect(parsed.signatureB64url).toBe(s);
	});

	it('rejects a token that is not exactly 3 dot-separated parts', () => {
		expect(() => parseCompactJws('a.b')).toThrow(/expected exactly 3 dot-separated parts/);
		expect(() => parseCompactJws('a.b.c.d')).toThrow(/expected exactly 3 dot-separated parts/);
		expect(() => parseCompactJws('')).toThrow(/expected exactly 3 dot-separated parts/);
	});

	it('rejects a header/claims segment that is not valid base64url JSON', () => {
		expect(() => parseCompactJws('not-json.not-json.sig')).toThrow();
	});

	// json's own duplicate-member handling: JSON.parse silently keeps the
	// *last* value for a repeated key. This documents that behavior rather
	// than asserting a rejection this layer doesn't implement -- callers
	// relying on strict duplicate-member rejection must not assume it.
	it('JSON.parse silently resolves duplicate members to the last value (documented, not enforced here)', () => {
		expect(JSON.parse(vectors.rawDuplicateMemberClaims).htm).toBe('POST');
	});
});
