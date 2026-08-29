// Signs real, validly-signed compact JWS fixtures for tests -- unlike
// tampering with the fixed corpus's *signature bytes*, this lets a test
// assert on a semantic check (aud, iss, htu, ...) with a signature that
// actually verifies, so the test proves that specific check fires rather
// than merely proving "verifyEs256 rejected garbage".
import { base64urlEncode } from '../src/crypto.ts';

export type Jwk = { kty: 'EC'; crv: 'P-256'; x: string; y: string };

export async function generateP256Pair(): Promise<{ privateKey: CryptoKey; publicKey: CryptoKey; jwk: Jwk }> {
	const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
	const exported = (await crypto.subtle.exportKey('jwk', pair.publicKey)) as JsonWebKey;
	return {
		privateKey: pair.privateKey,
		publicKey: pair.publicKey,
		jwk: { kty: 'EC', crv: 'P-256', x: exported.x!, y: exported.y! },
	};
}

function b64u(obj: unknown): string {
	return base64urlEncode(new TextEncoder().encode(JSON.stringify(obj)));
}

export async function signCompactJws(
	privateKey: CryptoKey,
	header: Record<string, unknown>,
	claims: Record<string, unknown>,
): Promise<string> {
	const signingInput = `${b64u(header)}.${b64u(claims)}`;
	const sig = await crypto.subtle.sign(
		{ name: 'ECDSA', hash: 'SHA-256' },
		privateKey,
		new TextEncoder().encode(signingInput),
	);
	return `${signingInput}.${base64urlEncode(new Uint8Array(sig))}`;
}
