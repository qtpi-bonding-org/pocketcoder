// Run once: npx tsx scripts/generate-test-vectors.ts > scripts/test-vectors.json
// Produces FIXED fixtures (not fresh-random) -- the whole point is that
// all four language implementations validate against the exact same
// bytes, forever, not a moving target.
import { base64urlEncode, rfc7638Thumbprint } from '../src/crypto.ts';

async function exportRawJwk(key: CryptoKey): Promise<{ kty: 'EC'; crv: 'P-256'; x: string; y: string }> {
	const jwk = await crypto.subtle.exportKey('jwk', key) as JsonWebKey;
	return { kty: 'EC', crv: 'P-256', x: jwk.x!, y: jwk.y! };
}

async function signEs256(privateKey: CryptoKey, signingInput: string): Promise<string> {
	const sig = await crypto.subtle.sign(
		{ name: 'ECDSA', hash: 'SHA-256' },
		privateKey,
		new TextEncoder().encode(signingInput),
	);
	return base64urlEncode(new Uint8Array(sig));
}

function b64u(obj: unknown): string {
	return base64urlEncode(new TextEncoder().encode(JSON.stringify(obj)));
}

async function main() {
	const rootPair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
	const boxPair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
	const rootJwk = await exportRawJwk(rootPair.publicKey);
	const boxJwk = await exportRawJwk(boxPair.publicKey);
	const iss = await rfc7638Thumbprint(rootJwk);

	const credHeader = { alg: 'ES256', typ: 'pocketcoder-box-cert+jwt', jwk: rootJwk };
	const credClaims = {
		iss, aud: 'https://images.relay.pocketcoder.org', iat: 1735689600,
		jti: 'dGVzdC1jcmVkLWp0aQ', cnf: { jwk: boxJwk },
	};
	const credSigningInput = `${b64u(credHeader)}.${b64u(credClaims)}`;
	const credSig = await signEs256(rootPair.privateKey, credSigningInput);
	const credential = `${credSigningInput}.${credSig}`;

	const proofHeader = { alg: 'ES256', typ: 'dpop+jwt', jwk: boxJwk };
	const proofClaims = {
		htm: 'GET', htu: 'https://images.relay.pocketcoder.org/v1/channels/stable.json',
		iat: 1735689600, jti: 'dGVzdC1wcm9vZi1qdGk',
	};
	const proofSigningInput = `${b64u(proofHeader)}.${b64u(proofClaims)}`;
	const proofSig = await signEs256(boxPair.privateKey, proofSigningInput);
	const proof = `${proofSigningInput}.${proofSig}`;

	console.log(JSON.stringify({
		rootJwk, boxJwk, iss, credential, proof,
		// Negative vectors -- review flagged the original set as
		// happy-path-plus-bad-signature only, and asked for the specific
		// edge cases below explicitly. Every implementation's verify()
		// must reject all of these, not just accept the positive case.
		credentialBadSignature: credential.slice(0, -4) + 'XXXX',
		proofBadSignature: proof.slice(0, -4) + 'XXXX',
		proofWrongMethod: { ...proofClaims, htm: 'POST' },
		// A JWK whose x/y decode to fewer than 32 bytes because of a
		// genuine leading-zero coordinate -- must still be accepted as
		// VALID (leading zeros are legitimate, not an error) once
		// correctly zero-padded; included here as a shape check, not a
		// rejection case.
		jwkWithLeadingZeroCoordinate: {
			kty: 'EC', crv: 'P-256',
			x: base64urlEncode(new Uint8Array(32)), // all-zero X is a real (if degenerate) 32-byte value
			y: rootJwk.y,
		},
		// Off-curve point -- x/y decode to 32 bytes each but do not
		// satisfy the P-256 curve equation. Every verifier's import step
		// (crypto.subtle.importKey / webcrypto / Go's elliptic curve
		// unmarshal / OpenSSL) should itself reject this on import,
		// before signature verification is ever reached -- confirm each
		// language's import call actually throws rather than silently
		// accepting an invalid point.
		offCurveJwk: { kty: 'EC', crv: 'P-256', x: rootJwk.x, y: rootJwk.x },
		// Raw JSON text (not parsed/re-serialized) containing a duplicate
		// member name -- included as raw text specifically because
		// JSON.stringify from a JS object can never itself produce
		// duplicate keys; this has to be hand-written to exist at all.
		// A strict parser must reject this outright; a lenient parser
		// that silently keeps "the last value" is exactly the
		// cross-implementation inconsistency risk flagged in review --
		// confirm each language's JSON parsing choice is documented and
		// consistent, not just "whatever the stdlib happens to do."
		rawDuplicateMemberClaims: '{"htm":"GET","htm":"POST","htu":"https://images.relay.pocketcoder.org/v1/channels/stable.json","iat":1735689600,"jti":"dGVzdA"}',
		// Padded / non-canonical base64url -- a byte-identical value to
		// a real field above, but with "=" padding added (illegal for
		// base64url per this protocol's encoding rules). Verifiers must
		// reject this, not silently tolerate it.
		nonCanonicalPaddedX: `${rootJwk.x}==`,
		// Wrong alg/typ -- structurally valid tokens, wrong header
		// values. Verifiers must reject on the exact string mismatch.
		wrongAlgHeader: { alg: 'HS256', typ: 'dpop+jwt', jwk: boxJwk },
		wrongTypHeader: { alg: 'ES256', typ: 'jwt', jwk: boxJwk },
	}, null, 2));
}
main();
