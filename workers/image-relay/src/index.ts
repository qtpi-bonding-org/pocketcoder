/**
 * PocketCoder Image Relay Worker
 *
 * Serves the public image manifest. Image provisioning is handled by the
 * control plane; this worker never receives provider credentials or uploads.
 */

interface Env {
	IMAGES: R2Bucket;
}

const CORS_HEADERS = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, OPTIONS',
	'Access-Control-Allow-Headers': 'Content-Type',
};

export default {
	async fetch(request: Request, env: Env): Promise<Response> {
		if (request.method === 'OPTIONS') return new Response(null, { headers: CORS_HEADERS });

		const url = new URL(request.url);
		if (url.pathname === '/image-manifest' && request.method === 'GET') {
			return handleImageManifest(env);
		}
		if (url.pathname === '/release-manifest' && request.method === 'GET') {
			return handleReleaseManifest(env);
		}
		if (url.pathname === '/v1/health' && request.method === 'GET') {
			return json({ status: 'ok', service: 'pocketcoder-image-relay', apiVersion: 1 });
		}
		if (request.method === 'GET' || request.method === 'HEAD') {
			const objectPath = resolveV1ObjectPath(url.pathname);
			if (objectPath) return handleV1Object(env, objectPath, request.method === 'HEAD');
		}
		if (url.pathname === '/health' && request.method === 'GET') {
			return json({ status: 'ok', service: 'pocketcoder-image-relay' });
		}
		return json({ error: 'Not found' }, 404);
	},
};

type ReleaseObject = {
	key: string;
	contentType: string;
	immutable: boolean;
};

function resolveV1ObjectPath(pathname: string): ReleaseObject | null {
	// The `-testing` suffix is a separate, parallel channel-pointer path for
	// the staging branch pipeline (see internal/release/resolver.go's
	// ChannelPath) -- kept as its own literal alternative, not a generic
	// suffix pattern, since GitHubVerifier.Verify only ever trusts
	// attestations published from "main" or "staging".
	const mutable = [
		/^\/v1\/channels\/(stable|beta|nightly)(-testing)?\.json$/,
		/^\/v1\/revocations\/releases\.json$/,
	];
	const immutable = [
		/^\/v1\/attestations\/channels\/(stable|beta|nightly)(-testing)?\/[1-9][0-9]*\.sigstore\.json$/,
		/^\/v1\/releases\/[0-9a-f]{64}\.json$/,
		/^\/v1\/attestations\/releases\/[0-9a-f]{64}\.sigstore\.json$/,
		/^\/v1\/attestations\/revocations\/releases\/[1-9][0-9]*\.sigstore\.json$/,
		/^\/v1\/documents\/[0-9a-f]{64}\.(?:json|txt|sh|go)$/,
		/^\/v1\/artifacts\/[0-9a-f]{64}\.(?:tar\.gz|img\.gz)$/,
	];

	if (mutable.some((pattern) => pattern.test(pathname))) {
		return {
			key: pathname.slice('/v1/'.length),
			contentType: 'application/json',
			immutable: false,
		};
	}
	if (immutable.some((pattern) => pattern.test(pathname))) {
		return {
			key: pathname.slice('/v1/'.length),
			contentType: contentTypeFor(pathname),
			immutable: true,
		};
	}
	return null;
}

function contentTypeFor(pathname: string): string {
	if (pathname.endsWith('.sh')) return 'text/x-shellscript; charset=utf-8';
	if (pathname.endsWith('.go')) return 'text/x-go; charset=utf-8';
	if (pathname.endsWith('.txt')) return 'text/plain; charset=utf-8';
	if (pathname.endsWith('.tar.gz') || pathname.endsWith('.img.gz')) {
		return 'application/gzip';
	}
	return 'application/json';
}

// headOnly uses R2's own head() (metadata only, no body transfer) rather
// than fetching and discarding get()'s body -- this is what publish/
// promotion tooling polls with to confirm an object is live without
// paying for a multi-GB download each check.
function objectHeaders(path: ReleaseObject, object: R2Object): HeadersInit {
	return {
		...CORS_HEADERS,
		'Content-Type': path.contentType,
		'Content-Length': object.size.toString(),
		'Cache-Control': path.immutable
			? 'public, max-age=31536000, immutable'
			: 'public, max-age=300, must-revalidate',
		ETag: object.httpEtag,
	};
}

async function handleV1Object(
	env: Env,
	path: ReleaseObject,
	headOnly: boolean,
): Promise<Response> {
	if (headOnly) {
		const object = await env.IMAGES.head(path.key);
		if (!object) return json({ error: 'Release object unavailable' }, 404);
		return new Response(null, { status: 200, headers: objectHeaders(path, object) });
	}

	const object = await env.IMAGES.get(path.key);
	if (!object) return json({ error: 'Release object unavailable' }, 404);
	return new Response(object.body, { status: 200, headers: objectHeaders(path, object) });
}

async function handleImageManifest(env: Env): Promise<Response> {
	const object = await env.IMAGES.get('image-manifest.json');
	if (!object) return json({ error: 'Image manifest unavailable' }, 404);

	return new Response(object.body, {
		status: 200,
		headers: {
			...CORS_HEADERS,
			'Content-Type': 'application/json',
			'Cache-Control': 'public, max-age=300',
		},
	});
}

async function handleReleaseManifest(env: Env): Promise<Response> {
	const object = await env.IMAGES.get('release-manifest.json');
	if (!object) return json({ error: 'Release manifest unavailable' }, 404);

	return new Response(object.body, {
		status: 200,
		headers: {
			...CORS_HEADERS,
			'Content-Type': 'application/json',
			'Cache-Control': 'public, max-age=300',
		},
	});
}

function json(data: unknown, status = 200): Response {
	return new Response(JSON.stringify(data), {
		status,
		headers: { ...CORS_HEADERS, 'Content-Type': 'application/json' },
	});
}
