import { parseCompactJws } from './jwt.ts';
import {
	base64urlDecode,
	importP256PublicJwk,
	P256PublicJwk,
	rfc7638Thumbprint,
	validatePublicJwkShape,
	verifyEs256,
} from './crypto.ts';

const AUDIENCE = 'https://images.relay.pocketcoder.org';
const FRESHNESS_WINDOW_SECONDS = 120;

export class VerificationError extends Error {}

export type VerifiedCredential = {
	iss: string;
	jti: string;
	boxJwk: P256PublicJwk;
	isSelfIssued: boolean;
};

// Implements docs/superpowers/specs/2026-08-24-image-relay-auth-protocol.md's
// "Credential verification" 7-step checklist verbatim, in order.
export async function verifyCredential(compactJws: string): Promise<VerifiedCredential> {
	const { header, claims, signingInput, signatureB64url } = parseCompactJws(compactJws);

	if (header.alg !== 'ES256') throw new VerificationError('credential: alg must be ES256');
	if (header.typ !== 'pocketcoder-box-cert+jwt') throw new VerificationError('credential: wrong typ');

	validatePublicJwkShape(header.jwk);
	const rootJwk = header.jwk as P256PublicJwk;
	const rootKey = await importP256PublicJwk(rootJwk);

	if (!(await verifyEs256(rootKey, signingInput, signatureB64url))) {
		throw new VerificationError('credential: signature invalid');
	}

	const thumbprint = await rfc7638Thumbprint(rootJwk);
	if (claims.iss !== thumbprint) throw new VerificationError('credential: iss does not match root jwk thumbprint');
	if (claims.aud !== AUDIENCE) throw new VerificationError('credential: aud mismatch');

	validatePublicJwkShape((claims.cnf as { jwk?: unknown } | undefined)?.jwk);
	const boxJwk = (claims.cnf as { jwk: P256PublicJwk }).jwk;

	if (typeof claims.jti !== 'string' || claims.jti.length < 16) {
		throw new VerificationError('credential: jti missing or too short');
	}

	const boxThumbprint = await rfc7638Thumbprint(boxJwk);
	const isSelfIssued = boxThumbprint === thumbprint;

	return { iss: thumbprint, jti: claims.jti, boxJwk, isSelfIssued };
}

export type VerifiedProof = { jti: string; targetJti?: string };

// Implements the protocol spec's proof-verification steps 3-8 (credential
// verification, step 2, is a separate call -- see verifyCredential above).
export async function verifyProof(
	compactJws: string,
	expectedJwk: P256PublicJwk,
	expectedMethod: string,
	expectedUrl: string,
	nowSeconds: number,
): Promise<VerifiedProof> {
	const { header, claims, signingInput, signatureB64url } = parseCompactJws(compactJws);

	if (header.alg !== 'ES256') throw new VerificationError('proof: alg must be ES256');
	if (header.typ !== 'dpop+jwt') throw new VerificationError('proof: wrong typ');

	validatePublicJwkShape(header.jwk);
	const proofJwk = header.jwk as P256PublicJwk;
	if (proofJwk.x !== expectedJwk.x || proofJwk.y !== expectedJwk.y) {
		throw new VerificationError('proof: header jwk does not match credential cnf.jwk');
	}

	const proofKey = await importP256PublicJwk(proofJwk);
	if (!(await verifyEs256(proofKey, signingInput, signatureB64url))) {
		throw new VerificationError('proof: signature invalid');
	}

	if (claims.htm !== expectedMethod) throw new VerificationError('proof: htm mismatch');
	if (normalizeHtu(claims.htu as string) !== normalizeHtu(expectedUrl)) {
		throw new VerificationError('proof: htu mismatch');
	}

	if (typeof claims.iat !== 'number' || Math.abs(nowSeconds - claims.iat) > FRESHNESS_WINDOW_SECONDS) {
		throw new VerificationError('proof: iat outside freshness window');
	}
	if (typeof claims.jti !== 'string' || claims.jti.length < 16) {
		throw new VerificationError('proof: jti missing or too short');
	}

	return { jti: claims.jti, targetJti: claims.target_jti as string | undefined };
}

// RFC 9449 section 4.3: lowercase scheme/host, default port omitted.
function normalizeHtu(url: string): string {
	const u = new URL(url);
	u.hostname = u.hostname.toLowerCase();
	u.protocol = u.protocol.toLowerCase();
	if ((u.protocol === 'https:' && u.port === '443') || (u.protocol === 'http:' && u.port === '80')) {
		u.port = '';
	}
	u.search = '';
	u.hash = '';
	return u.toString();
}
