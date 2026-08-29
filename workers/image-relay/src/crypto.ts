// Native Web Crypto only -- no JOSE/JWT library. See
// docs/superpowers/specs/2026-08-24-image-relay-auth-protocol.md for the
// exact byte-level rules this implements.

export function base64urlEncode(bytes: Uint8Array): string {
	let binary = '';
	for (const b of bytes) binary += String.fromCharCode(b);
	return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

// Rejects padded input and non-base64url characters -- lenient decoding
// of a signature/key input is exactly the kind of boundary-parsing risk
// the protocol spec calls out; never silently accept "close enough".
export function base64urlDecode(s: string): Uint8Array {
	if (!/^[A-Za-z0-9_-]*$/.test(s)) throw new Error('invalid base64url: illegal characters');
	const padded = s + '='.repeat((4 - (s.length % 4)) % 4);
	const binary = atob(padded.replace(/-/g, '+').replace(/_/g, '/'));
	const bytes = new Uint8Array(binary.length);
	for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
	return bytes;
}

function utf8Bytes(s: string): Uint8Array {
	return new TextEncoder().encode(s);
}

export async function sha256Base64url(input: string): Promise<string> {
	const digest = await crypto.subtle.digest('SHA-256', utf8Bytes(input));
	return base64urlEncode(new Uint8Array(digest));
}

export type P256PublicJwk = { kty: 'EC'; crv: 'P-256'; x: string; y: string };

// Strict: exactly kty/crv/x/y, no private "d" member, x/y decode to
// exactly 32 bytes each. A JWK that "mostly" looks right but has an
// extra member or a private key attached is rejected, not tolerated.
export function validatePublicJwkShape(jwk: unknown): asserts jwk is P256PublicJwk {
	if (typeof jwk !== 'object' || jwk === null) throw new Error('jwk: not an object');
	const j = jwk as Record<string, unknown>;
	const allowedMembers = new Set(['kty', 'crv', 'x', 'y']);
	for (const key of Object.keys(j)) {
		if (!allowedMembers.has(key)) throw new Error(`jwk: unexpected member "${key}"`);
	}
	if (j.kty !== 'EC') throw new Error('jwk: kty must be EC');
	if (j.crv !== 'P-256') throw new Error('jwk: crv must be P-256');
	if (typeof j.x !== 'string' || typeof j.y !== 'string') throw new Error('jwk: x/y must be strings');
	if (base64urlDecode(j.x).length !== 32) throw new Error('jwk: x must decode to 32 bytes');
	if (base64urlDecode(j.y).length !== 32) throw new Error('jwk: y must decode to 32 bytes');
}

export async function importP256PublicJwk(jwk: P256PublicJwk): Promise<CryptoKey> {
	return crypto.subtle.importKey(
		'jwk',
		{ ...jwk, ext: true },
		{ name: 'ECDSA', namedCurve: 'P-256' },
		true,
		['verify'],
	);
}

// ES256 signature bytes are raw r||s (64 bytes), never DER -- Web
// Crypto's ECDSA verify already expects this exact layout for a
// P-256/SHA-256 key, so no conversion is needed on this side (the
// signer, in every other language, is responsible for producing raw
// r||s, not the Worker).
export async function verifyEs256(
	key: CryptoKey,
	signingInput: string,
	signatureB64url: string,
): Promise<boolean> {
	const sig = base64urlDecode(signatureB64url);
	if (sig.length !== 64) return false;
	return crypto.subtle.verify(
		{ name: 'ECDSA', hash: 'SHA-256' },
		key,
		sig,
		utf8Bytes(signingInput),
	);
}

// RFC 7638: canonical JSON with ONLY the required EC members, ordered
// lexicographically by member name -- crv, kty, x, y -- no whitespace.
export async function rfc7638Thumbprint(jwk: P256PublicJwk): Promise<string> {
	const canonical = `{"crv":"${jwk.crv}","kty":"${jwk.kty}","x":"${jwk.x}","y":"${jwk.y}"}`;
	return sha256Base64url(canonical);
}
