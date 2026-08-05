# MCP OAuth Provider Discovery — Design (addendum to mcp-oauth-flow)

> Builds directly on `docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md`
> (the base MCP OAuth Flow design, already implemented on
> `goose-agui-refactor-plan`). Read that spec first — this document only
> covers the delta: removing per-provider hardcoding from the Flutter
> client by moving provider knowledge entirely into the Worker.

## Problem

The base design shipped `McpOAuthService` (Flutter) with **per-provider
knowledge baked into the client**:

```dart
static const _authorizeUrls = {'github': 'https://github.com/login/oauth/authorize'};
static const _scopes = {'github': 'repo read:user'};
McpOAuthService(this._httpClient, this._relayBaseUrl,
    @Named('githubOAuthClientId') String githubClientId)
  : _clientIds = {'github': githubClientId};
```

This was flagged (correctly) as an architectural smell during review: every
new OAuth-requiring MCP server provider (Linear, Notion, ...) currently
requires a **Flutter code change and app release** — a new `_authorizeUrls`
entry, a new `_scopes` entry, a new `@Named('<provider>OAuthClientId')` DI
provider wired through `external_module.dart` — even though `client_id`
itself is not secret and the Worker (`workers/oauth-relay`) already
holds the authoritative, secret-adjacent configuration for every provider
(`PROVIDERS` map: `tokenUrl` today). The Worker is already the single place
a human registers a new OAuth App; the Flutter client duplicating a subset
of that same config is pure redundancy with an app-release cost attached.

Compare to `docker/mcp-gateway`'s own approach (read directly, not copied —
see the base spec's Attribution section): its gateway process is the piece
that knows a remote MCP server's OAuth metadata, discovered per-server via
RFC 9728/8414 (`WWW-Authenticate` header, protected-resource metadata) —
the client (`docker mcp oauth authorize`) never hardcodes a provider's
authorize/token endpoints or scopes. We deliberately don't adopt full
Dynamic Client Registration (per the base spec's Problem section — a
centrally pre-registered `client_id` has no role in DCR), but the *shape*
of "the piece holding the secrets also holds the routing metadata, the
client just says which provider" is worth taking without DCR itself.

## Solution

**Move all per-provider metadata into the Worker's `PROVIDERS` map, and
add two new Worker routes so Flutter never needs to know a provider's
authorize URL, token URL, scope, or `client_id`.** The client only ever
needs a provider's opaque string key (already present as
`McpServer.oauthProvider`, sourced from the `mcp_servers` schema field a
human set when registering that catalog entry — see the base spec's
Component 3) plus a locally-generated PKCE `code_verifier`/`code_challenge`
pair, which must stay client-side regardless (only the client may know the
verifier before `/claim` time).

### Worker: expanded `PROVIDERS` map (Component 1 addendum)

```js
const PROVIDERS = {
  github: {
    displayName: 'GitHub',
    authorizeUrl: 'https://github.com/login/oauth/authorize',
    tokenUrl: 'https://github.com/login/oauth/access_token',
    scope: 'repo read:user',
  },
  // linear: { displayName: 'Linear', authorizeUrl: '...', tokenUrl: '...', scope: '...' },
  // notion: { displayName: 'Notion', authorizeUrl: '...', tokenUrl: '...', scope: '...' },
};
```

`client_id`/`client_secret` remain Worker *secrets* (`wrangler secret put
<PROVIDER>_OAUTH_CLIENT_ID` / `_CLIENT_SECRET`), not part of this
in-source map — same split as today. A provider only shows up as
"supported" (see `/providers` below) once both secrets are actually set,
which doubles as a live-configuration check, not just a code-presence
check.

### New Worker route: `GET /providers`

Returns the list of providers that have **both** a `PROVIDERS` entry
**and** their secrets configured (env var lookup, same pattern
`handleCallback` already uses to fail closed on missing secrets):

```json
{"providers": [{"id": "github", "displayName": "GitHub"}]}
```

Consumed by `McpOAuthService.supportedProviders()` (Flutter), cached
in-memory for the app session (not persisted — this is non-secret,
cheap-to-refetch, low-cardinality data, so there's no correctness reason to
survive an app restart). The cubit/UI layer uses this to gate the
CONNECT button: a server whose `oauth_provider` isn't in this list shows a
"not yet configured" state instead of launching a browser sheet that
would fail after the fact with `unknownProvider`.

### New Worker route: `GET /authorize`

```
GET /authorize?provider=github&code_challenge=<..>&code_challenge_method=S256
```

Looks up `provider` in `PROVIDERS` (400 `unknown_provider` if absent, same
fail-closed posture as `/callback`'s existing provider check), builds
`state = base64url(JSON.stringify({p: provider, cc: code_challenge}))`
**server-side now** (previously built client-side by
`McpOAuthService.encodeState` — that method and its client-side duplication
of the state-encoding scheme go away entirely), and **302s straight to the
provider's real authorize URL** with `client_id`/`scope`/`redirect_uri`
filled in from the Worker's own held config:

```
302 https://github.com/login/oauth/authorize?client_id=...&response_type=code
    &redirect_uri=https://.../callback&scope=repo+read:user
    &state=<base64url>&code_challenge=<..>&code_challenge_method=S256
```

Flutter's `FlutterWebAuth2.authenticate(url: '$relayBaseUrl/authorize?...',
callbackUrlScheme: 'pocketcoder')` call is unchanged in *shape* — it's
still exactly one `authenticate()` call opening exactly one browser sheet.
The 302 happens **inside** that browser sheet, transparently, before the
user sees anything — this is not a second round trip the app has to wait
on or orchestrate; it's the same class of redirect `/callback` already
does today, just one hop earlier in the chain. This preserves the base
spec's Decision 1 rationale (no separate pre-redirect network call the app
has to make and await) while moving the URL-building logic itself
server-side.

### Flutter (`McpOAuthService`) after this change

Everything that was static per-provider config is deleted:
`_authorizeUrls`, `_scopes`, `_clientIds`, the constructor's
`@Named('githubOAuthClientId')` parameter, and
`external_module.dart`'s `githubOAuthClientId` DI provider. `encodeState`
is deleted (state-building moves server-side). What remains client-side,
unchanged: PKCE `generateCodeVerifier`/`generateCodeChallenge` (must stay
client-only — the Worker never sees `code_verifier` until `/claim`), the
`/claim` POST, and all existing failure-mode handling (cancel, provider
error, claim failure, retry-with-backoff in `McpCubit`).

New method:
```dart
Future<List<McpOAuthProvider>> supportedProviders(); // GET /providers, cached in-memory
```//
where `McpOAuthProvider = ({String id, String displayName})`, mirroring
the existing `McpOAuthTokenPair` typedef-record style already used in
`i_mcp_oauth_service.dart`.

## Adding a new provider, after this change

100% Worker-side, zero Flutter changes, zero app release:
1. One `PROVIDERS` entry (`authorizeUrl`, `tokenUrl`, `scope`,
   `displayName`).
2. `wrangler secret put <PROVIDER>_OAUTH_CLIENT_ID` /
   `_CLIENT_SECRET`.
3. `wrangler deploy` (or `tooling/scripts/deploy-workers.sh`).

The next time any app fetches `/providers`, the new one appears and its
CONNECT button lights up — no client update in the loop at all.

## Security considerations (for review)

- **`/authorize` is a fixed-destination redirector, not an open
  redirect.** The only user-influenced inputs are `provider` (looked up
  against a closed, server-defined `PROVIDERS` map — unknown values 400,
  never redirect anywhere), and `code_challenge`/`state`, which are placed
  into the outgoing URL's query string via a proper URL-building API
  (`URL`/`URLSearchParams`, matching `handleCallback`'s existing pattern —
  never raw string concatenation), so neither can inject additional query
  parameters or redirect the browser to a non-provider domain.
- **`code_verifier` never appears in any URL, on either the `/authorize`
  or `/callback` leg** — only `code_challenge` (not secret per RFC 7636
  §4.2) does. This is unchanged from the base design.
- **`/providers` and `/authorize` are both unauthenticated**, same as the
  base design's `/callback`/`/claim` — appropriate because: (a) they're
  hit by a browser/webview redirect chain and a native app's HTTP client
  respectively, neither of which can attach this user's PocketBase auth
  token to a request to a *different* origin (the Worker); (b) nothing
  they return is secret — `/providers` discloses only which OAuth
  integrations are live (equivalent to what's visible by inspecting the
  app's own catalog UI), and `/authorize` discloses nothing at all (it's a
  redirect, not a data response).
- **No new secret-handling surface.** `client_id`/`client_secret` remain
  exactly where they were in the base design (Worker secrets, read at
  `/authorize` and `/callback` time respectively) — this change only
  relocates *which endpoint* reads `client_id`/`scope`/`authorizeUrl` (from
  `/callback`-adjacent code to `/authorize`), not who holds them.
- **State-building moves server-side but keeps the same non-HMAC,
  plaintext-is-fine posture** the base spec's Decision 1 already
  justified (code_challenge isn't secret; nothing here needs to verify the
  Worker itself set `state`, since the only consumer of the eventual
  deep-link callback is the same device that initiated the flow). Moving
  the encode from client to server doesn't change that threat model — it's
  the same non-secret value, built in one more place instead of one fewer.
- **Question for review:** does exposing `GET /providers` unauthenticated
  create any enumeration/reconnaissance value for an attacker (e.g.
  learning which third-party integrations a specific
  Aeroform-provisioned fleet uses)? This endpoint is **global to the
  Worker**, not scoped to a single deployment/user — it lists which
  providers are configured centrally, identical for every PocketCoder
  install, not which providers *this* user's `mcp_servers` catalog
  actually uses. Our read: low value to an attacker (a de facto public
  fact, given the OAuth App names themselves would be discoverable via the
  Worker's own `/callback`'s registered redirect URI on each provider's
  side anyway) — but explicitly flagging for a second opinion since
  "unauthenticated enumeration endpoint" is a pattern worth double-checking
  even when each individual disclosure looks benign.

## Out of scope

- Full Dynamic Client Registration / RFC 9728/8414 discovery (see the base
  spec's Problem section for why — unchanged by this addendum).
- Persisting `supportedProviders()`'s result across app restarts — refetch
  is cheap and the data is small/non-secret.
- Any change to `/callback` or `/claim` — both are unmodified by this
  addendum.

## Security review (Opus, 2026-07-27) — required changes before implementation

Full review on file; verdict was **"safe to implement in shape, not exactly
as specced."** Four required changes, folded into the design above:

1. **Provider lookup must not walk the JS prototype chain.** Plain
   `PROVIDERS[provider]` lets `provider=constructor`/`toString`/`__proto__`
   pass a bare `if (!provider)` guard. Use `Object.hasOwn(PROVIDERS,
   provider)` (both in the new `/authorize` and, backported, in the
   existing `/callback`). Derive the secret env-var prefix from the
   *matched map key*, never the raw query param.
2. **Build the outgoing redirect URL from a fresh `URLSearchParams`,
   `.set()`-ing exactly the known keys** (`client_id`, `response_type`,
   `redirect_uri`, `scope`, `state`, `code_challenge`,
   `code_challenge_method`) — never forward the inbound query string
   wholesale. Prevents a duplicate/injected `redirect_uri` or `scope` param
   once a second provider is added.
3. **Hardcode `code_challenge_method=S256` server-side** (drop it as a
   client-supplied param — `/claim` only ever checks S256 anyway) and
   **validate `code_challenge` against `^[A-Za-z0-9_-]{43}$`** before it's
   embedded in the outgoing URL or written to KV.
4. **Keep a client-side `decodeState` + equality check.** The line "
   `encodeState` is deleted (state-building moves server-side)" is amended
   to: `encodeState` is deleted, but a `decodeState` is added — the client
   still asserts `decoded.cc == myCodeChallenge` (and `decoded.p ==
   provider`) before calling `/claim`. Free, and restores the
   state-echo-verification property `state` is normally supposed to
   provide (PKCE already fails closed without it, so this is
   defense-in-depth, not a blocking gap — but it's zero-cost to keep).

Also adopted as stated invariants: `Cache-Control: no-store` on
`/authorize`; `GET /providers` response shape is pinned to `{id,
displayName}` and nothing else, forever (no `authorizeUrl`/`tokenUrl`/
`scope`/`client_id`/secret-presence diagnostics); Flutter caches only
*successful* `/providers` responses (a transient fetch failure must not
poison the session with an empty list).

Explicitly confirmed **not** a blocker: unauthenticated `/providers` (the
disclosed set is global/identical across every deployment, and `/authorize`
is already an equivalent oracle that can't be removed either way); the
unsigned plaintext `state` (PKCE's `code_challenge`/`code_verifier` check
at `/claim` is the actual trust boundary, unchanged by this addendum); a
poisoned in-memory provider-list cache (UI-gating only — every
authoritative value is still resolved server-side at `/authorize` time, so
the worst case is a button that 400s, never a redirect to an attacker
endpoint).
