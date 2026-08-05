# MCP OAuth Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user connect a locally-run, OAuth-requiring MCP catalog server (GitHub today) with a zero-touch, in-app browser flow — no SSH, no human at the gateway's terminal — by routing the PKCE dance through one centrally-run Cloudflare Worker that holds the OAuth App's `client_secret`, then handing the resulting access/refresh token to the user's own PocketBase as a plain secret that lands in `mcp.env` through the exact pipeline every other MCP server credential already uses.

**Architecture:** App builds a PKCE authorize URL (our shared `client_id`, `code_challenge`, and `code_challenge`+`provider` folded into `state`) and opens it via `flutter_web_auth_2`. GitHub redirects to the Worker's fixed `https://.../callback`, which exchanges `code`→token using its own held `client_secret`, stashes the token in KV under a fresh one-time `exchange_code` (60s TTL), and 302s to `pocketcoder://oauth-callback?exchange_code=...`. The app catches that deep link, `POST`s `{exchange_code, code_verifier}` to the Worker's `/claim`, which verifies `S256(code_verifier) == code_challenge` (decoded from `state` at `/callback` time — no `/claim`-time KV write of its own) and releases the token. The app then delivers the token to its own PocketBase's new `POST /api/pocketcoder/mcp_oauth/store`, which merges it into the target `mcp_servers` row's existing `config` JSON field — the same field `hooks/mcp.go`'s `renderMcpConfig` already turns into `mcp.env`, so saving that row automatically re-renders and restarts the gateway with no new wiring.

**Tech Stack:** Cloudflare Workers (vanilla JS, `fetch` handler + KV), Go (PocketBase custom API route, `server/pocketbase/internal/api`), Flutter/Dart (`pocketcoder_flutter` — Cubit, Freezed, `@injectable`/`@lazySingleton` DI, `flutter_web_auth_2`, `crypto`).

## Global Constraints

- Source of truth: `docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md` (single source of truth for *what* to build — read it before touching any task below if anything here seems to contradict it, the spec wins on intent, this plan wins on mechanics).
- **Path correction vs. the spec/precedent plans:** the backend Go module lives at `server/pocketbase/` in the currently checked-out tree (Go module `github.com/qtpi-automaton/pocketcoder/backend`), **not** `services/pocketbase/` — that path was renamed away in commit `1a393d486` ("rename services/ to server/"). Every file path below uses the real, current `server/pocketbase/...` location. The untracked `services/` directory that exists today only holds `services/mcp-gateway` and is unrelated to this plan.
- `mcp_servers.config` (a `json` field, already in `schema.json`) is **already** the plain-secret carrier: `hooks/mcp.go`'s `renderMcpConfig` iterates it and writes `KEY=value` lines straight into `mcp.env` for every `status = 'approved'` row (confirmed by reading `server/pocketbase/internal/hooks/mcp.go`). Component 3 does **not** need a new secret-storage mechanism — it reuses this field. The only schema gap is knowing (a) whether a server needs OAuth at all and (b) which env var name the token should land under — Task 2 adds exactly those two fields, nothing else.
- `hooks/mcp.go`'s `mcpStatusHandler` runs on **every** `OnRecordAfterUpdateSuccess("mcp_servers")` event and re-renders + restarts the gateway whenever the record's **current** `status` is `"approved"` or `"revoked"` — regardless of which field changed. This means Component 3's Go handler needs no explicit "please re-render" call: `app.Save()`-ing the merged `config` on an already-approved row is sufficient. A still-`"pending"` row is correctly left alone (falls through the `switch`'s default case) until explicitly approved — this is existing, unmodified behavior, not something this plan changes.
- Go style: GNU AGPL header block (copy verbatim from `server/pocketbase/internal/api/mcp.go`) on every new `.go` file; `log.Printf` with an emoji+bracket subsystem prefix — this plan uses `"🔐 [MCPOAuth]"` for the new Go file (no existing prefix covers OAuth specifically).
- Flutter conventions (`client/CLAUDE.md`): no `!` operator; repositories/services wrap every public method in `tryMethod` with a typed `DomainException` subclass; DI via `@injectable` (cubits) / `@lazySingleton` (repos+services) — **every single-implementation infrastructure class in `pocketcoder_flutter` still binds through an `I*` interface** (confirmed: `AuthRepository`, `FilesRepository`, etc. all use `@LazySingleton(as: IThing)`; there is no precedent anywhere in `lib/infrastructure/` for a bare `@LazySingleton()` with no interface) — so **Decision 2 (Component 2): `McpOAuthService` gets an `IMcpOAuthService` interface**, matching every neighbor, not a bare concrete class.
- `pocketcoder_flutter`'s existing `McpCubit` does **not** extend `AppCubit<T>` (it extends plain `Cubit<McpState>`) — this plan's edits to `mcp_cubit.dart` follow that file's own existing pattern, not the generic `client/CLAUDE.md` rule, per the same precedent the 2026-07-23 governance-ui plan already established.
- **Decision 1 (Component 1 — Worker):** no `POST /start` call. The `code_challenge` is carried **in plaintext inside `state`** as `base64url(JSON.stringify({p: provider, cc: code_challenge}))`, generated client-side and decoded by the Worker only at `/callback` time (when it mints the KV entry). No HMAC signing, no persisted state→challenge mapping, no extra network round trip before redirecting to the provider. This is safe because `code_challenge` is not secret (RFC 7636 §4.2 — only the verifier is secret) and nothing in this flow needs to verify that the Worker itself set `state` (there is no session/CSRF concern to defend against here: the only consumer of the deep-link callback is the OS-level custom-scheme handler on the same device that generated the verifier). `workers/oauth-relay` therefore needs exactly one KV write (at `/callback`, the exchange-code→token entry, 60s TTL) and one KV read+delete (at `/claim`) — never a write keyed by `state`.
- **Decision 2 (Component 2 — package boundary):** `IMcpOAuthService`/`McpOAuthService` live in `pocketcoder_flutter` (`lib/domain/mcp/i_mcp_oauth_service.dart`, `lib/infrastructure/mcp/mcp_oauth_service.dart`), **not** in `flutter_aeroform`. This is a PocketCoder-domain concern (talks to this user's own PocketBase and this design's own Worker) with nothing to do with aeroform's VPS-provisioning domain, even though it structurally mirrors `LinodeOAuthService`.
- **Decision 3 (Component 3 — schema):** add exactly two new **optional** `text` fields to `mcp_servers`: `oauth_provider` (empty = plain-secret server, unchanged existing behavior) and `oauth_token_env_var` (the `mcp.env` variable name the access token lands under, e.g. `GITHUB_PERSONAL_ACCESS_TOKEN`). The refresh token, when present, is stored under `"{oauth_token_env_var}_REFRESH_TOKEN"` — a naming *convention* applied in Go code, not a third schema field, since nothing consumes it yet (token refresh is out of scope per the spec).
- **Decision 4 (UI wiring):** the smallest addition is (a) two more optional fields in the existing "ADD NEW" dialog (`oauth_provider`, `oauth_token_env_var`) so an OAuth-requiring server can be registered at all, and (b) a "CONNECT" button on `McpManagementScreen`'s server card that replaces the config-schema form entirely whenever `server.oauthProvider` is non-empty (an OAuth server has nothing for a human to type). This is Task 6, deliberately last and independently droppable — Tasks 1–5 deliver a fully working flow that a developer could trigger by hand (e.g. via `curl`/a debug button) even before Task 6 lands.
- Root `CLAUDE.md`'s Model Generation Pipeline **does** apply to Task 2 (new `mcp_servers` fields) — run its full 5-step sequence, not a shortcut.

---

## File Structure

**Cloudflare Worker — new:**
- `workers/oauth-relay/src/index.js` — `/callback` + `/claim` routes.
- `workers/oauth-relay/wrangler.toml`
- `workers/oauth-relay/package.json`
- `workers/oauth-relay/.gitignore`

**Go — new:**
- `server/pocketbase/internal/api/mcp_oauth.go` — `RegisterMcpOAuthApi`, `storeOAuthToken`.
- `server/pocketbase/internal/api/mcp_oauth_test.go`

**Go — modified:**
- `server/pocketbase/pb_migrations/schema.json` — `mcp_servers` gets `oauth_provider`, `oauth_token_env_var`.
- `server/pocketbase/main.go` — wire `api.RegisterMcpOAuthApi(app, e)`.

**Flutter — new:**
- `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart`
- `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart`
- `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart`

**Flutter — modified:**
- `client/packages/pocketcoder_flutter/assets/pb_schema.json` — regenerated (Task 2).
- `client/packages/pocketcoder_flutter/lib/domain/models/mcp_server.dart`/`.freezed.dart`/`.g.dart` — regenerated (Task 2): `oauthProvider`, `oauthTokenEnvVar`.
- `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart` — new `McpOAuthException`.
- `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart` — new `@Named('mcpOAuthRelayBaseUrl')`/`@Named('githubOAuthClientId')` providers.
- `client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart` — new `mcpOAuthStore` endpoint constant.
- `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart` — add `deliverOAuthToken`; extend `createServer`.
- `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart` — implement both.
- `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart` — add `connectOAuth`/`retryOAuthDelivery`/`hasPendingOAuthDelivery`; extend `createServer`.
- `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart` — CONNECT button, add-server dialog fields.
- `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb` (+ regenerated localization files) — new strings.
- `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart` — new cases.
- `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart` — new cases.
- `client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart` — regenerated (`build_runner`).

---

### Task 1: Cloudflare Worker `workers/oauth-relay`

**Files:**
- Create: `workers/oauth-relay/src/index.js`, `workers/oauth-relay/wrangler.toml`, `workers/oauth-relay/package.json`, `workers/oauth-relay/.gitignore`

**Interfaces:**
- Consumes: nothing (standalone Worker; provider client credentials via `wrangler secret put`).
- Produces: `GET /callback?code&state` → `302 pocketcoder://oauth-callback?exchange_code=...&state=...` (or `?error=...`); `POST /claim {exchange_code, code_verifier}` → `200 {access_token, refresh_token}` or `404`/`400` on failure. Task 4's `McpOAuthService` is the only consumer.

No existing Worker in this repo (`push-relay`, `image-relay`) has an automated test suite (`package.json` in both has only `dev`/`deploy` scripts) — this task follows that same convention and verifies via `wrangler dev --local` + `curl` rather than inventing a Vitest harness that would be the first of its kind in `workers/`.

- [ ] **Step 1: Scaffold the package**

Run:
```bash
mkdir -p workers/oauth-relay/src
```

Create `workers/oauth-relay/package.json`:
```json
{
  "name": "pocketcoder-oauth-relay",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy"
  },
  "devDependencies": {
    "wrangler": "^3.0.0"
  }
}
```

Create `workers/oauth-relay/.gitignore`:
```
node_modules/
.wrangler/
.dev.vars
```

Create `workers/oauth-relay/wrangler.toml`:
```toml
name = "pocketcoder-oauth-relay"
main = "src/index.js"
compatibility_date = "2024-12-01"

[[kv_namespaces]]
binding = "MCP_OAUTH_KV"
id = "REPLACE_WITH_ID_FROM_WRANGLER_KV_NAMESPACE_CREATE"

# Secrets (set via `wrangler secret put`), one client_id/client_secret pair
# per provider, named "<PROVIDER>_OAUTH_CLIENT_ID"/"_CLIENT_SECRET":
# GITHUB_OAUTH_CLIENT_ID     — from a centrally-registered GitHub OAuth App
# GITHUB_OAUTH_CLIENT_SECRET — same App. GitHub requires this even with PKCE
#                              (see the spec's Problem section) — it must
#                              never be shipped to the app or any user's VPS.
```

- [ ] **Step 2: Write `src/index.js`**

Create `workers/oauth-relay/src/index.js`:
```js
/**
 * PocketCoder MCP OAuth Relay
 *
 * Central-broker-with-HTTPS-callback shape informed by reading
 * docker/mcp-gateway (MIT, Copyright (c) 2025 Docker, Inc.) — see
 * docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, "Precedent
 * this design follows directly" / "Attribution & licensing". No code from
 * that project is copied or adapted here.
 *
 * One centrally-registered OAuth App's client_secret lives here (via
 * `wrangler secret put`), never in the app or any self-hosted deployment.
 * Every Aeroform-provisioned PocketCoder instance shares this one Worker.
 *
 * Flow (see the spec's Architecture diagram):
 *   1. App builds an authorize URL itself (this Worker never does) with a
 *      PKCE code_challenge folded into `state` and redirect_uri = this
 *      Worker's own /callback URL, then opens it in a browser sheet.
 *   2. Provider redirects here: GET /callback?code&state
 *   3. This Worker exchanges code -> {access_token, refresh_token} using
 *      its held client_secret, stashes the token in KV under a fresh
 *      one-time exchange_code (60s TTL), and 302s to
 *      pocketcoder://oauth-callback?exchange_code=...&state=...
 *   4. App calls POST /claim {exchange_code, code_verifier}. This Worker
 *      verifies S256(code_verifier) == the code_challenge it decoded from
 *      `state` back in step 3, and only then releases + deletes the KV
 *      entry. This is PKCE's entire purpose in this flow — without it, the
 *      verifier the app generated is never checked by anything.
 *
 * No `/start` route: `state` opaquely carries the code_challenge in
 * plaintext (it is not secret — RFC 7636 §4.2), decoded only here, at
 * /callback time. See this plan's Global Constraints, Decision 1, for why
 * that's safe and why it avoids an extra pre-redirect round trip.
 */

const PROVIDERS = {
	github: {
		tokenUrl: 'https://github.com/login/oauth/access_token',
	},
};

const EXCHANGE_TTL_SECONDS = 60;

export default {
	async fetch(request, env) {
		const url = new URL(request.url);

		if (request.method === 'GET' && url.pathname === '/callback') {
			return handleCallback(url, env);
		}
		if (request.method === 'POST' && url.pathname === '/claim') {
			return handleClaim(request, env);
		}
		return json({ status: 'ok', service: 'pocketcoder-oauth-relay' }, 200);
	},
};

// ---------------------------------------------------------------------------
// GET /callback
// ---------------------------------------------------------------------------

async function handleCallback(url, env) {
	const code = url.searchParams.get('code');
	const stateParam = url.searchParams.get('state');
	const providerError = url.searchParams.get('error');

	if (providerError) {
		return redirectToApp({ error: providerError });
	}
	if (!code || !stateParam) {
		return redirectToApp({ error: 'missing_code_or_state' });
	}

	const state = parseState(stateParam);
	if (!state || !state.p || !state.cc) {
		return redirectToApp({ error: 'invalid_state' });
	}

	const provider = PROVIDERS[state.p];
	if (!provider) {
		return redirectToApp({ error: `unknown_provider:${state.p}` });
	}

	const envPrefix = state.p.toUpperCase();
	const clientId = env[`${envPrefix}_OAUTH_CLIENT_ID`];
	const clientSecret = env[`${envPrefix}_OAUTH_CLIENT_SECRET`];
	if (!clientId || !clientSecret) {
		console.error(`Missing OAuth client credentials for provider ${state.p}`);
		return redirectToApp({ error: 'server_misconfigured' });
	}

	// Must exactly match the redirect_uri the app sent to the provider at
	// authorize time (RFC 6749 §4.1.3) — the app builds it the same way:
	// `${relayBaseUrl}/callback`.
	const redirectUri = `${url.origin}/callback`;

	let tokenResp;
	try {
		tokenResp = await fetch(provider.tokenUrl, {
			method: 'POST',
			headers: {
				'Content-Type': 'application/json',
				Accept: 'application/json',
			},
			body: JSON.stringify({
				client_id: clientId,
				client_secret: clientSecret,
				code,
				redirect_uri: redirectUri,
			}),
		});
	} catch (e) {
		console.error('Token exchange request failed:', e.message);
		return redirectToApp({ error: 'token_exchange_failed' });
	}

	const tokenBody = await tokenResp.json().catch(() => null);
	if (!tokenResp.ok || !tokenBody || tokenBody.error || !tokenBody.access_token) {
		console.error('Token exchange rejected:', tokenResp.status, JSON.stringify(tokenBody));
		return redirectToApp({ error: (tokenBody && tokenBody.error) || 'token_exchange_rejected' });
	}

	const exchangeCode = crypto.randomUUID();
	await env.MCP_OAUTH_KV.put(
		`exchange:${exchangeCode}`,
		JSON.stringify({
			codeChallenge: state.cc,
			accessToken: tokenBody.access_token,
			refreshToken: tokenBody.refresh_token || null,
		}),
		{ expirationTtl: EXCHANGE_TTL_SECONDS }
	);

	// Tokens never ride in this redirect URL — only the one-time
	// exchange_code does. See the spec's Component 1.
	return redirectToApp({ exchange_code: exchangeCode, state: stateParam });
}

// ---------------------------------------------------------------------------
// POST /claim
// ---------------------------------------------------------------------------

async function handleClaim(request, env) {
	let body;
	try {
		body = await request.json();
	} catch (e) {
		return json({ error: 'invalid_json' }, 400);
	}

	const exchangeCode = body.exchange_code;
	const codeVerifier = body.code_verifier;
	if (!exchangeCode || !codeVerifier) {
		return json({ error: 'missing_exchange_code_or_code_verifier' }, 400);
	}

	const kvKey = `exchange:${exchangeCode}`;
	const raw = await env.MCP_OAUTH_KV.get(kvKey);
	if (!raw) {
		return json({ error: 'expired_or_already_claimed' }, 404);
	}
	const entry = JSON.parse(raw);

	const computedChallenge = await sha256Base64url(codeVerifier);

	// Delete on every outcome (match or mismatch), not just on success: a
	// single exchange_code must never be claimable twice, even by a retried
	// wrong verifier. Fail closed — this check is PKCE's entire purpose in
	// this flow.
	await env.MCP_OAUTH_KV.delete(kvKey);

	if (computedChallenge !== entry.codeChallenge) {
		return json({ error: 'verifier_mismatch' }, 400);
	}

	return json({ access_token: entry.accessToken, refresh_token: entry.refreshToken }, 200);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function redirectToApp(params) {
	const target = new URL('pocketcoder://oauth-callback');
	for (const [k, v] of Object.entries(params)) {
		if (v !== undefined && v !== null) target.searchParams.set(k, v);
	}
	return Response.redirect(target.toString(), 302);
}

function parseState(stateParam) {
	try {
		return JSON.parse(base64urlDecode(stateParam));
	} catch (e) {
		return null;
	}
}

function base64urlDecode(str) {
	const padLen = (4 - (str.length % 4)) % 4;
	const padded = str.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat(padLen);
	return atob(padded);
}

async function sha256Base64url(input) {
	const data = new TextEncoder().encode(input);
	const digest = await crypto.subtle.digest('SHA-256', data);
	return arrayBufferToBase64url(digest);
}

function arrayBufferToBase64url(buffer) {
	const bytes = new Uint8Array(buffer);
	let binary = '';
	for (let i = 0; i < bytes.length; i++) {
		binary += String.fromCharCode(bytes[i]);
	}
	return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function json(data, status = 200) {
	return new Response(JSON.stringify(data), {
		status,
		headers: { 'Content-Type': 'application/json' },
	});
}
```

- [ ] **Step 3: Local verification (no automated test harness — see task intro)**

Run:
```bash
cd workers/oauth-relay && npm install
```
Expected: `wrangler` installs, exits 0.

Create a local-only `workers/oauth-relay/.dev.vars` (gitignored by Step 1):
```
GITHUB_OAUTH_CLIENT_ID=test-client-id
GITHUB_OAUTH_CLIENT_SECRET=test-client-secret
```

Run (background):
```bash
cd workers/oauth-relay && npx wrangler dev --local --port 8788 &
sleep 3
```

Run and check each:
```bash
curl -s http://127.0.0.1:8788/
```
Expected: `{"status":"ok","service":"pocketcoder-oauth-relay"}`

```bash
curl -s -i "http://127.0.0.1:8788/callback?error=access_denied&state=x"
```
Expected: `HTTP/1.1 302` with `Location: pocketcoder://oauth-callback?error=access_denied`

```bash
curl -s -X POST http://127.0.0.1:8788/claim -H 'Content-Type: application/json' -d '{"exchange_code":"nonexistent","code_verifier":"x"}'
```
Expected: `{"error":"expired_or_already_claimed"}`, HTTP 404.

```bash
STATE=$(node -e "console.log(Buffer.from(JSON.stringify({p:'github',cc:'test-challenge'})).toString('base64url'))")
curl -s -i "http://127.0.0.1:8788/callback?code=fake-code&state=$STATE"
```
Expected: with fake `.dev.vars` credentials, this makes a real outbound call to `https://github.com/login/oauth/access_token`, which GitHub rejects (invalid client) — response is a `302` to `pocketcoder://oauth-callback?error=...` carrying GitHub's real error string. This confirms the request-building and error-redirect path works end to end; the only thing this local run cannot exercise is a *successful* exchange, which requires a real registered GitHub OAuth App (an operational, not code, prerequisite — see Task 1's follow-up note below).

Stop the dev server:
```bash
kill %1
```

- [ ] **Step 4: Note the operational prerequisite (not part of this task's code)**

Before this flow works end to end in any real deployment, someone with access to the PocketCoder Cloudflare account must, once:
1. Register a GitHub OAuth App with callback URL `https://<this-worker's-deployed-domain>/callback`.
2. `wrangler kv:namespace create MCP_OAUTH_KV` and paste the returned `id` into `wrangler.toml`.
3. `wrangler secret put GITHUB_OAUTH_CLIENT_ID` / `wrangler secret put GITHUB_OAUTH_CLIENT_SECRET` with the real values.
4. `wrangler deploy`.

This is out of scope for this plan's code changes (no code depends on the real values existing yet) but is required before Task 4's `githubOAuthClientId` placeholder can be replaced with a real one.

- [ ] **Step 5: Commit**

```bash
git add workers/oauth-relay
git commit -m "feat(oauth-relay): add Worker brokering PKCE OAuth for locally-run MCP servers"
```

---

### Task 2: `mcp_servers` schema — `oauth_provider`/`oauth_token_env_var`

**Files:**
- Modify: `server/pocketbase/pb_migrations/schema.json`
- Regenerated: `client/packages/pocketcoder_flutter/assets/pb_schema.json`, `client/packages/pocketcoder_flutter/lib/domain/models/mcp_server.dart`/`.freezed.dart`/`.g.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `mcp_servers.oauth_provider`/`oauth_token_env_var` (PocketBase text fields, both optional), and the equivalent `McpServer.oauthProvider`/`oauthTokenEnvVar` Dart fields Task 6 reads. Task 3's Go handler reads these two fields directly via `record.GetString(...)` — no Go model regen needed on the backend side (PocketBase Go code never uses generated structs for records).

This task follows root `CLAUDE.md`'s Model Generation Pipeline in full — schema changes go through `schema.json` + `export_schema.sh` + `generate_models.py` + `build_runner build`, not a new timestamped migration file (per that doc, until the two-file schema/seed split grows large enough to warrant otherwise — it hasn't).

- [ ] **Step 1: Add the two fields to `schema.json`**

In `server/pocketbase/pb_migrations/schema.json`, find the `mcp_servers` collection's `fields` array (search for `"name": "mcp_servers"`). Insert two new field objects immediately after the `config_schema` field's closing `}` and before the `created` autodate field's `{` (matches this file's existing 6-space-indent style):

```
      {
        "hidden": false,
        "id": "json3471781264",
        "maxSize": 0,
        "name": "config_schema",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "json"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text2094856317",
        "max": 0,
        "min": 0,
        "name": "oauth_provider",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text5817203964",
        "max": 0,
        "min": 0,
        "name": "oauth_token_env_var",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
        "hidden": false,
        "id": "autodate2990389176",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "presentable": false,
        "system": false,
        "type": "autodate"
      },
```

(`oauth_provider` empty = plain-secret server, all existing rows keep working unchanged. `oauth_token_env_var` names the `mcp.env` variable the access token lands under, e.g. `GITHUB_PERSONAL_ACCESS_TOKEN` — set by whoever registers the server, see Task 6's add-server dialog.)

- [ ] **Step 2: Validate the JSON**

Run:
```bash
python3 -c "import json; json.load(open('server/pocketbase/pb_migrations/schema.json'))" && echo OK
```
Expected: `OK`.

- [ ] **Step 3: Rebuild and restart the backend containers**

Run:
```bash
docker compose build pocketbase goose
docker compose up -d pocketbase goose
```
Expected: both build and start without error; PocketBase's `migratecmd.Automigrate` applies the two new fields to the running database on startup (confirm via `docker compose logs pocketbase | tail -30` — no migration errors).

- [ ] **Step 4: Export schema to the Flutter assets**

Run:
```bash
tooling/scripts/export_schema.sh
```
Expected: exits 0, `client/packages/pocketcoder_flutter/assets/pb_schema.json` is rewritten and now contains `oauth_provider`/`oauth_token_env_var` under `mcp_servers` (spot check: `grep -c oauth_token_env_var client/packages/pocketcoder_flutter/assets/pb_schema.json` returns `1` or more).

- [ ] **Step 5: Generate Dart models**

Run:
```bash
cd client/packages/pocketcoder_flutter && python3 scripts/generate_models.py
```
Expected: exits 0; `lib/domain/models/mcp_server.dart` now declares `String? oauthProvider` and `String? oauthTokenEnvVar` fields (spot check with `grep oauthProvider lib/domain/models/mcp_server.dart`).

- [ ] **Step 6: Run build_runner**

Run:
```bash
cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0, regenerates `mcp_server.freezed.dart`/`mcp_server.g.dart` with the two new fields wired into `fromJson`/`toJson`/`copyWith`.

- [ ] **Step 7: Commit**

```bash
git add server/pocketbase/pb_migrations/schema.json client/packages/pocketcoder_flutter/assets/pb_schema.json client/packages/pocketcoder_flutter/lib/domain/models/mcp_server.dart client/packages/pocketcoder_flutter/lib/domain/models/mcp_server.freezed.dart client/packages/pocketcoder_flutter/lib/domain/models/mcp_server.g.dart
git commit -m "feat(mcp): add oauth_provider/oauth_token_env_var to mcp_servers schema"
```

---

### Task 3: PocketBase token-intake endpoint

**Files:**
- Create: `server/pocketbase/internal/api/mcp_oauth.go`
- Create: `server/pocketbase/internal/api/mcp_oauth_test.go`
- Modify: `server/pocketbase/main.go`

**Interfaces:**
- Consumes: `mcp_servers.oauth_token_env_var` (Task 2), `mcp_servers.config` (existing json field), `hooks/mcp.go`'s existing `OnRecordAfterUpdateSuccess` re-render (unmodified — this task only needs to `app.Save()` correctly).
- Produces: `POST /api/pocketcoder/mcp_oauth/store {server_name, access_token, refresh_token}` (authenticated via `apis.RequireAuth()`, no role restriction — unlike `mcp.go`'s agent/admin-only `mcp_request` route, per the spec's Component 3, which specifies `apis.RequireAuth()` only). Task 5's `McpRepository.deliverOAuthToken` is the only consumer.

This is the spec's Component 3, and per the spec it is **not** written into `mcp-gateway`'s own OAuth credential-helper store (`pkg/oauth/token_store.go`) — that store belongs to the gateway's own DCR-based OAuth subsystem, which this design does not use at all (see the spec's Problem section). This handler only ever touches `mcp_servers.config`.

- [ ] **Step 1: Write the failing tests**

Create `server/pocketbase/internal/api/mcp_oauth_test.go`:
```go
package api

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	_ "github.com/qtpi-automaton/pocketcoder/backend/pb_migrations"
)

func newMcpServer(t *testing.T, app core.App, name, status string, extra map[string]any) *core.Record {
	t.Helper()
	col, err := app.FindCollectionByNameOrId("mcp_servers")
	if err != nil {
		t.Fatal(err)
	}
	rec := core.NewRecord(col)
	rec.Set("name", name)
	rec.Set("status", status)
	for k, v := range extra {
		rec.Set(k, v)
	}
	if err := app.Save(rec); err != nil {
		t.Fatalf("save mcp_servers: %v", err)
	}
	return rec
}

func TestStoreOAuthToken_MergesIntoExistingConfig(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	rec := newMcpServer(t, app, "github-mcp-server", "approved", map[string]any{
		"oauth_token_env_var": "GITHUB_PERSONAL_ACCESS_TOKEN",
		"config":              map[string]any{"OTHER_KEY": "keep-me"},
	})

	if err := storeOAuthToken(app, "github-mcp-server", "tok123", "refresh456"); err != nil {
		t.Fatalf("storeOAuthToken: %v", err)
	}

	got, err := app.FindRecordById("mcp_servers", rec.Id)
	if err != nil {
		t.Fatal(err)
	}
	config := map[string]any{}
	if err := got.UnmarshalJSONField("config", &config); err != nil {
		t.Fatal(err)
	}
	if config["OTHER_KEY"] != "keep-me" {
		t.Errorf("config = %v, want OTHER_KEY preserved", config)
	}
	if config["GITHUB_PERSONAL_ACCESS_TOKEN"] != "tok123" {
		t.Errorf("config = %v, want GITHUB_PERSONAL_ACCESS_TOKEN=tok123", config)
	}
	if config["GITHUB_PERSONAL_ACCESS_TOKEN_REFRESH_TOKEN"] != "refresh456" {
		t.Errorf("config = %v, want refresh token under the derived key", config)
	}
}

func TestStoreOAuthToken_NoRefreshToken_OmitsRefreshKey(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	newMcpServer(t, app, "github-mcp-server", "approved", map[string]any{
		"oauth_token_env_var": "GITHUB_PERSONAL_ACCESS_TOKEN",
	})

	if err := storeOAuthToken(app, "github-mcp-server", "tok123", ""); err != nil {
		t.Fatalf("storeOAuthToken: %v", err)
	}

	recs, err := app.FindRecordsByFilter("mcp_servers", "name = 'github-mcp-server'", "", 1, 0)
	if err != nil || len(recs) != 1 {
		t.Fatalf("lookup failed: %v", err)
	}
	config := map[string]any{}
	_ = recs[0].UnmarshalJSONField("config", &config)
	if _, ok := config["GITHUB_PERSONAL_ACCESS_TOKEN_REFRESH_TOKEN"]; ok {
		t.Errorf("config = %v, want no refresh-token key when refreshToken is empty", config)
	}
}

func TestStoreOAuthToken_ServerNotFound(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	err = storeOAuthToken(app, "does-not-exist", "tok", "")
	if err != errOAuthServerNotFound {
		t.Fatalf("err = %v, want errOAuthServerNotFound", err)
	}
}

func TestStoreOAuthToken_MissingOAuthTokenEnvVar(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	newMcpServer(t, app, "plain-secret-server", "approved", nil)

	err = storeOAuthToken(app, "plain-secret-server", "tok", "")
	if err != errOAuthNotConfigured {
		t.Fatalf("err = %v, want errOAuthNotConfigured", err)
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
cd server/pocketbase && go test ./internal/api/... -run TestStoreOAuthToken -v
```
Expected: compile error — `undefined: storeOAuthToken`, `undefined: errOAuthServerNotFound`, `undefined: errOAuthNotConfigured`.

- [ ] **Step 3: Implement `mcp_oauth.go`**

Create `server/pocketbase/internal/api/mcp_oauth.go`:
```go
/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: MCP OAuth Token Intake. Receives the
// {access_token, refresh_token} pair a client obtained via
// workers/oauth-relay's PKCE exchange (see
// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, Component 3)
// and writes it into the same mcp_servers.config JSON blob hooks/mcp.go's
// renderMcpConfig already turns into mcp.env — this is not a new
// secret-delivery path, it reuses the existing one. NOT written into
// mcp-gateway's own OAuth credential-helper store
// (pkg/oauth/token_store.go) — that store belongs to the gateway's own
// DCR-based OAuth subsystem, which this design does not use (see the
// spec's Problem section).
package api

import (
	"fmt"
	"log"

	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

var (
	errOAuthServerNotFound = fmt.Errorf("mcp_servers row not found")
	errOAuthNotConfigured  = fmt.Errorf("mcp_servers row has no oauth_token_env_var set")
)

// RegisterMcpOAuthApi registers the OAuth token-intake endpoint.
func RegisterMcpOAuthApi(app *pocketbase.PocketBase, e *core.ServeEvent) {
	e.Router.POST("/api/pocketcoder/mcp_oauth/store", func(re *core.RequestEvent) error {
		if re.Auth == nil {
			return re.JSON(401, map[string]string{"error": "Authentication required"})
		}

		var input struct {
			ServerName   string `json:"server_name"`
			AccessToken  string `json:"access_token"`
			RefreshToken string `json:"refresh_token"`
		}
		if err := re.BindBody(&input); err != nil {
			return re.JSON(400, map[string]string{"error": "Invalid request body"})
		}
		if input.ServerName == "" || input.AccessToken == "" {
			return re.JSON(400, map[string]string{"error": "server_name and access_token are required"})
		}

		if err := storeOAuthToken(app, input.ServerName, input.AccessToken, input.RefreshToken); err != nil {
			switch err {
			case errOAuthServerNotFound:
				return re.JSON(404, map[string]string{"error": "mcp server not found"})
			case errOAuthNotConfigured:
				return re.JSON(400, map[string]string{"error": "mcp server is not configured for OAuth (oauth_token_env_var unset)"})
			default:
				log.Printf("❌ [MCPOAuth] store failed for %q: %v", input.ServerName, err)
				return re.JSON(500, map[string]string{"error": "internal error"})
			}
		}

		log.Printf("✅ [MCPOAuth] stored OAuth token for server %q", input.ServerName)
		return re.JSON(200, map[string]any{"stored": true})
	}).Bind(apis.RequireAuth())
}

// storeOAuthToken merges access_token (and, if present, refresh_token) into
// the target mcp_servers row's existing `config` map — the same field
// hooks/mcp.go's renderMcpConfig already writes into mcp.env as `KEY=value`
// lines for every approved server. The env var name comes from that row's
// oauth_token_env_var field; the refresh token, if any, lands under
// "{oauth_token_env_var}_REFRESH_TOKEN" — a naming convention, not a
// separate schema field, since nothing consumes it yet (token refresh is
// out of scope, see the spec's Out of scope section).
//
// Saving the record fires hooks/mcp.go's OnRecordAfterUpdateSuccess
// handler, which re-renders mcp.env and restarts the gateway container
// whenever the row's *current* status is "approved" or "revoked" — no
// separate re-render call is needed here, and a still-"pending" row is
// correctly left out of the catalog until it's explicitly approved.
func storeOAuthToken(app core.App, serverName, accessToken, refreshToken string) error {
	records, err := app.FindRecordsByFilter(
		"mcp_servers",
		"name = {:name} && status != 'denied' && status != 'revoked'",
		"-created",
		1,
		0,
		map[string]any{"name": serverName},
	)
	if err != nil {
		return fmt.Errorf("query mcp_servers: %w", err)
	}
	if len(records) == 0 {
		return errOAuthServerNotFound
	}
	record := records[0]

	envVar := record.GetString("oauth_token_env_var")
	if envVar == "" {
		return errOAuthNotConfigured
	}

	config := map[string]any{}
	// Tolerant of no/malformed existing config, mirroring
	// renderMcpConfig's own UnmarshalJSONField usage — start fresh rather
	// than fail the whole request over an unrelated pre-existing field.
	_ = record.UnmarshalJSONField("config", &config)

	config[envVar] = accessToken
	if refreshToken != "" {
		config[envVar+"_REFRESH_TOKEN"] = refreshToken
	}
	record.Set("config", config)

	if err := app.Save(record); err != nil {
		return fmt.Errorf("save mcp_servers/%s: %w", record.Id, err)
	}
	return nil
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run:
```bash
cd server/pocketbase && go test ./internal/api/... -run TestStoreOAuthToken -v
```
Expected: all 4 tests PASS.

- [ ] **Step 5: Wire the route into `main.go`**

In `server/pocketbase/main.go`, inside the `app.OnServe().BindFunc(...)` block, add the new registration right after `api.RegisterMcpApi(app, e)`:

```go
		api.RegisterSSHApi(app, e)
		api.RegisterMcpApi(app, e)
		api.RegisterMcpOAuthApi(app, e)
		api.RegisterProxyApi(app, e)
```

- [ ] **Step 6: Full package build**

Run:
```bash
cd server/pocketbase && go build ./... && go vet ./...
```
Expected: builds clean, no vet warnings.

- [ ] **Step 7: Commit**

```bash
git add server/pocketbase/internal/api/mcp_oauth.go server/pocketbase/internal/api/mcp_oauth_test.go server/pocketbase/main.go
git commit -m "feat(mcp-oauth): add token-intake endpoint merging OAuth tokens into mcp_servers.config"
```

---

### Task 4: Flutter `IMcpOAuthService`/`McpOAuthService`

**Files:**
- Create: `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart`
- Create: `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart`
- Create: `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart`

**Interfaces:**
- Consumes: `flutter_web_auth_2` (already a dependency, `^3.1.2`), `crypto` (already a dependency, `^3.0.3`), `workers/oauth-relay`'s `/claim` route (Task 1).
- Produces: `IMcpOAuthService.authenticate(String provider) -> Future<McpOAuthTokenPair>` where `McpOAuthTokenPair = ({String accessToken, String? refreshToken})`. Task 5's `McpCubit.connectOAuth` is the only consumer.

Structured like `flutter_aeroform`'s `LinodeOAuthService` (PKCE verifier/challenge generation, the same `FlutterWebAuth2.authenticate(url:, callbackUrlScheme:)` call shape, the same `PlatformException(code: 'CANCELED')` handling) but **without** that file's dynamic-import test-mocking hack (`importFlutterWebAuth2`/`MockFlutterWebAuth2`) — this plan instead injects the web-auth call as a plain overridable field, which is simpler and doesn't need a try/catch around an import.

- [ ] **Step 1: Add `McpOAuthException`**

In `client/packages/pocketcoder_flutter/lib/domain/exceptions.dart`, add after the existing `McpException` class:
```dart
/// OAuth-flow-specific exceptions from McpOAuthService. `isCancelled` lets
/// callers (McpCubit) distinguish "user dismissed the browser sheet" (not
/// an error state — see the spec's Component 2 failure-mode list) from a
/// genuine failure.
class McpOAuthException extends DomainException {
  final bool isCancelled;

  McpOAuthException(super.message, [super.cause]) : isCancelled = false;

  McpOAuthException._(String message, {this.isCancelled = false, Object? cause})
      : super(message, cause);

  factory McpOAuthException.cancelled() =>
      McpOAuthException._('User cancelled the OAuth flow', isCancelled: true);
  factory McpOAuthException.unknownProvider(String provider) =>
      McpOAuthException._('Unknown OAuth provider: $provider');
  factory McpOAuthException.providerError(String error) =>
      McpOAuthException._('Provider returned an error: $error');
  factory McpOAuthException.claimFailed([dynamic cause]) =>
      McpOAuthException._('Failed to claim OAuth token', cause: cause);
}
```

- [ ] **Step 2: Write the interface**

Create `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart`:
```dart
/// Result of a completed OAuth exchange: the access token the target MCP
/// server will use as its bearer/PAT credential, and (if the provider
/// issued one) a refresh token. Ephemeral — never persisted client-side.
typedef McpOAuthTokenPair = ({String accessToken, String? refreshToken});

/// Client-side half of the MCP OAuth flow (see
/// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md, Component
/// 2). Runs the PKCE authorize/browser/claim dance against
/// workers/oauth-relay and hands back the resulting token pair. This
/// service is a courier, not a holder: callers are responsible for
/// delivering the returned token to this user's own PocketBase (Component
/// 3, via IMcpRepository.deliverOAuthToken) — McpOAuthService never stores
/// it (no flutter_secure_storage use here, unlike LinodeOAuthService's
/// provisioning token, which belongs to the app's own session — this token
/// belongs to the user's gateway).
abstract class IMcpOAuthService {
  /// Runs the full authorize -> browser -> claim flow for [provider] (e.g.
  /// "github") and returns the resulting token pair.
  ///
  /// Throws [McpOAuthException] on any failure, with `isCancelled: true`
  /// when the user dismissed the browser sheet.
  Future<McpOAuthTokenPair> authenticate(String provider);
}
```

- [ ] **Step 3: Add DI-provided config values**

In `client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart`, add to the `ExternalModule` class (after the existing `httpClient` getter):
```dart
  /// Base URL of workers/oauth-relay (Task 1). No trailing slash.
  /// TODO(mcp-oauth): replace with the real deployed Worker's custom
  /// domain once Task 1 Step 4's one-time `wrangler deploy` has run.
  @Named('mcpOAuthRelayBaseUrl')
  @lazySingleton
  String get mcpOAuthRelayBaseUrl =>
      'https://pocketcoder-oauth-relay.workers.dev';

  /// client_id of the centrally-registered GitHub OAuth App (not secret —
  /// safe to embed, same as Linode's `linodeClientId` in flutter_aeroform).
  /// TODO(mcp-oauth): replace with the real GitHub OAuth App's client_id
  /// once Task 1 Step 4's registration step has happened.
  @Named('githubOAuthClientId')
  @lazySingleton
  String get githubOAuthClientId => 'REPLACE_WITH_REAL_GITHUB_OAUTH_CLIENT_ID';
```

- [ ] **Step 4: Write the failing tests**

Create `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart`:
```dart
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/infrastructure/mcp/mcp_oauth_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  late McpOAuthService service;
  late MockHttpClient httpClient;

  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  setUp(() {
    httpClient = MockHttpClient();
    service = McpOAuthService(
      httpClient,
      'https://relay.example.com',
      'test-github-client-id',
    );
  });

  group('PKCE helpers', () {
    test('generateCodeVerifier produces a 64-char unreserved-charset string', () {
      final v = McpOAuthService.generateCodeVerifier();
      expect(v.length, 64);
      expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(v), isTrue);
    });

    test('generateCodeChallenge is deterministic S256 of the verifier', () {
      const verifier = 'fixed-test-verifier-value-1234567890';
      final a = McpOAuthService.generateCodeChallenge(verifier);
      final b = McpOAuthService.generateCodeChallenge(verifier);
      expect(a, b);
      expect(a, isNot(contains('=')));
    });

    test('encodeState round-trips provider + code_challenge', () {
      final state = McpOAuthService.encodeState(
        provider: 'github',
        codeChallenge: 'abc123',
      );
      final padded = base64Url.normalize(state);
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      expect(decoded, {'p': 'github', 'cc': 'abc123'});
    });
  });

  group('McpOAuthService.authenticate', () {
    test('cancelled browser sheet surfaces isCancelled=true', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) {
        throw PlatformException(code: 'CANCELED');
      };

      try {
        await service.authenticate('github');
        fail('expected McpOAuthException');
      } on McpOAuthException catch (e) {
        expect(e.isCancelled, isTrue);
      }
    });

    test('provider error in the callback URL surfaces as McpOAuthException', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        return 'pocketcoder://oauth-callback?error=access_denied';
      };

      await expectLater(
        () => service.authenticate('github'),
        throwsA(isA<McpOAuthException>().having((e) => e.isCancelled, 'isCancelled', isFalse)),
      );
    });

    test('unknown provider throws before launching the browser', () async {
      var launched = false;
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        launched = true;
        return '';
      };

      await expectLater(
        () => service.authenticate('unknown-provider'),
        throwsA(isA<McpOAuthException>()),
      );
      expect(launched, isFalse);
    });

    test('happy path calls /claim with the generated code_verifier and returns the token pair', () async {
      String? capturedBody;
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        expect(uri.host, 'github.com');
        expect(uri.queryParameters['code_challenge_method'], 'S256');
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=${uri.queryParameters['state']}';
      };
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((invocation) async {
        capturedBody = invocation.namedArguments[#body] as String;
        return http.Response(jsonEncode({'access_token': 'tok', 'refresh_token': 'ref'}), 200);
      });

      final pair = await service.authenticate('github');

      expect(pair.accessToken, 'tok');
      expect(pair.refreshToken, 'ref');
      final sentBody = jsonDecode(capturedBody!) as Map<String, dynamic>;
      expect(sentBody['exchange_code'], 'xyz');
      expect(sentBody['code_verifier'], isNotEmpty);
    });

    test('/claim non-200 response throws McpOAuthException', () async {
      service.webAuthLauncher = ({required String url, required String callbackUrlScheme}) async {
        final uri = Uri.parse(url);
        return 'pocketcoder://oauth-callback?exchange_code=xyz&state=${uri.queryParameters['state']}';
      };
      when(() => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')))
          .thenAnswer((_) async => http.Response(jsonEncode({'error': 'verifier_mismatch'}), 400));

      await expectLater(() => service.authenticate('github'), throwsA(isA<McpOAuthException>()));
    });
  });
}
```

- [ ] **Step 5: Run tests to verify they fail**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/mcp/mcp_oauth_service_test.dart
```
Expected: fails to compile — `mcp_oauth_service.dart` does not exist yet.

- [ ] **Step 6: Implement `McpOAuthService`**

Create `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart`:
```dart
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/core/try_operation.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';

/// Shape of FlutterWebAuth2.authenticate, injected so tests can substitute
/// a fake without a real platform channel — same call shape as
/// flutter_aeroform's LinodeOAuthService.authenticate(), but injected
/// directly rather than via that file's dynamic-import mocking hack.
typedef WebAuthLauncher = Future<String> Function({
  required String url,
  required String callbackUrlScheme,
});

/// Cloudflare-Worker-backed OAuth client for locally-run MCP catalog
/// servers that need a real user identity (GitHub today) rather than a
/// static API key. See i_mcp_oauth_service.dart's doc comment and
/// docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md Component 2.
///
/// `provider` is a per-call argument, not a constructor argument, even
/// though the spec's illustrative pseudocode shows
/// `McpOAuthService(provider: 'github')` — this class is a DI singleton
/// (registered once via @LazySingleton below, matching every other
/// single-implementation infrastructure class in this package, e.g.
/// AuthRepository/FilesRepository), so it can't be constructed fresh per
/// provider. The Worker and this provider registry are already generic by
/// construction, so a method parameter does the same job.
@LazySingleton(as: IMcpOAuthService)
class McpOAuthService implements IMcpOAuthService {
  static const _callbackScheme = 'pocketcoder';

  // Deliberately duplicated (not shared) with workers/oauth-relay's own
  // PROVIDERS map: the Worker never builds this authorize URL itself
  // (Decision 1 — no /start round trip), so the two registries only need
  // to describe the same OAuth Apps, not share code. Out of scope:
  // providers other than GitHub (see the spec's Out of scope section).
  static const _authorizeUrls = {
    'github': 'https://github.com/login/oauth/authorize',
  };
  static const _scopes = {
    'github': 'repo read:user',
  };

  final http.Client _httpClient;
  final String _relayBaseUrl;
  final Map<String, String> _clientIds;

  McpOAuthService(
    this._httpClient,
    @Named('mcpOAuthRelayBaseUrl') this._relayBaseUrl,
    @Named('githubOAuthClientId') String githubClientId,
  ) : _clientIds = {'github': githubClientId};

  /// Overridable in tests only — production code always uses the real
  /// FlutterWebAuth2.authenticate.
  @visibleForTesting
  WebAuthLauncher webAuthLauncher = FlutterWebAuth2.authenticate;

  @override
  Future<McpOAuthTokenPair> authenticate(String provider) {
    return tryMethod(() async {
      final authorizeUrl = _authorizeUrls[provider];
      final clientId = _clientIds[provider];
      final scope = _scopes[provider];
      if (authorizeUrl == null || clientId == null || scope == null) {
        throw McpOAuthException.unknownProvider(provider);
      }

      final codeVerifier = generateCodeVerifier();
      final codeChallenge = generateCodeChallenge(codeVerifier);
      final state = encodeState(provider: provider, codeChallenge: codeChallenge);
      final redirectUri = '$_relayBaseUrl/callback';

      final authUri = Uri.parse(authorizeUrl).replace(queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'scope': scope,
        'state': state,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
      });

      String callbackUrl;
      try {
        callbackUrl = await webAuthLauncher(
          url: authUri.toString(),
          callbackUrlScheme: _callbackScheme,
        );
      } on PlatformException catch (e) {
        if (e.code == 'CANCELED') {
          throw McpOAuthException.cancelled();
        }
        throw McpOAuthException('Web auth failed: ${e.code}', e);
      }

      final callback = Uri.parse(callbackUrl);
      final providerError = callback.queryParameters['error'];
      if (providerError != null) {
        throw McpOAuthException.providerError(providerError);
      }
      final exchangeCode = callback.queryParameters['exchange_code'];
      if (exchangeCode == null || exchangeCode.isEmpty) {
        throw McpOAuthException('Worker callback missing exchange_code');
      }

      return _claim(exchangeCode: exchangeCode, codeVerifier: codeVerifier);
    }, McpOAuthException.new, 'authenticate');
  }

  Future<McpOAuthTokenPair> _claim({
    required String exchangeCode,
    required String codeVerifier,
  }) async {
    final resp = await _httpClient.post(
      Uri.parse('$_relayBaseUrl/claim'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'exchange_code': exchangeCode,
        'code_verifier': codeVerifier,
      }),
    );

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (resp.statusCode != 200) {
      throw McpOAuthException.claimFailed(body['error']);
    }
    final accessToken = body['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw McpOAuthException.claimFailed('missing access_token in /claim response');
    }
    return (accessToken: accessToken, refreshToken: body['refresh_token'] as String?);
  }

  /// PKCE code_verifier per RFC 7636: 43-128 chars, unreserved charset.
  @visibleForTesting
  static String generateCodeVerifier() {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(64, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// S256 code_challenge: SHA-256 of the verifier, base64url without
  /// padding — the same transform workers/oauth-relay's /claim route
  /// re-derives from the verifier the app sends back.
  @visibleForTesting
  static String generateCodeChallenge(String codeVerifier) {
    final hash = sha256.convert(utf8.encode(codeVerifier));
    return base64Url.encode(hash.bytes).replaceAll('=', '');
  }

  /// Encodes {p: provider, cc: code_challenge} as base64url(JSON) into the
  /// OAuth `state` param. The Worker only ever decodes this at /callback
  /// time (see workers/oauth-relay/src/index.js's parseState).
  /// Plaintext, not HMAC-signed: code_challenge is not secret (RFC 7636
  /// §4.2) — see this plan's Global Constraints, Decision 1.
  @visibleForTesting
  static String encodeState({required String provider, required String codeChallenge}) {
    final json = jsonEncode({'p': provider, 'cc': codeChallenge});
    return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  }
}
```

- [ ] **Step 7: Run tests to verify they pass**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/mcp/mcp_oauth_service_test.dart
```
Expected: all tests PASS.

- [ ] **Step 8: Regenerate DI wiring**

Run:
```bash
cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0; `lib/app/bootstrap.config.dart` now registers `McpOAuthService` behind `IMcpOAuthService`.

- [ ] **Step 9: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_oauth_service.dart client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_oauth_service.dart client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_oauth_service_test.dart client/packages/pocketcoder_flutter/lib/domain/exceptions.dart client/packages/pocketcoder_flutter/lib/infrastructure/core/external_module.dart client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart
git commit -m "feat(mcp): add McpOAuthService — PKCE + flutter_web_auth_2 client for workers/oauth-relay"
```

---

### Task 5: Repository delivery + cubit connect/retry flow

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart`
- Modify: `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart`
- Modify: `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart`

**Interfaces:**
- Consumes: `IMcpOAuthService.authenticate` (Task 4), `POST /api/pocketcoder/mcp_oauth/store` (Task 3).
- Produces: `IMcpRepository.deliverOAuthToken(String serverName, {required String accessToken, String? refreshToken})`, `McpCubit.connectOAuth(McpServer server)`, `McpCubit.retryOAuthDelivery(String serverId)`, `McpCubit.hasPendingOAuthDelivery(String serverId)`. Task 6's UI is the only consumer of the cubit methods.

Implements the spec's Component 2 failure-mode requirement: "`/claim` succeeds but the subsequent PocketBase delivery fails — retry with backoff before giving up, and on final failure keep the token in memory long enough to offer a one-tap retry without re-running the whole browser flow."

- [ ] **Step 1: Add the endpoint constant**

In `client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart`, add under a new `// MCP OAUTH ENDPOINTS` section (after `SKILLS ENDPOINTS`, before `SCHEDULER ENDPOINTS`):
```dart
  // ===========================================================================
  // MCP OAUTH ENDPOINTS
  // ===========================================================================

  /// POST /api/pocketcoder/mcp_oauth/store
  /// Merges an OAuth {access_token, refresh_token} pair into the target
  /// mcp_servers row's config, which hooks/mcp.go renders into mcp.env.
  static const String mcpOAuthStore = '/api/pocketcoder/mcp_oauth/store';
```
And add `mcpOAuthStore` to the `all` list.

- [ ] **Step 2: Write the failing repository test**

In `client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart`, add (the file already mocks `McpServerDao`; extend the mock to also stub `.pb`):
```dart
import 'package:pocketbase/pocketbase.dart';

class MockPocketBase extends Mock implements PocketBase {}
```
and, inside `main()`, add a new group:
```dart
  group('McpRepository.deliverOAuthToken', () {
    late MockPocketBase pb;

    setUp(() {
      pb = MockPocketBase();
      when(() => dao.pb).thenReturn(pb);
    });

    test('POSTs server_name/access_token/refresh_token to mcpOAuthStore', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method'), body: any(named: 'body')))
          .thenAnswer((_) async => {'stored': true});

      await repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok', refreshToken: 'ref');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/mcp_oauth/store',
            method: 'POST',
            body: {
              'server_name': 'github-mcp-server',
              'access_token': 'tok',
              'refresh_token': 'ref',
            },
          )).called(1);
    });

    test('omits refresh_token when null', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method'), body: any(named: 'body')))
          .thenAnswer((_) async => {'stored': true});

      await repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok');

      verify(() => pb.send<dynamic>(
            '/api/pocketcoder/mcp_oauth/store',
            method: 'POST',
            body: {'server_name': 'github-mcp-server', 'access_token': 'tok'},
          )).called(1);
    });

    test('wraps failures in McpException', () async {
      when(() => pb.send<dynamic>(any(), method: any(named: 'method'), body: any(named: 'body')))
          .thenThrow(Exception('boom'));

      await expectLater(
        () => repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok'),
        throwsA(isA<McpException>()),
      );
    });
  });
```
(`dao.pb` requires `McpServerDao` to expose `pb` — it already does, via `BaseDao.pb`.)

- [ ] **Step 3: Run to verify it fails**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/mcp/mcp_repository_test.dart
```
Expected: compile error — `deliverOAuthToken` undefined on `IMcpRepository`/`McpRepository`.

- [ ] **Step 4: Implement `deliverOAuthToken`**

In `client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart`, add to the abstract class:
```dart
  Future<void> deliverOAuthToken(
    String serverName, {
    required String accessToken,
    String? refreshToken,
  });
```

In `client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart`, add (needs `import 'package:pocketcoder_flutter/infrastructure/core/api_endpoints.dart';`):
```dart
  @override
  Future<void> deliverOAuthToken(
    String serverName, {
    required String accessToken,
    String? refreshToken,
  }) async {
    return tryMethod(
      () async {
        await _mcpServerDao.pb.send<dynamic>(
          ApiEndpoints.mcpOAuthStore,
          method: 'POST',
          body: {
            'server_name': serverName,
            'access_token': accessToken,
            if (refreshToken != null && refreshToken.isNotEmpty) 'refresh_token': refreshToken,
          },
        );
      },
      McpException.new,
      'deliverOAuthToken',
    );
  }
```

- [ ] **Step 5: Run to verify it passes**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter test test/infrastructure/mcp/mcp_repository_test.dart
```
Expected: all tests PASS.

- [ ] **Step 6: Write the failing cubit tests**

In `client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart`, add:
```dart
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';

class MockMcpOAuthService extends Mock implements IMcpOAuthService {}
```
Update `buildCubit`/`setUp` to construct `McpCubit(repo, oauthService)` and add:
```dart
  late MockMcpOAuthService oauthService;
  // (inside setUp) oauthService = MockMcpOAuthService();

  McpServer oauthServer({String status = 'approved'}) => McpServer.fromJson({
        'id': 'srv1',
        'name': 'github-mcp-server',
        'status': status,
        'oauth_provider': 'github',
      });

  group('McpCubit.connectOAuth', () {
    test('delivers the token pair to the repository on success', () async {
      when(() => oauthService.authenticate('github'))
          .thenAnswer((_) async => (accessToken: 'tok', refreshToken: 'ref'));
      when(() => repo.deliverOAuthToken(any(), accessToken: any(named: 'accessToken'), refreshToken: any(named: 'refreshToken')))
          .thenAnswer((_) async {});

      final cubit = buildCubit();
      await cubit.connectOAuth(oauthServer());

      verify(() => repo.deliverOAuthToken('github-mcp-server', accessToken: 'tok', refreshToken: 'ref')).called(1);
      expect(cubit.hasPendingOAuthDelivery('srv1'), isFalse);
    });

    test('cancelled auth does not emit an error state', () async {
      when(() => oauthService.authenticate('github')).thenThrow(McpOAuthException.cancelled());

      final cubit = buildCubit();
      await cubit.connectOAuth(oauthServer());

      expect(cubit.state.hasError, isFalse);
    });

    test('delivery failure after retries keeps the token pending for retryOAuthDelivery', () async {
      when(() => oauthService.authenticate('github'))
          .thenAnswer((_) async => (accessToken: 'tok', refreshToken: 'ref'));
      when(() => repo.deliverOAuthToken(any(), accessToken: any(named: 'accessToken'), refreshToken: any(named: 'refreshToken')))
          .thenThrow(Exception('pb unreachable'));

      final cubit = buildCubit();
      await cubit.connectOAuth(oauthServer());

      expect(cubit.state.hasError, isTrue);
      expect(cubit.hasPendingOAuthDelivery('srv1'), isTrue);

      // retryOAuthDelivery re-delivers without calling authenticate again.
      when(() => repo.deliverOAuthToken(any(), accessToken: any(named: 'accessToken'), refreshToken: any(named: 'refreshToken')))
          .thenAnswer((_) async {});
      await cubit.retryOAuthDelivery('srv1');

      verify(() => oauthService.authenticate('github')).called(1); // still only once
      expect(cubit.hasPendingOAuthDelivery('srv1'), isFalse);
    }, timeout: const Timeout(Duration(seconds: 10)));
  });
```

- [ ] **Step 7: Run to verify it fails**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter test test/application/mcp/mcp_cubit_test.dart
```
Expected: compile error — `McpCubit` doesn't take a second constructor argument, `connectOAuth`/`retryOAuthDelivery`/`hasPendingOAuthDelivery` undefined.

- [ ] **Step 8: Implement the cubit changes**

Replace the full contents of `client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart`:
```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:pocketcoder_flutter/domain/exceptions.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_oauth_service.dart';
import 'package:pocketcoder_flutter/domain/mcp/i_mcp_repository.dart';
import 'package:pocketcoder_flutter/domain/models/mcp_server.dart';
import "package:pocketcoder_flutter/infrastructure/core/logger.dart";
import 'mcp_state.dart';

/// A completed-but-undelivered OAuth grant, kept in memory only until
/// retryOAuthDelivery succeeds — see the spec's Component 2 failure-mode
/// list: "keep the token in memory long enough to offer a one-tap retry
/// without re-running the whole browser flow."
typedef _PendingOAuthDelivery = ({
  String serverId,
  String serverName,
  String accessToken,
  String? refreshToken,
});

@injectable
class McpCubit extends Cubit<McpState> {
  final IMcpRepository _repository;
  final IMcpOAuthService _oauthService;
  StreamSubscription? _subscription;

  _PendingOAuthDelivery? _pendingOAuthDelivery;

  McpCubit(this._repository, this._oauthService) : super(const McpState.initial());

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }

  void watchServers() {
    emit(const McpState.loading());
    _subscription?.cancel();
    _subscription = _repository.watchServers().listen(
      (servers) {
        emit(McpState.loaded(servers));
      },
      onError: (e) {
        logError('MCP: Failed to watch servers', e);
        emit(McpState.error(e.toString()));
      },
    );
  }

  Future<void> authorize(String id, {Map<String, dynamic>? config}) async {
    try {
      await _repository.authorizeServer(id, config: config);
    } catch (e) {
      logError('MCP: Failed to authorize server', e);
      emit(McpState.error(e.toString()));
    }
  }

  Future<void> deny(String id) async {
    try {
      await _repository.denyServer(id);
    } catch (e) {
      logError('MCP: Failed to deny server', e);
      emit(McpState.error(e.toString()));
    }
  }

  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
    String? oauthProvider,
    String? oauthTokenEnvVar,
  }) async {
    try {
      await _repository.createServer(
        name: name,
        image: image,
        config: config,
        oauthProvider: oauthProvider,
        oauthTokenEnvVar: oauthTokenEnvVar,
      );
    } catch (e) {
      logError('MCP: Failed to create server', e);
      emit(McpState.error(e.toString()));
    }
  }

  /// True once [serverId]'s OAuth grant was obtained but delivery to
  /// PocketBase failed after retries — the UI should offer a one-tap
  /// retry via [retryOAuthDelivery] instead of re-running [connectOAuth].
  bool hasPendingOAuthDelivery(String serverId) =>
      _pendingOAuthDelivery?.serverId == serverId;

  Future<void> connectOAuth(McpServer server) async {
    final provider = server.oauthProvider;
    if (provider == null || provider.isEmpty) {
      logError('MCP: connectOAuth called for a non-OAuth server', server.id);
      return;
    }
    try {
      final tokenPair = await _oauthService.authenticate(provider);
      await _deliverWithRetry(
        serverId: server.id,
        serverName: server.name,
        accessToken: tokenPair.accessToken,
        refreshToken: tokenPair.refreshToken,
      );
    } on McpOAuthException catch (e) {
      if (e.isCancelled) return; // dismissable, not an error state
      logError('MCP: OAuth authenticate failed', e);
      emit(McpState.error(e.toString()));
    } catch (e) {
      logError('MCP: OAuth authenticate failed', e);
      emit(McpState.error(e.toString()));
    }
  }

  Future<void> retryOAuthDelivery(String serverId) async {
    final pending = _pendingOAuthDelivery;
    if (pending == null || pending.serverId != serverId) return;
    await _deliverWithRetry(
      serverId: pending.serverId,
      serverName: pending.serverName,
      accessToken: pending.accessToken,
      refreshToken: pending.refreshToken,
    );
  }

  /// Retries deliverOAuthToken 3 times with 1s/2s/4s backoff before giving
  /// up. On final failure the grant is cached in [_pendingOAuthDelivery] so
  /// a later retryOAuthDelivery call can resume without re-running
  /// connectOAuth's browser step.
  Future<void> _deliverWithRetry({
    required String serverId,
    required String serverName,
    required String accessToken,
    String? refreshToken,
  }) async {
    const delays = [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 4)];
    for (var attempt = 0; attempt <= delays.length; attempt++) {
      try {
        await _repository.deliverOAuthToken(
          serverName,
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
        _pendingOAuthDelivery = null;
        return;
      } catch (e) {
        if (attempt == delays.length) {
          _pendingOAuthDelivery = (
            serverId: serverId,
            serverName: serverName,
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
          logError('MCP: OAuth token delivery failed after retries', e);
          emit(McpState.error(e.toString()));
          return;
        }
        await Future.delayed(delays[attempt]);
      }
    }
  }
}
```

Also extend `IMcpRepository.createServer` and `McpRepository.createServer` to accept and pass through `oauthProvider`/`oauthTokenEnvVar` (both nullable, mapped to the `oauth_provider`/`oauth_token_env_var` PocketBase field names):

In `i_mcp_repository.dart`:
```dart
  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
    String? oauthProvider,
    String? oauthTokenEnvVar,
  });
```

In `mcp_repository.dart`:
```dart
  @override
  Future<void> createServer({
    required String name,
    String? image,
    Map<String, dynamic>? config,
    String? oauthProvider,
    String? oauthTokenEnvVar,
  }) async {
    return tryMethod(
      () async {
        await _mcpServerDao.save(null, {
          'name': name,
          'status': 'approved',
          if (image != null && image.isNotEmpty) 'image': image,
          if (config != null) 'config': config,
          if (oauthProvider != null && oauthProvider.isNotEmpty) 'oauth_provider': oauthProvider,
          if (oauthTokenEnvVar != null && oauthTokenEnvVar.isNotEmpty) 'oauth_token_env_var': oauthTokenEnvVar,
        });
      },
      McpException.new,
      'createServer',
    );
  }
```

- [ ] **Step 9: Run to verify it passes**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter test test/application/mcp/mcp_cubit_test.dart test/infrastructure/mcp/mcp_repository_test.dart
```
Expected: all tests PASS (the retry test takes ~1s of real backoff delay — acceptable given the 10s per-test timeout set above; do not mock `Future.delayed` away, it's the actual behavior under test).

- [ ] **Step 10: Regenerate DI wiring**

Run:
```bash
cd client/packages/pocketcoder_flutter && dart run build_runner build --delete-conflicting-outputs
```
Expected: exits 0; `McpCubit`'s DI registration now injects both `IMcpRepository` and `IMcpOAuthService`.

- [ ] **Step 11: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/infrastructure/core/api_endpoints.dart client/packages/pocketcoder_flutter/lib/domain/mcp/i_mcp_repository.dart client/packages/pocketcoder_flutter/lib/infrastructure/mcp/mcp_repository.dart client/packages/pocketcoder_flutter/lib/application/mcp/mcp_cubit.dart client/packages/pocketcoder_flutter/test/infrastructure/mcp/mcp_repository_test.dart client/packages/pocketcoder_flutter/test/application/mcp/mcp_cubit_test.dart client/packages/pocketcoder_flutter/lib/app/bootstrap.config.dart
git commit -m "feat(mcp): deliver OAuth tokens to PocketBase with retry-and-resume on failure"
```

---

### Task 6: UI wiring — CONNECT button + add-server OAuth fields

**Files:**
- Modify: `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart`
- Modify: `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb` (+ regenerated localization files)

**Interfaces:**
- Consumes: `McpServer.oauthProvider`/`oauthTokenEnvVar` (Task 2), `McpCubit.connectOAuth`/`retryOAuthDelivery`/`hasPendingOAuthDelivery`/`createServer` (Task 5).
- Produces: end-user-visible "CONNECT"/"RETRY DELIVERY" actions and two new optional add-server fields. Nothing downstream consumes this task — it's the final, independently-droppable UI trigger per this plan's Global Constraints, Decision 4.

- [ ] **Step 1: Add l10n keys**

In `client/packages/pocketcoder_flutter/lib/l10n/app_en.arb`, add after the existing `"mcpAddConfigOptional"` entry (matching this file's flat-camelCase key convention, the one every existing `mcp*` key already uses):
```json
  "mcpAddConfigOptional": "Optional config (leave blank if none needed)",
  "mcpConnectCap": "CONNECT",
  "mcpRetryDeliveryCap": "RETRY DELIVERY",
  "mcpOauthRequiredLabel": "REQUIRES OAUTH: {provider}",
  "@mcpOauthRequiredLabel": {
    "placeholders": {
      "provider": { "type": "String" }
    }
  },
  "mcpOauthProviderOptionalLabel": "OAUTH PROVIDER (OPTIONAL)",
  "mcpOauthTokenEnvVarOptionalLabel": "OAUTH TOKEN ENV VAR (OPTIONAL)",
```

- [ ] **Step 2: Regenerate localization files**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter gen-l10n
```
Expected: exits 0; `lib/l10n/app_localizations.dart` (and per-locale files) now expose `mcpConnectCap` etc.

- [ ] **Step 3: Add the CONNECT/RETRY branch to `_buildMcpItem`**

In `client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart`, replace the existing button block (the `if (isPending) ... else if (server.status == McpServerStatus.approved) ...` `Row`s inside `_buildMcpItem`) with:
```dart
          if (server.oauthProvider?.isNotEmpty == true) ...[
            VSpace.x1,
            TerminalText.mini(
              context.l10n.mcpOauthRequiredLabel(server.oauthProvider ?? ''),
              color: colors.primary,
              alpha: 0.8,
            ),
            VSpace.x1,
            BlocBuilder<McpCubit, McpState>(
              builder: (context, _) {
                final cubit = context.read<McpCubit>();
                final pendingRetry = cubit.hasPendingOAuthDelivery(server.id);
                return Row(
                  children: [
                    Expanded(
                      child: TerminalButton(
                        label: pendingRetry
                            ? context.l10n.mcpRetryDeliveryCap
                            : context.l10n.mcpConnectCap,
                        onTap: () => pendingRetry
                            ? cubit.retryOAuthDelivery(server.id)
                            : cubit.connectOAuth(server),
                      ),
                    ),
                    if (server.status != McpServerStatus.pending) ...[
                      HSpace.x2,
                      TerminalButton(
                        label: context.l10n.mcpRevoke,
                        onTap: () => cubit.deny(server.id),
                        color: colors.error,
                      ),
                    ],
                  ],
                );
              },
            ),
          ] else if (isPending) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.mcpAuthorizeCap,
                    onTap: () => _showAuthorizeDialog(context, server),
                  ),
                ),
                HSpace.x2,
                TerminalButton(
                  label: 'DENY',
                  onTap: () => context.read<McpCubit>().deny(server.id),
                  color: colors.error,
                ),
              ],
            ),
          ] else if (server.status == McpServerStatus.approved) ...[
            VSpace.x1,
            Row(
              children: [
                Expanded(
                  child: TerminalButton(
                    label: context.l10n.mcpEditConfig,
                    isPrimary: false,
                    onTap: () => _showAuthorizeDialog(context, server),
                  ),
                ),
                HSpace.x2,
                TerminalButton(
                  label: context.l10n.mcpRevoke,
                  onTap: () => context.read<McpCubit>().deny(server.id),
                  color: colors.error,
                ),
              ],
            ),
          ],
```
(An OAuth-requiring server never shows the config-schema `AUTHORIZE`/`EDIT CONFIGURATION` dialog — there is nothing for a human to type; `_buildConfigSchemaList`'s call site above this block should also be skipped for OAuth servers, since `configSchema` isn't how OAuth servers receive their secret. Guard it: change `if (isPending && server.configSchema != null)` to `if (isPending && server.oauthProvider?.isEmpty != false && server.configSchema != null)`.)

- [ ] **Step 4: Extend the add-server dialog**

In `_showAddServerDialog`, add two more controllers and fields:
```dart
    final oauthProviderController = TextEditingController();
    final oauthTokenEnvVarController = TextEditingController();
```
add to the dialog's `content` column (after the `imageController` field):
```dart
            VSpace.x2,
            TerminalTextField(
              controller: oauthProviderController,
              label: context.l10n.mcpOauthProviderOptionalLabel,
              obscureText: false,
            ),
            VSpace.x2,
            TerminalTextField(
              controller: oauthTokenEnvVarController,
              label: context.l10n.mcpOauthTokenEnvVarOptionalLabel,
              obscureText: false,
            ),
```
and update the `ADD` button's `onPressed`:
```dart
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              cubit.createServer(
                name: name,
                image: imageController.text.trim().isEmpty
                    ? null
                    : imageController.text.trim(),
                oauthProvider: oauthProviderController.text.trim().isEmpty
                    ? null
                    : oauthProviderController.text.trim(),
                oauthTokenEnvVar: oauthTokenEnvVarController.text.trim().isEmpty
                    ? null
                    : oauthTokenEnvVarController.text.trim(),
              );
              Navigator.of(dialogContext).pop();
            },
```

- [ ] **Step 5: Static analysis**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter analyze lib/presentation/mcp/mcp_management_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 6: Full test suite for the MCP feature**

Run:
```bash
cd client/packages/pocketcoder_flutter && flutter test test/application/mcp/ test/infrastructure/mcp/
```
Expected: all tests PASS (this task adds no new automated widget tests — `McpManagementScreen` has no existing widget-test file to extend, matching this file's current test coverage; manual verification is via the `run` skill against a live deployment once Tasks 1–5 and the operational Worker/GitHub-App setup from Task 1 Step 4 are complete).

- [ ] **Step 7: Commit**

```bash
git add client/packages/pocketcoder_flutter/lib/presentation/mcp/mcp_management_screen.dart client/packages/pocketcoder_flutter/lib/l10n/app_en.arb client/packages/pocketcoder_flutter/lib/l10n/app_localizations.dart client/packages/pocketcoder_flutter/lib/l10n/app_localizations_en.dart
git commit -m "feat(mcp): add CONNECT/RETRY DELIVERY UI for OAuth-requiring MCP servers"
```

---

### Task 7: Shared deploy script for `workers/*`

**Files:**
- Create: `tooling/scripts/deploy-workers.sh`

**Interfaces:**
- Consumes: nothing (infra-only, wraps each worker's own `npm run deploy`).
- Produces: one command that deploys `push-relay`, `image-relay`, and
  `oauth-relay` in sequence.

`workers/push-relay` and `workers/image-relay` are deliberately kept as
independent Workers (own `wrangler.toml`, own `package.json`, own
secrets) rather than fused into one — matches this codebase's existing
split-by-concern pattern and keeps the GitHub `client_secret` this spec
introduces scoped away from the push/image workers' secrets. This task
only adds a convenience wrapper so deploying all three after a shared
change doesn't mean three manual `cd && npm run deploy` invocations; it
does not change any worker's code, config, or secret handling.

- [ ] **Step 1: Write the script**

Create `tooling/scripts/deploy-workers.sh`:

```bash
#!/usr/bin/env bash
# Deploys every workers/* Cloudflare Worker in sequence. Each worker stays
# an independent deploy (own wrangler.toml, own secrets) — this only saves
# running `npm run deploy` three times by hand after a shared change.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for worker_dir in "$repo_root"/workers/*/; do
  name="$(basename "$worker_dir")"
  echo "==> Deploying $name"
  (cd "$worker_dir" && npm run deploy)
done

echo "==> All workers deployed"
```

- [ ] **Step 2: Make executable, verify**

Run:
```bash
chmod +x tooling/scripts/deploy-workers.sh
bash -n tooling/scripts/deploy-workers.sh
```
Expected: `bash -n` (syntax check only) exits 0, no output.

- [ ] **Step 3: Commit**

```bash
git add tooling/scripts/deploy-workers.sh
git commit -m "chore(workers): add shared deploy script for push-relay/image-relay/oauth-relay"
```
