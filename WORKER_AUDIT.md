# PocketCoder Worker Audit

Audit scope: all central Cloudflare Workers under `workers/`.

The intended security boundary from [`CLAUDE.md`](CLAUDE.md) is that central Workers may provide shared infrastructure, but user credentials should remain in the user's deployment or client whenever possible.

## Reviewer addendum (second pass)

Independent second read of the same three Workers, cross-checked against this document. Agreement with the great majority of it, including several findings this pass didn't catch on its own (`no-store` missing on token responses, redirect_uri trusting `url.origin`, the `/claim` get/verify/delete race, image-relay's wildcard CORS). Two adjustments and one addition worth flagging:

- **IMAGE-001**: framing this as "the clearest violation" of CLAUDE.md's boundary overstates it. CLAUDE.md's invariant is specifically about centralizing *OAuth app registrations/secrets* that require a human to register once with a third party — Linode's OAuth is a true public/PKCE client with no `client_secret`, and the app already holds the raw token itself; routing it through image-relay is a deliberate perf tradeoff (streaming a 300MB image the phone can't push itself), not a leak of a secret that was supposed to stay server-side. Worth keeping as a finding (a bearer credential does transit infra we operate, and IMAGE-002's points about no additional auth + wildcard CORS still stand on their own merits), just not at High severity under this particular rationale.
- **OAUTH-004**: the KV get/verify/delete race is real, but PKCE means only a caller who already knows the correct `code_verifier` can pass the check either way — so the worst case of the race is a legitimate client's own retried request double-claiming its own token, not an attacker without the verifier claiming someone else's. Would downgrade from Medium to Low.
- **PUSH-002/005 — missing the actual root cause**: neither finding states that `PN_RELAY_SECRET` is one identical value baked into *every* self-hosted deployment's `docker-compose` env at provisioning time (confirmed in `elestio.yml`, `tooling/scripts/elestio/postInstall.sh`, `docker-compose.yml`), and that the endpoint never scopes `user_id`/`token` to the caller who presents it. That's not "replay protection is missing" (PUSH-005) or "an attacker who obtains the secret" (PUSH-001) — every legitimate self-hoster already has this secret as part of normal provisioning, with no per-tenant binding at all. Added as **PUSH-006** below, since it changes the severity calculus on PUSH-002 (fail-open) too: a malicious tenant can likely force the Supabase RPC to error on demand with a malformed `user_id`, making quota-bypass reliable rather than outage-dependent.

## Executive summary

| Worker | Role | Audit status |
|---|---|---|
| `oauth-relay` | OAuth broker for GitHub and Linode | Mostly standard Authorization Code + PKCE, but has token-handling hardening gaps and custom broker endpoints |
| `image-relay` | R2 image transfer and Linode image API proxy | Does receive user Linode bearer tokens; conflicts with the no-user-credentials-in-central-Workers goal |
| `push-relay` | Push notification, billing/quota, and FCM relay | Uses standard Google service-account OAuth for its own service credential; has unrelated SSRF and fail-open authorization issues |

OAuth does not eliminate sensitive credentials. It prevents the application from receiving the user's password. Access tokens and refresh tokens remain bearer credentials and must be held by whichever component calls the provider. The security goal is therefore to minimize custody, retention, scope, logging, and exposure.

## 1. `oauth-relay`

### Current flow

1. The app creates a PKCE verifier and S256 challenge.
2. `GET /authorize` builds a provider-specific authorization URL.
3. The provider redirects to `GET /callback` with an authorization code.
4. The Worker exchanges the code using its centrally-held client secret.
5. The Worker stores the resulting access/refresh token pair in KV for 60 seconds.
6. The app calls `POST /claim` with the exchange code and PKCE verifier.
7. The Worker returns the token pair to the app, which delivers it to the user's own deployment.

### What is standard

- Authorization Code grant is used.
- PKCE with `S256` is used.
- The user's password is never sent to PocketCoder.
- Provider URLs, client IDs, scopes, and client secrets are kept server-side.
- Provider selection is allowlisted with `Object.hasOwn`.
- The authorization redirect is built from an explicit parameter set rather than forwarding arbitrary query parameters.
- Access tokens are not placed directly in the browser/deep-link redirect.
- Provider token exchange uses the standard refresh-token grant when `/refresh` is used.

### Custom, but intentional

`/claim` is not an OAuth-defined endpoint. It is a relay-specific handoff that converts a short-lived Worker exchange code plus PKCE verifier into the provider token. This is defensible for a native-app broker, but it should be documented as a custom transport layer rather than described as pure OAuth.

`/refresh` is also a custom relay endpoint. The upstream request uses the standard OAuth `grant_type=refresh_token`, but the public Worker route is not a standard OAuth token endpoint.

### Findings

#### OAUTH-001 — Token responses lack `no-store` headers

Severity: High

`POST /claim` and `POST /refresh` return access and refresh tokens without `Cache-Control: no-store`:

- [`workers/oauth-relay/src/index.js:298`](workers/oauth-relay/src/index.js#L298)
- [`workers/oauth-relay/src/index.js:353`](workers/oauth-relay/src/index.js#L353)

The authorization redirect has `no-store`, but the token-bearing responses do not. Intermediaries, browser layers, or debugging infrastructure must not cache these responses.

Remediation: add `Cache-Control: no-store` and preferably `Pragma: no-cache` to every token-bearing response.

#### OAUTH-002 — Full provider error response may be logged

Severity: High

The failed authorization-code exchange logs the entire decoded provider response:

- [`workers/oauth-relay/src/index.js:237`](workers/oauth-relay/src/index.js#L237)
- [`workers/oauth-relay/src/index.js:239`](workers/oauth-relay/src/index.js#L239)

Although providers normally return an error object, a malformed or unusual response could include token-like or other sensitive fields.

Remediation: log only HTTP status and a fixed allowlisted error code. Never serialize the full provider response.

#### OAUTH-003 — Redirect URI is derived from the inbound request origin

Severity: Medium

Both authorization and token exchange derive the redirect URI from `url.origin`:

- [`workers/oauth-relay/src/index.js:148`](workers/oauth-relay/src/index.js#L148)
- [`workers/oauth-relay/src/index.js:218`](workers/oauth-relay/src/index.js#L218)

This allows alternate hostnames or host-header routing to influence the redirect URI. It can also cause authorization-code exchange failures if the provider registration contains only the canonical hostname.

Remediation: configure a canonical `OAUTH_RELAY_BASE_URL`, construct the redirect URI from it, and reject requests whose host is not approved.

#### OAUTH-004 — Claim is not atomically one-time

Severity: Low

`/claim` performs KV `get`, PKCE verification, and KV `delete` as separate operations:

- [`workers/oauth-relay/src/index.js:280`](workers/oauth-relay/src/index.js#L280)
- [`workers/oauth-relay/src/index.js:292`](workers/oauth-relay/src/index.js#L292)

Two concurrent requests can potentially read the same exchange entry before either deletion completes. PKCE prevents an attacker without the verifier from claiming it, but the documented one-time property is not absolute.

Remediation: use an atomic claim primitive, such as a Durable Object, or redesign the exchange so the authorization code is consumed by a serialized stateful component.

Status: Accepted residual risk. PKCE prevents an attacker without the verifier from claiming another client's exchange; this remains a correctness limitation rather than a credential exposure.

#### OAUTH-005 — Provider error text is copied into the deep-link URL

Severity: Medium

The callback forwards the provider's raw `error` value to the app:

- [`workers/oauth-relay/src/index.js:186`](workers/oauth-relay/src/index.js#L186)
- [`workers/oauth-relay/src/index.js:188`](workers/oauth-relay/src/index.js#L188)

The value is URL-encoded, but it can still expose provider-controlled diagnostic text to application URL handlers and logs.

Remediation: map provider errors to a fixed allowlist such as `access_denied`, `invalid_request`, and `provider_error`. Do not forward arbitrary descriptions.

#### OAUTH-006 — Token-bearing custom endpoints need explicit replay and abuse controls

Severity: Medium

`/claim` and `/refresh` are public routes. PKCE protects the authorization-code handoff, but `/refresh` accepts any bearer refresh token and has no rate limiting or provider/token binding beyond the upstream provider's validation:

- [`workers/oauth-relay/src/index.js:310`](workers/oauth-relay/src/index.js#L310)
- [`workers/oauth-relay/src/index.js:318`](workers/oauth-relay/src/index.js#L318)

Remediation: add rate limits, strict body-size/type validation, no-store headers, and consider whether refresh should be handled by the user's deployment instead of the central Worker.

#### OAUTH-007 — No explicit canonical origin or deployment test is checked in

Severity: Low/Operational

The Worker source assumes that the request origin is the registered OAuth callback. The custom domain exists operationally, but the Worker configuration does not express or validate it.

Remediation: add the canonical base URL to Worker configuration and add tests for the production custom domain, alternate Host headers, provider errors, token response headers, and PKCE claim behavior.

## 2. `image-relay`

### Dead-code finding — `/upload-image`, `/image-status`, and the queue path are unreachable

Confirmed against `flutter_aeroform` (the only caller): `IInstanceProvisioningStrategy` is resolved via DI without a name in `flutter_aeroform.module.dart`, which binds to `BootTimePullProvisioningStrategy` — the only strategy that calls `/image-manifest`. `CustomImageProvisioningStrategy` (the only caller of `/upload-image` and `/image-status`) is registered solely under `@Named('customImage')`, and nothing in the codebase looks it up by that name — it is never instantiated. Its own doc comment confirms this directly: *"no longer the default for Linode... its known bugs (in image-relay's Worker code, not here) are deliberately unfixed."* This matches `wrangler.toml`'s already-disabled queue consumer and its comment citing `2026-07-29-linode-boot-time-image-provisioning-design.md`, "Strategy 1."

Net effect: IMAGE-001, IMAGE-002, and IMAGE-003 below all concern code paths (`/upload-image`, `/image-status`, `streamImageToLinode`, the queue producer/consumer) that no live code calls. This isn't a hardening question, it's dead-code removal — deleting those routes plus `CustomImageProvisioningStrategy` and its DI registration resolves all three findings with no functional risk. `/image-manifest` and `/health` are the only routes actually load-bearing (used by `BootTimePullProvisioningStrategy`, the real default) and should stay.

### Current behavior

The Worker accepts a Linode bearer token from the caller and uses it to call Linode's Images API:

- [`workers/image-relay/src/index.ts:18`](workers/image-relay/src/index.ts#L18)
- [`workers/image-relay/src/index.ts:87`](workers/image-relay/src/index.ts#L87)
- [`workers/image-relay/src/index.ts:121`](workers/image-relay/src/index.ts#L121)
- [`workers/image-relay/src/index.ts:189`](workers/image-relay/src/index.ts#L189)
- [`workers/image-relay/src/index.ts:227`](workers/image-relay/src/index.ts#L227)

This is not an OAuth exchange. It is a bearer-token proxy. The Worker does not receive the user's password, but it does receive a powerful user credential.

### Findings

#### IMAGE-001 — Central Worker receives user Linode bearer tokens

Severity: High

`/upload-image` and `/image-status` accept `linodeToken` in JSON and send it to Linode. This directly violates the desired invariant that central Workers should not receive user credentials.

Remediation: remove these routes if they are legacy and unused. Prefer having the client or the user's own deployment call Linode directly using the token obtained through the OAuth flow. If a proxy is unavoidable, use a narrowly scoped, short-lived capability minted by the user's deployment rather than the raw Linode token.

Status: Resolved by removing the token-bearing routes and the legacy client strategy. The image Worker now serves only the public manifest and health endpoint.

#### IMAGE-002 — Token proxy routes have no authentication

Severity: High

The Worker accepts the token-bearing routes without a Worker authentication header or deployment identity. CORS is also wildcarded:

- [`workers/image-relay/src/index.ts:31`](workers/image-relay/src/index.ts#L31)
- [`workers/image-relay/src/index.ts:45`](workers/image-relay/src/index.ts#L45)

The token itself is the only effective authorization. Any caller who obtains it can use the Worker as a proxy.

Remediation: remove the routes or require authenticated, deployment-scoped requests. Do not use wildcard CORS for credential-bearing APIs.

Status: Resolved by removing the credential-bearing routes.

#### IMAGE-003 — Upload capability URL is placed in a queue

Severity: Medium

The Linode `upload_to` URL is placed in the Cloudflare Queue:

- [`workers/image-relay/src/index.ts:14`](workers/image-relay/src/index.ts#L14)
- [`workers/image-relay/src/index.ts:145`](workers/image-relay/src/index.ts#L145)

That URL is a bearer capability. The queue consumer is currently disabled in `wrangler.toml`, so stale messages may remain without a functioning consumer.

Remediation: remove the producer route if the legacy path is unused. Otherwise ensure the queue has a consumer, enforce expiry/ownership where possible, and never log the URL.

Status: Resolved by removing the upload route and queue producer.

#### IMAGE-004 — Upstream Linode error bodies are returned to callers

Severity: Low/Medium

The Worker includes the raw Linode response body in its error response:

- [`workers/image-relay/src/index.ts:132`](workers/image-relay/src/index.ts#L132)

Remediation: return a generic error to callers and log only sanitized diagnostic metadata.

#### IMAGE-005 — No request validation or rate limiting

Severity: Medium

The Worker accepts arbitrary labels and regions, does not cap request body size, and has no rate limiting. This can be abused to spend the user's Linode quota or generate repeated image operations.

Remediation: validate labels/regions, enforce body limits, add per-deployment rate limits, and make operations idempotent with a server-side request identifier.

## 3. `push-relay`

### Current behavior

The Worker receives a shared PocketBase relay secret, a device token, user ID, and notification content. It then checks subscription/quota status and sends through FCM or UnifiedPush.

### OAuth assessment

The FCM credential flow is standard Google OAuth 2.0 JWT bearer:

1. The Worker signs a short-lived service-account JWT.
2. It exchanges the JWT at Google's token endpoint.
3. It caches the resulting service access token in memory.

This is a central service credential, not an end-user OAuth credential:

- [`workers/push-relay/src/index.js:285`](workers/push-relay/src/index.js#L285)
- [`workers/push-relay/src/index.js:304`](workers/push-relay/src/index.js#L304)

### Findings

#### PUSH-001 — UnifiedPush endpoint is an SSRF primitive

Severity: High

The authenticated caller supplies `token`, which is treated as an arbitrary URL and fetched by the Worker:

- [`workers/push-relay/src/index.js:50`](workers/push-relay/src/index.js#L50)
- [`workers/push-relay/src/index.js:374`](workers/push-relay/src/index.js#L374)

Anyone who obtains `PN_RELAY_SECRET` can make the Worker send requests to arbitrary internet destinations.

Remediation: validate UnifiedPush endpoints against an explicit HTTPS hostname allowlist, or route UnifiedPush directly from the user's deployment instead of accepting arbitrary URLs centrally.

#### PUSH-002 — Subscription and quota failures fail open

Severity: High

Unexpected RevenueCat failures return premium/allowed, and Supabase failures return zero usage:

- [`workers/push-relay/src/index.js:162`](workers/push-relay/src/index.js#L162)
- [`workers/push-relay/src/index.js:185`](workers/push-relay/src/index.js#L185)
- [`workers/push-relay/src/index.js:208`](workers/push-relay/src/index.js#L208)

This permits subscription and quota bypass during dependency failures.

Remediation: fail closed for paid-path enforcement, with a narrowly defined temporary outage policy if notification availability is more important than billing enforcement.

#### PUSH-003 — Central Worker receives user notification content and device identifiers

Severity: Medium/Privacy

The Worker receives FCM/UnifiedPush tokens, PocketBase user IDs, chat IDs, titles, and messages:

- [`workers/push-relay/src/index.js:43`](workers/push-relay/src/index.js#L43)
- [`workers/push-relay/src/index.js:226`](workers/push-relay/src/index.js#L226)

These are not OAuth credentials, but they are user data. Notification messages should be minimized and must not contain secrets, raw credentials, or full tool arguments.

Remediation: send opaque notification identifiers where possible and retrieve details from the user's deployment after opening the app.

#### PUSH-004 — Raw upstream error text is exposed

Severity: Low/Medium

The Worker returns exception messages to callers and logs complete FCM error objects:

- [`workers/push-relay/src/index.js:82`](workers/push-relay/src/index.js#L82)
- [`workers/push-relay/src/index.js:270`](workers/push-relay/src/index.js#L270)

Remediation: return stable error codes and log sanitized status/error codes only.

#### PUSH-005 — No explicit body limits or replay protection

Severity: Medium

The relay accepts a per-user header secret and arbitrary JSON payloads. There is no timestamp, nonce, signature, body-size limit, or per-deployment rate limit.

Remediation: use an authenticated request scheme with timestamp/nonce replay protection, strict schemas, size limits, and rate limiting.

#### PUSH-006 — Shared secret provides no tenant isolation; any deployment can act as any other user

Severity: High

`PN_RELAY_SECRET` was a single value set once via `wrangler secret put` on the Worker side, but every Aeroform-provisioned deployment was given the *same* value in its own `docker-compose` environment:

- [`elestio.yml:30`](elestio.yml#L30)
- [`tooling/scripts/elestio/postInstall.sh:31`](tooling/scripts/elestio/postInstall.sh#L31)
- [`docker-compose.yml:34`](docker-compose.yml#L34)

The Worker now hashes the presented secret and binds it to the first `user_id` through the `bind_relay_secret` RPC. A later mismatched user is rejected, and `user_id` is mandatory for FCM. This is a trust-on-first-use binding; provisioning must still ensure each deployment receives a distinct secret.

Status: Resolved in the Worker and schema. Remaining deployment follow-up: existing deployments must receive regenerated per-deployment secrets.

#### PUSH-007 — Shared-secret comparison is not constant-time

Severity: Low

The old comparison was removed with the global secret check. The Worker now uses a SHA-256 digest for tenant binding, so this specific comparison finding is resolved.

Status: Resolved.

## Cross-Worker conclusions

### Credentials currently held by central Workers

- `oauth-relay`: centrally-held OAuth client secrets; transient user access/refresh tokens during the standard broker flow.
- `image-relay`: no user credentials; it serves only the public image manifest and health endpoint.
- `push-relay`: central RevenueCat, Supabase, Firebase service credentials and short-lived Google service access tokens; no user OAuth credentials.

### Recommended remediation order

1. Deploy the image-relay route removal and clean up any existing queue configuration.
2. Add `no-store` to all OAuth token responses and remove full token-response logging.
3. Replace inbound-origin redirect construction with a configured canonical origin.
4. Make OAuth exchange-code consumption atomic.
5. Sanitize OAuth callback errors and all Worker error logging.
6. Lock down UnifiedPush URL handling and change push billing/quota checks to fail closed.
7. Add Worker-level tests for token non-caching, redirect-host validation, PKCE failures, replay/concurrency, CORS, SSRF, and body limits.

## Verification notes

- `oauth-relay`'s Wrangler identity remains `pocketcoder-oauth-relay`.
- The custom domain remains `oauth.relay.pocketcoder.org`.
- The rename from `workers/mcp-oauth-relay` to `workers/oauth-relay` does not change Cloudflare identity by itself.
- No Worker test script currently exists; the Worker packages expose only `dev` and `deploy` scripts.
