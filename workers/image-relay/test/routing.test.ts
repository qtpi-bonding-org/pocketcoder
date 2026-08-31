import { describe, expect, it } from 'vitest';
import { contentTypeFor, resolveV1ObjectPath } from '../src/index.ts';

const DIGEST = 'a'.repeat(64);

describe('resolveV1ObjectPath', () => {
	it('accepts mutable channel pointers and marks them non-immutable', () => {
		for (const p of ['/v1/channels/stable.json', '/v1/channels/beta.json', '/v1/channels/nightly.json', '/v1/channels/stable-testing.json']) {
			const result = resolveV1ObjectPath(p);
			expect(result).not.toBeNull();
			expect(result!.immutable).toBe(false);
		}
	});

	it('accepts content-addressed artifacts/releases and marks them immutable', () => {
		for (const p of [
			`/v1/releases/${DIGEST}.json`,
			`/v1/artifacts/${DIGEST}.tar.gz`,
			`/v1/artifacts/${DIGEST}.img.gz`,
			`/v1/attestations/releases/${DIGEST}.sigstore.json`,
		]) {
			const result = resolveV1ObjectPath(p);
			expect(result).not.toBeNull();
			expect(result!.immutable).toBe(true);
		}
	});

	it('rejects an unknown channel name (not an allowlisted value)', () => {
		expect(resolveV1ObjectPath('/v1/channels/canary.json')).toBeNull();
	});

	it('rejects a digest that is not exactly 64 lowercase hex characters', () => {
		expect(resolveV1ObjectPath(`/v1/releases/${'A'.repeat(64)}.json`)).toBeNull(); // uppercase
		expect(resolveV1ObjectPath(`/v1/releases/${'a'.repeat(63)}.json`)).toBeNull(); // too short
		expect(resolveV1ObjectPath(`/v1/releases/${'a'.repeat(65)}.json`)).toBeNull(); // too long
		expect(resolveV1ObjectPath(`/v1/releases/not-hex-at-all.json`)).toBeNull();
	});

	it('rejects path traversal attempts', () => {
		expect(resolveV1ObjectPath(`/v1/artifacts/../../../etc/passwd`)).toBeNull();
		expect(resolveV1ObjectPath(`/v1/releases/${DIGEST}/../../secret.json`)).toBeNull();
	});

	it('rejects an arbitrary unlisted path', () => {
		expect(resolveV1ObjectPath('/v1/anything-else')).toBeNull();
		expect(resolveV1ObjectPath('/')).toBeNull();
		expect(resolveV1ObjectPath('')).toBeNull();
	});

	it('sequence-numbered attestation/revocation paths require a positive, non-zero-padded integer', () => {
		expect(resolveV1ObjectPath('/v1/attestations/channels/stable/1.sigstore.json')).not.toBeNull();
		expect(resolveV1ObjectPath('/v1/attestations/channels/stable/0.sigstore.json')).toBeNull();
		expect(resolveV1ObjectPath('/v1/attestations/channels/stable/01.sigstore.json')).toBeNull();
	});
});

describe('contentTypeFor', () => {
	it('maps known extensions to their content types', () => {
		expect(contentTypeFor('x.sh')).toBe('text/x-shellscript; charset=utf-8');
		expect(contentTypeFor('x.go')).toBe('text/x-go; charset=utf-8');
		expect(contentTypeFor('x.txt')).toBe('text/plain; charset=utf-8');
		expect(contentTypeFor('x.tar.gz')).toBe('application/gzip');
		expect(contentTypeFor('x.img.gz')).toBe('application/gzip');
	});

	it('defaults unknown extensions to application/json (matches the .json-heavy allowlist)', () => {
		expect(contentTypeFor('x.json')).toBe('application/json');
		expect(contentTypeFor('x.unknown')).toBe('application/json');
	});
});
