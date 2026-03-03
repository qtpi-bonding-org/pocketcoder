/**
 * PocketCoder Notification Relay Worker
 *
 * The "Zero-Cost Franken-Stack" — duct-tapes Cloudflare, RevenueCat,
 * Supabase, and Firebase together into a zero-cost monetization tollbooth.
 *
 * Flow:
 *   PocketBase POST → validate secret → RevenueCat sub check (cached)
 *   → Supabase daily quota → FCM v1 delivery → device buzzes
 *
 * Expected payload from PocketBase:
 *   {
 *     "token":   "fcm_device_token",
 *     "user_id": "pocketbase_user_id",
 *     "service": "fcm",
 *     "title":   "SIGNATURE REQUIRED",
 *     "message": "Action: bash",
 *     "type":    "permission",
 *     "chat":    "abc123"
 *   }
 *
 * Notification types (drives Flutter navigation):
 *   permission   → ChatScreen(chatId)
 *   question     → ChatScreen(chatId)
 *   task_complete → ChatScreen(chatId)
 *   task_error   → ChatScreen(chatId)
 *   mcp_request  → McpManagementScreen
 */

export default {
	async fetch(request, env) {
		if (request.method !== 'POST') {
			return json({ status: 'ok', service: 'pocketcoder-relay' }, 200);
		}

		// Step 1: Validate shared secret
		const secret = request.headers.get('X-Relay-Secret');
		if (secret !== env.PN_RELAY_SECRET) {
			return json({ error: 'Unauthorized' }, 401);
		}

		try {
			const payload = await request.json();
			const { token, user_id, service, title, message, type, chat } = payload;

			if (!token || !service) {
				return json({ error: 'Missing token or service' }, 400);
			}

			// UnifiedPush: direct passthrough, no subscription/quota checks
			if (service === 'unifiedpush') {
				return await sendUnifiedPush(token, title, message, type, chat);
			}

			if (service !== 'fcm') {
				return json({ error: `Unknown service: ${service}` }, 400);
			}

			// --- FCM path: the monetization tollbooth ---

			// Step 2: RevenueCat subscription check
			if (user_id && env.REVENUECAT_SECRET_KEY) {
				const isPremium = await checkSubscription(user_id, env);
				if (!isPremium) {
					return json({ error: 'Subscription required', code: 'NOT_SUBSCRIBED' }, 403);
				}
			}

			// Step 3: Supabase daily quota check
			if (user_id && env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
				const count = await checkAndIncrementQuota(user_id, env);
				const limit = parseInt(env.DAILY_PUSH_LIMIT || '1000', 10);
				if (count > limit) {
					return json({ error: 'Daily push limit exceeded', count, limit }, 429);
				}
			}

			// Step 4: FCM v1 delivery
			const result = await sendFCM({ token, title, message, type, chat }, env);
			return json(result, result.success ? 200 : 502);

		} catch (e) {
			console.error('Relay error:', e.message, e.stack);
			return json({ error: e.message }, 500);
		}
	},
};

// ---------------------------------------------------------------------------
// Step 2: RevenueCat subscription check with Cloudflare Cache API
// ---------------------------------------------------------------------------

async function checkSubscription(userId, env) {
	const cacheUrl = `https://rc-cache.internal/${userId}`;
	const cacheKey = new Request(cacheUrl);
	const cache = caches.default;

	// Check edge cache first (0ms)
	const cached = await cache.match(cacheKey);
	if (cached) {
		const data = await cached.json();
		return data.isPremium;
	}

	// Cache miss — ask RevenueCat
	try {
		const resp = await fetch(
			`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(userId)}`,
			{
				headers: {
					'Authorization': `Bearer ${env.REVENUECAT_SECRET_KEY}`,
					'Content-Type': 'application/json',
				},
			}
		);

		if (!resp.ok) {
			console.error(`RevenueCat returned ${resp.status} for user ${userId}`);
			// Fail open on RevenueCat errors — deliver the notification
			return true;
		}

		const data = await resp.json();
		const entitlements = data.subscriber?.entitlements || {};
		const premium = entitlements.premium;
		const isPremium = !!premium &&
			!!premium.expires_date &&
			new Date(premium.expires_date) > new Date();

		// Cache result for 5 minutes at the edge
		const cacheResp = new Response(JSON.stringify({ isPremium }), {
			headers: {
				'Content-Type': 'application/json',
				'Cache-Control': 'max-age=300',
			},
		});
		await cache.put(cacheKey, cacheResp);

		return isPremium;
	} catch (e) {
		console.error('RevenueCat check failed:', e.message);
		// Fail open — deliver anyway
		return true;
	}
}

// ---------------------------------------------------------------------------
// Step 3: Supabase daily quota (atomic increment + check)
// ---------------------------------------------------------------------------

async function checkAndIncrementQuota(userId, env) {
	try {
		const resp = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/increment_push`, {
			method: 'POST',
			headers: {
				'apikey': env.SUPABASE_SERVICE_KEY,
				'Authorization': `Bearer ${env.SUPABASE_SERVICE_KEY}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({ p_user_id: userId }),
		});

		if (!resp.ok) {
			console.error(`Supabase returned ${resp.status}`);
			// Fail open — don't block notifications on quota DB errors
			return 0;
		}

		return await resp.json();
	} catch (e) {
		console.error('Supabase quota check failed:', e.message);
		return 0;
	}
}

// ---------------------------------------------------------------------------
// Step 4: FCM v1 API delivery
// ---------------------------------------------------------------------------

async function sendFCM(payload, env) {
	const { token, title, message, type, chat } = payload;

	const accessToken = await getAccessToken(env);

	const fcmBody = {
		message: {
			token,
			notification: {
				title: title || 'PocketCoder',
				body: message || '',
			},
			data: {
				type: type || 'general',
				...(chat && { chat }),
				click_url: chat ? `pocketcoder://chat/${chat}` : 'pocketcoder://',
			},
			android: {
				priority: 'high',
			},
			apns: {
				payload: {
					aps: {
						sound: 'default',
						'mutable-content': 1,
					},
				},
			},
		},
	};

	const resp = await fetch(
		`https://fcm.googleapis.com/v1/projects/${env.FCM_PROJECT_ID}/messages:send`,
		{
			method: 'POST',
			headers: {
				'Authorization': `Bearer ${accessToken}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify(fcmBody),
		}
	);

	const result = await resp.json();

	if (!resp.ok) {
		console.error('FCM error:', JSON.stringify(result));
		return { success: false, fcm_status: resp.status, error: result.error?.message };
	}

	return { success: true, fcm_message_name: result.name };
}

// ---------------------------------------------------------------------------
// OAuth2 access token (JWT signed with Web Crypto API, zero dependencies)
// ---------------------------------------------------------------------------

// In-memory cache (survives within Worker isolate, typically ~30s between requests)
let tokenCache = { token: null, expiry: 0 };

async function getAccessToken(env) {
	// Return cached token if still valid (with 5 min buffer)
	if (tokenCache.token && Date.now() < tokenCache.expiry - 300_000) {
		return tokenCache.token;
	}

	const now = Math.floor(Date.now() / 1000);
	const jwt = await signJWT(
		{ alg: 'RS256', typ: 'JWT' },
		{
			iss: env.FCM_CLIENT_EMAIL,
			scope: 'https://www.googleapis.com/auth/firebase.messaging',
			aud: 'https://oauth2.googleapis.com/token',
			iat: now,
			exp: now + 3600,
		},
		env.FCM_PRIVATE_KEY
	);

	const resp = await fetch('https://oauth2.googleapis.com/token', {
		method: 'POST',
		headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
		body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${jwt}`,
	});

	if (!resp.ok) {
		const text = await resp.text();
		throw new Error(`OAuth2 token exchange failed (${resp.status}): ${text}`);
	}

	const data = await resp.json();
	tokenCache = {
		token: data.access_token,
		expiry: Date.now() + (data.expires_in * 1000),
	};

	return data.access_token;
}

async function signJWT(header, claims, privateKeyBase64) {
	// Decode the base64-encoded PEM
	const pem = atob(privateKeyBase64);

	// Strip PEM headers and whitespace to get raw DER bytes
	const pemBody = pem
		.replace(/-----BEGIN PRIVATE KEY-----/, '')
		.replace(/-----END PRIVATE KEY-----/, '')
		.replace(/\s/g, '');

	const keyData = Uint8Array.from(atob(pemBody), c => c.charCodeAt(0));

	// Import as PKCS#8 RSA key
	const key = await crypto.subtle.importKey(
		'pkcs8',
		keyData.buffer,
		{ name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
		false,
		['sign']
	);

	// Encode header and claims
	const encodedHeader = base64url(JSON.stringify(header));
	const encodedClaims = base64url(JSON.stringify(claims));
	const signingInput = `${encodedHeader}.${encodedClaims}`;

	// Sign
	const signature = await crypto.subtle.sign(
		'RSASSA-PKCS1-v1_5',
		key,
		new TextEncoder().encode(signingInput)
	);

	return `${signingInput}.${arrayBufferToBase64url(signature)}`;
}

// ---------------------------------------------------------------------------
// UnifiedPush passthrough (ntfy-compatible)
// ---------------------------------------------------------------------------

async function sendUnifiedPush(endpoint, title, message, type, chat) {
	const clickUrl = chat ? `pocketcoder://chat/${chat}` : 'pocketcoder://';

	const resp = await fetch(endpoint, {
		method: 'POST',
		headers: {
			'Title': title || 'PocketCoder',
			'Click': clickUrl,
			'Priority': 'high',
			...(type && { 'Tags': type }),
		},
		body: message || '',
	});

	return new Response(await resp.text(), {
		status: resp.status,
		headers: { 'Content-Type': 'application/json' },
	});
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function json(data, status = 200) {
	return new Response(JSON.stringify(data), {
		status,
		headers: { 'Content-Type': 'application/json' },
	});
}

function base64url(str) {
	return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function arrayBufferToBase64url(buffer) {
	const bytes = new Uint8Array(buffer);
	let binary = '';
	for (let i = 0; i < bytes.length; i++) {
		binary += String.fromCharCode(bytes[i]);
	}
	return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}
