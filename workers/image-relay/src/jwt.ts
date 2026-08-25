import { base64urlDecode } from './crypto.ts';

export type ParsedJws = {
	header: Record<string, unknown>;
	claims: Record<string, unknown>;
	signingInput: string;
	signatureB64url: string;
};

export function parseCompactJws(token: string): ParsedJws {
	const parts = token.split('.');
	if (parts.length !== 3) throw new Error('jws: expected exactly 3 dot-separated parts');
	const [h, c, s] = parts;
	const header = JSON.parse(new TextDecoder().decode(base64urlDecode(h)));
	const claims = JSON.parse(new TextDecoder().decode(base64urlDecode(c)));
	return { header, claims, signingInput: `${h}.${c}`, signatureB64url: s };
}
