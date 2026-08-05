# MCP OAuth Flow — Design

## Problem

Some MCP servers behind the gateway (GitHub, Notion, Linear, and any future
remote server that needs a user's identity rather than a static API key)
require OAuth, not a plain secret. `docker/mcp-gateway` (what
`docker-compose.yml`'s `mcp-gateway` service runs today,
`--transport streaming` per the governance-UI spec) has three OAuth modes
(`pkg/oauth/mode.go`): `ModeDesktop` (Desktop catalog servers, via Docker's
own hosted Secrets Engine), `ModeCommunity` (Desktop + community server,
via local `docker pass`), and `ModeCE` (no Desktop — what a headless
container runs, confirmed via `IsCEMode()` returning true whenever there's
no Desktop socket). `mcp-gateway` running standalone in our container is
always CE mode.

CE mode's `docker mcp oauth authorize` opens a browser and a callback
server on a **fixed** port, `54321` by default
(`pkg/oauth/callback_server.go`'s `DefaultOAuthPort`, overridable via
`MCP_GATEWAY_OAUTH_PORT`), and stores the resulting token via the system
credential helper. That assumes a human with a CLI and a browser on the
same machine as the gateway. It's incompatible with what this codebase is
actually building: **Aeroform** (`flutter_aeroform`) auto-provisions a
fresh VPS and stands up the whole PocketCoder docker-compose stack with no
SSH step at all, and the only client is the phone that triggered the
provisioning. There is no human ever sitting at a terminal on the
gateway's machine to complete a loopback OAuth dance.

**A second, independent blocker, not about the callback at all:** CE
mode's OAuth flow is built for remote MCP servers that support Dynamic
Client Registration (RFC 7591) — it calls `EnsureDCRClient`
(`cmd/docker-mcp/oauth/auth.go`) and the gateway registers *its own*
OAuth client with the provider on first use, discovered via RFC 9728/8414.
A pre-registered, centrally-held `client_id` (the shape this spec needs,
see below) has no role in that path — the gateway would just register a
new client of its own, bypassing ours entirely. **This design therefore
does not use `mcp-gateway`'s OAuth subsystem at all.** It targets MCP
servers that run locally in the gateway's catalog and accept a plain
bearer/PAT-style secret (e.g. `github-mcp-server` reads
`GITHUB_PERSONAL_ACCESS_TOKEN`) — the same `mcp.env` secret-delivery path
already used for every non-OAuth server. OAuth only happens to get that
token *value*; from the gateway's point of view it's still just a secret.
Remote MCP servers that require the gateway's own DCR-based OAuth are out
of scope (see Out of scope).

## Ownership model this design depends on

Each docker-compose deployment belongs to exactly one user — it's their
VPS, their PocketBase, their gateway, provisioned by Aeroform and never
touched by us directly. The **only** infrastructure the PocketCoder team
operates centrally is the Cloudflare Workers (`workers/push-relay`,
`workers/image-relay`, and this spec's new one) — everything else is
per-user, self-hosted, and outside our reach.

That has a direct consequence for OAuth: end users never see a GitHub
developer-settings page in a zero-touch provisioning flow, so **we** have
to be the ones who register the GitHub OAuth App, once, centrally — not
each self-hoster. `mcp-gateway`'s own CE mode already establishes exactly
this shape as prior art: its default DCR redirect URI is the fixed,
Docker-owned `https://mcp.docker.com/oauth/callback`
(`pkg/oauth/manager.go`'s `DefaultRedirectURI`), with per-machine routing
carried in the `state` parameter as `mcp-gateway:{port}:{baseState}` — one
central HTTPS broker serving every CE installation, self-hosted machines
included. This spec's Worker plays the identical role for us: one fixed
HTTPS endpoint, centrally registered, serving every Aeroform-provisioned
deployment.

One consequence of GitHub specifically (verified against their [PKCE
changelog](https://github.blog/changelog/2025-07-14-pkce-support-for-oauth-and-github-app-authentication/)):
even with PKCE, GitHub still requires `client_secret` at the token-exchange
step — it doesn't distinguish public from confidential clients the way
Okta/Entra ID do. So that secret can never live in the mobile app or in
any individual user's self-hosted gateway config. It can only live in the
Worker, as a `wrangler secret put` value, exactly like `push-relay` already
holds `PN_RELAY_SECRET`/`REVENUECAT_SECRET_KEY`/etc.

## Precedent this design follows directly

`flutter_aeroform` already does this exact pattern for Linode
(`lib/infrastructure/auth/linode_oauth_service.dart`,
`lib/infrastructure/cloud_provider/linode_api_client.dart`):

- Builds an authorize URL with a PKCE `code_verifier`/`code_challenge` and
  `redirect_uri: 'pocketcoder://oauth-callback'`.
- Calls `FlutterWebAuth2.authenticate(url: ..., callbackUrlScheme: 'pocketcoder')`.
- The `pocketcoder://` scheme is already registered natively
  (`client/apps/pocketcoder/android/.../AndroidManifest.xml`'s
  `android:scheme="pocketcoder"` intent filter, and the iOS
  `CFBundleURLTypes` entry) — nothing new needed there.

Linode's OAuth accepts the custom scheme as the registered redirect_uri
directly and doesn't require a `client_secret` for the exchange (a true
public/PKCE client), so `LinodeOAuthService` does the whole flow, including
token exchange, client-side with no relay.

**Deliberate choice: every provider goes through the Worker's HTTPS
callback uniformly, even ones (like Linode) that would accept a direct
`pocketcoder://` redirect.** We do not branch per-provider on redirect-URI
capability. One callback shape, one code path, one place secrets live —
adding a provider is a config entry in the Worker, not a new flow. GitHub
forces this shape (mandatory `client_secret`, no documented custom-scheme
support); applying it everywhere, rather than special-casing providers
that don't strictly need it, is what keeps this generic.

## Alternative considered and rejected: docker-agent's elicitation mode

`docker/docker-agent` (Apache-2.0, a separate Docker project) solves this
same problem differently in its `serve api` mode: with
`--mcp-oauth-redirect-uri` set, it emits an MCP elicitation
(`pkg/tools/mcp/oauth.go`: `docker-agent/type: "oauth_flow"`,
`docker-agent/authorize_url`, `docker-agent/state` in the elicitation
`Meta`) instead of a local callback server, and the client replies to a
`POST /api/mcp-oauth/callback` (`pkg/tools/mcp/pending_oauth.go`) with
`{code, state}`. That's a real, working mechanism — but adopting it means
running `docker-agent` instead of `docker mcp gateway`, or forking Go
internals to backport it. Rejected: this spec's Worker-broker shape gets
the same zero-touch result without touching either upstream project's
code, at the cost of one more network hop (app → Worker → provider →
Worker → app) instead of routing through the gateway's own session.

## Architecture

```
1. User taps "Connect GitHub" in PocketCoder
      │
      ▼
2. App builds the authorize URL (our shared client_id, PKCE
   code_challenge, redirect_uri = the Worker's fixed callback URL) and
   calls FlutterWebAuth2.authenticate(url: ..., callbackUrlScheme:
   "pocketcoder") — same call shape as LinodeOAuthService.authenticate()
      │
      ▼
3. GitHub redirects to:
   GET https://oauth-relay.<workers-domain>/callback?code=...&state=...
      │
      ▼
4. Worker (new, sibling to push-relay/image-relay):
   - exchanges code → {access_token, refresh_token} with GitHub, using its
     own held client_id + client_secret (Worker secret, never shipped to
     any client or any user's VPS)
   - writes the token to a short-lived KV entry (60s TTL) keyed by a fresh
     one-time exchange_code, NOT into the redirect URL (tokens must not
     ride in a URL that lands in browser/webview history)
   - 302s to:
     pocketcoder://oauth-callback?exchange_code=...&state=...
      │
      ▼
5. flutter_web_auth_2 catches the custom-scheme redirect (same mechanism
   already proven for Linode), returns the callback URL to the awaiting
   Dart Future
      │
      ▼
6. App POSTs {exchange_code, code_verifier} to the Worker's /claim route.
   The Worker verifies S256(code_verifier) == the code_challenge recorded
   at authorize time, and only then releases the token from KV and
   deletes the entry. This is what actually makes PKCE do its job here —
   without this step the verifier the app generated in step 2 is never
   checked by anything, and a token sitting in a 302 URL is interceptable
   by anything that can read redirect history on the device
      │
      ▼
7. App calls a new endpoint on the USER'S OWN PocketBase (authenticated,
   mirroring RegisterMcpApi in server/pocketbase/internal/api/mcp.go) to
   hand the token to that user's own gateway, writing it as a plain
   secret into mcp.env for the target server's PAT-style env var (NOT
   into mcp-gateway's own OAuth credential-helper store — see Component 3)
```

Note what's *not* in this flow: no fork of `docker/mcp-gateway`'s Go
internals, no dependency on its OAuth subsystem (which, per the DCR issue
above, wouldn't even accept our pre-registered client), no MCP
elicitation, no gateway↔PocketBase↔Worker round-trip mid-tool-call. The
entire OAuth dance happens between the app and the Worker; the gateway
ends up with a token in `mcp.env`, the exact shape it already expects for
any other MCP server credential.

## Components

### Component 1 — new Worker: `workers/oauth-relay`

Mirrors `workers/push-relay`'s shape (single `fetch` handler,
`wrangler.toml` + `wrangler secret put` for credentials), plus one KV
namespace for the short-lived exchange-code → token mapping (60s TTL,
deleted on claim):

- Config: one record per provider, `{authorize_url, token_url, client_id,
  client_secret, scopes}` — GitHub today, but nothing provider-specific
  in the handler logic itself. Client secrets stored as Worker secrets.
- `GET /callback?code&state` — exchanges `code` for a token via the
  provider's token endpoint, using the *same* `redirect_uri` value (this
  Worker's own URL) at both the authorize and exchange steps, per RFC
  6749 §4.1.3. Stores the token in KV under a fresh random
  `exchange_code`, 302s to
  `pocketcoder://oauth-callback?exchange_code=...&state=...` on success;
  on failure, redirects to an error variant of the same scheme
  (`pocketcoder://oauth-callback?error=...`) rather than a bare error page
  the user can't navigate away from on a phone browser tab.
- `POST /claim {exchange_code, code_verifier}` — looks up the KV entry,
  verifies `base64url(sha256(code_verifier)) == code_challenge` recorded
  at authorize time, returns the token and deletes the KV entry. Reject
  (404/400) on missing/expired/already-claimed entries or a verifier
  mismatch — this check is PKCE's entire purpose in this flow and must
  fail closed.
- **Plan must resolve:** does the authorize step (building the URL with
  `code_challenge`) happen purely client-side, or does the app first hit
  a `POST /start` on the Worker so it can record `code_challenge` against
  a `state` before redirecting? The `/claim` verification above requires
  the Worker to know the `code_challenge` it should check against —
  confirm whether that's carried through `state` (opaque to the Worker
  until claim time, decoded then) or persisted at a `/start` call.

### Component 2 — PocketCoder Flutter: `McpOAuthService`

New class in `pocketcoder_flutter`, structured like `flutter_aeroform`'s
`LinodeOAuthService` (same package family, same org, same pattern), but
parameterized by provider from the start — `McpOAuthService(provider:
'github')`, not a GitHub-specific class, since Component 1's Worker is
already provider-generic and the client side should match:

- `authenticate()`: build the authorize URL (`client_id` = our shared
  provider App's id — not secret, safe to embed/config the same way
  `linodeClientId` is injected via `@Named('linodeClientId')`), PKCE
  challenge, `redirect_uri` = the Worker's fixed callback URL, then
  `FlutterWebAuth2.authenticate(...)`.
- On the returned callback URL: `POST /claim` to the Worker with the
  `exchange_code` and the `code_verifier` generated in the first step,
  get back the real token.
- Handle failure modes explicitly, not just the happy path:
  - User cancels the browser sheet — `FlutterWebAuth2` throws
    `PlatformException(code: 'CANCELED', ...)` (same as
    `LinodeOAuthService` already catches) — surface as a dismissable, not
    an error state.
  - Worker redirects the `error=` variant — surface the provider's error.
  - `/claim` succeeds but the subsequent PocketBase delivery (Component
    3) fails — the user now has a live OAuth grant with nowhere to land.
    Retry the PocketBase call with backoff before giving up, and on
    final failure keep the token in memory long enough to offer a
    one-tap retry without re-running the whole browser flow.
- Hand the token to the new PocketBase endpoint (Component 3) rather than
  storing it locally via `flutter_secure_storage` the way Linode's
  provisioning token is stored — this token belongs to *this user's
  gateway*, not to the app's own session, so the app is a courier here,
  not the long-term holder.

**Plan must resolve:** where in the UI this gets triggered from — likely
the existing MCP server approval/governance screens
(`McpManagementScreen`), as a "Connect" action shown for servers whose
catalog entry is marked as OAuth-requiring rather than secret-requiring.
That distinction doesn't exist yet in `mcp_servers`'/the catalog schema —
confirm what marks a server as OAuth vs. plain-secret before wiring the UI.

### Component 3 — PocketBase: token intake endpoint

New route, `server/pocketbase/internal/api/mcp.go`-style (or a sibling
file), `POST /api/pocketcoder/mcp_oauth/store`, authenticated
(`apis.RequireAuth()`), body `{server_name, access_token, refresh_token}`:
writes the token as a **plain secret** into the same render pipeline that
already produces `mcp.env` from `mcp_servers` rows (the mechanism
`hooks/mcp.go` already drives for approved servers, per the
mcp-governance-ui spec) — i.e. it lands in `mcp.env` as whatever env var
the target server's catalog entry declares (`GITHUB_PERSONAL_ACCESS_TOKEN`
for `github-mcp-server`, etc.), exactly like a manually-entered API key
would. This is **not** written into `mcp-gateway`'s own OAuth
credential-helper store (`pkg/oauth/token_store.go`'s
`{authorizationEndpoint}/{providerName}` key format) — that store belongs
to the gateway's own DCR-based OAuth subsystem, which (per Problem, above)
isn't in this design's path at all. Confirmed by reading the source, not
assumed.

## Attribution & licensing

No third-party code is copied into this design. `docker/mcp-gateway`,
`docker/docker-agent`, and `docker/mcp-gateway-oauth-helpers` were cloned
locally and read directly to verify behavior before this spec made any
claims about them, rather than relying on paraphrased summaries.

**Patterns directly followed — credit in source headers when the
corresponding code is written:**

- **`docker/mcp-gateway`** — MIT, Copyright (c) 2025 Docker, Inc.
  `workers/oauth-relay` follows the *shape* of its CE-mode OAuth flow:
  a single fixed HTTPS callback acting as a central broker for many
  machines (`DefaultRedirectURI = "https://mcp.docker.com/oauth/callback"`
  in `pkg/oauth/manager.go`), with routing information carried in the
  OAuth `state` parameter (`cmd/docker-mcp/oauth/auth.go`). No code is
  copied; add to `workers/oauth-relay/src/index.ts`:
  `// Central-broker-with-HTTPS-callback shape informed by reading`
  `// docker/mcp-gateway (MIT, Copyright (c) 2025 Docker, Inc.)`

- **`docker/docker-agent`** — Apache-2.0, Copyright Docker, Inc. Its
  remote-OAuth mode (`pkg/tools/mcp/oauth.go`,
  `--mcp-oauth-redirect-uri`) is the direct precedent for "a public HTTPS
  bouncer that hands a finished credential back to a client via a
  deeplink" — see Alternative considered and rejected, above. We use none
  of its code and do not run docker-agent, so Apache-2.0 §4(d)'s
  attribution-notice obligation does not attach (nothing Apache-licensed
  is distributed), but the concept credit is recorded here.

**Read for understanding only — no attribution obligation, nothing used:**

- **`docker/mcp-gateway-oauth-helpers`** — MIT, Copyright (c) 2025 Docker.
  DCR (RFC 7591), OAuth discovery (RFC 9728/8414), `WWW-Authenticate`
  parsing. Read specifically to confirm the DCR path does **not** apply
  here (Problem, above) — our design uses a pre-registered OAuth App, not
  dynamic client registration, and none of this library's logic is used,
  adapted, or reimplemented.

If any of the above code is ever actually vendored (not just referenced
for pattern/behavior), add a top-level `NOTICE` file carrying the MIT
license texts verbatim. As of this design, none is vendored.

## Out of scope

- Multiple PocketCoder users on the *same* deployment each connecting
  their own GitHub account. Each docker-compose instance is one user's
  instance; this spec is single-tenant per deployment, matching the rest
  of the MCP governance model (`mcp_servers` approval is global within a
  deployment, not per-user).
- Remote MCP servers that require `mcp-gateway`'s own DCR-based OAuth
  subsystem (see Problem). Those servers register their own client with
  the provider at connect time; a centrally pre-registered `client_id`
  has no role there, and this design doesn't attempt to reconcile the two
  paths. In scope only: locally-run catalog servers that accept a plain
  bearer/PAT secret.
- Token refresh. `access_token`/`refresh_token` land in `mcp.env` as a
  pair; refreshing an expired token is a separate, smaller follow-up
  (either re-running Component 2, or a small scheduled job — not
  designed here).
- Providers other than GitHub. Components 1 and 2 are already
  provider-generic by construction (a config record in the Worker, a
  `provider` parameter in the Flutter service), but each new provider's
  authorize/token endpoint quirks (scopes, whether a `client_secret` is
  even required) need their own quick verification pass before adding
  them — don't assume GitHub's constraints apply uniformly.
