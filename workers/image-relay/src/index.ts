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
		if (url.pathname === '/health' && request.method === 'GET') {
			return json({ status: 'ok', service: 'pocketcoder-image-relay' });
		}
		return json({ error: 'Not found' }, 404);
	},
};

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
