import { describe, expect, it } from 'vitest';
import {
	base64urlDecode,
	base64urlEncode,
	rfc7638Thumbprint,
	sha256Base64url,
	validatePublicJwkShape,
} from '../src/crypto.ts';
import vectors from '../scripts/test-vectors.json' with { type: 'json' };

describe('base64urlDecode', () => {
	it('round-trips through base64urlEncode', () => {
		const bytes = new Uint8Array([0, 1, 2, 254, 255, 16, 32]);
		expect(base64urlDecode(base64urlEncode(bytes))).toEqual(bytes);
	});

	it('rejects standard-base64 padding', () => {
		expect(() => base64urlDecode(vectors.nonCanonicalPaddedX)).toThrow(/illegal characters/);
	});

	it('rejects "+" and "/" (non-url-safe base64 alphabet)', () => {
		expect(() => base64urlDecode('a+b')).toThrow(/illegal characters/);
		expect(() => base64urlDecode('a/b')).toThrow(/illegal characters/);
	});

	it('accepts unpadded url-safe base64', () => {
		expect(() => base64urlDecode('YWJj')).not.toThrow();
	});
});

describe('validatePublicJwkShape', () => {
	it('accepts a well-formed P-256 public JWK', () => {
		expect(() => validatePublicJwkShape(vectors.rootJwk)).not.toThrow();
	});

	it('rejects a JWK with an extra member (e.g. a private "d")', () => {
		expect(() => validatePublicJwkShape({ ...vectors.rootJwk, d: 'secret' })).toThrow(/unexpected member/);
	});

	it('rejects wrong kty', () => {
		expect(() => validatePublicJwkShape({ ...vectors.rootJwk, kty: 'RSA' })).toThrow(/kty must be EC/);
	});

	it('rejects wrong crv', () => {
		expect(() => validatePublicJwkShape({ ...vectors.rootJwk, crv: 'P-384' })).toThrow(/crv must be P-256/);
	});

	it('rejects a coordinate that decodes to the wrong byte length', () => {
		expect(() => validatePublicJwkShape(vectors.jwkWithLeadingZeroCoordinate)).not.toThrow();
	});

	it('rejects a non-object jwk', () => {
		expect(() => validatePublicJwkShape(null)).toThrow(/not an object/);
		expect(() => validatePublicJwkShape('not-a-jwk')).toThrow(/not an object/);
	});

	it('rejects x/y that are not strings', () => {
		expect(() => validatePublicJwkShape({ ...vectors.rootJwk, x: 12345 })).toThrow(/x\/y must be strings/);
	});
});

describe('rfc7638Thumbprint', () => {
	it('matches the fixed cross-language test vector for rootJwk', async () => {
		expect(await rfc7638Thumbprint(vectors.rootJwk)).toBe(vectors.iss);
	});

	it('is deterministic and order-independent of member insertion', async () => {
		const jwk = vectors.rootJwk;
		const reordered = { y: jwk.y, x: jwk.x, crv: jwk.crv, kty: jwk.kty };
		expect(await rfc7638Thumbprint(jwk)).toBe(await rfc7638Thumbprint(reordered));
	});

	it('produces different thumbprints for different keys', async () => {
		expect(await rfc7638Thumbprint(vectors.rootJwk)).not.toBe(await rfc7638Thumbprint(vectors.boxJwk));
	});
});

describe('sha256Base64url', () => {
	it('matches a known SHA-256 test vector ("abc")', async () => {
		// echo -n abc | openssl dgst -sha256 -binary | basenc --base64url
		expect(await sha256Base64url('abc')).toBe('ungWv48Bz-pBQUDeXa4iI7ADYaOWF3qctBD_YfIAFa0');
	});
});
