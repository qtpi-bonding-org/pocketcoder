# Worker Security Hardening — Design

## Problem

A security audit of the three central Cloudflare Workers (`WORKER_AUDIT.md`,
committed at the repo root) found real issues, most concentrated in
`push-relay`:

- **`push-relay` has no tenant isolation.** `PN_RELAY_SECRET` is a single
  value copy-pasted into every self-hosted deployment's `.env` at
  provisioning time (`elestio.yml`, `tooling/scripts/elestio/postInstall.sh`,
  `docker-compose.yml`). The Worker's only check is
  `secret !== env.PN_RELAY_SECRET` — there is no per-deployment identity, and
  the request body's `user_id` is trusted as-is. Any deployment can therefore
  act as any other user: spam another user's device, use
  `checkSubscription` as a premium-status oracle for an arbitrary `user_id`,
  or exhaust another user's `DAILY_PUSH_LIMIT`.
- **`push-relay`'s `unifiedpush` path is an open SSRF primitive.** It takes
  `token` straight from the caller's JSON body and does
  `fetch(token, ...)` server-side with no allowlist — usable by anyone
  holding the (already-shared) secret to make the Worker request arbitrary
  URLs.
- **`image-relay` has two credential-handling routes
  (`/upload-image`, `/image-status`) that are dead code.** They're only
  called by `flutter_aeroform`'s `CustomImageProvisioningStrategy`, which is
  registered in DI under `@Named('customImage')` and never looked up by that
  name anywhere — `BootTimePullProvisioningStrategy` (unnamed, the actual
  binding `DeploymentService` receives) is what's live, and it only calls
  `/image-manifest`.

Separately, product requirements that motivate part of this design: a
free trial period for centrally-relayed FCM push (so a self-hosted user
gets working push notifications without paying immediately), and self-hosted
users must be able to pay later for FCM instead of self-hosting
UnifiedPush/ntfy, with the subscription surviving a full VPS redeploy.

## Global Constraints

- No production users exist yet — no migration/grandfathering path is
  needed for the existing shared `PN_RELAY_SECRET`.
- Each deployment belongs to exactly one user, provisioned by Aeroform with
  no SSH step (`CLAUDE.md`, "Deployment Model"). The only infrastructure we
  operate centrally is `workers/`.
- The PocketBase user id is already the identity RevenueCat and push-relay
  both key on: `RevenueCatBillingService.identify(userId)`
  (`client/packages/pocketcoder_pro/lib/app.dart`) calls
  `Purchases.logIn(pocketbaseUserId)` once a PocketBase account exists, and
  push-relay's payload already carries `user_id` as that same id. This
  design does not invent a new identity system — it makes the existing
  `user_id` provable instead of self-declared.
- **RevenueCat's own trial-eligibility enforcement is authoritative and
  sufficient.** Both Apple (`checkTrialOrIntroductoryPriceEligibility`,
  enforced per Apple ID per subscription group at the App Store server) and
  Google (per-Google-account "new customer acquisition" eligibility on an
  offer) track free-trial usage at the *account* level, not the app-install
  level — reinstalling the app or getting a new `app_user_id` does not grant
  a second trial. A trial period shows up in RevenueCat as just another
  active entitlement (`period_type: trial`). This means **no custom
  trial-tracking table or clock is needed** — configuring a real
  introductory-offer/free-trial phase on the subscription product in App
  Store Connect / Play Console is a dashboard change, not a code change, and
  `checkSubscription`'s existing `active_entitlements` check already handles
  it correctly. See Sources at the end of this document.
- **Redeploy must preserve an existing paid subscription.** RevenueCat's
  default "Transfer to new App User ID" restore-behavior setting means
  `Purchases.logIn(newUserId)` on the same physical device/store account
  automatically moves an active entitlement from the old (pre-redeploy)
  `user_id` to the new one — no explicit `restorePurchases()` needed. This
  is a **per-RevenueCat-project dashboard setting**, not fixed SDK behavior;
  it must stay set to "Transfer to new App User ID" (the default) for this
  design to hold. Flagged here so nobody changes it without realizing the
  consequence.
- Free-trial abuse via "redeploy to reset the clock" is explicitly **not**
  addressed by this design, because it no longer applies: since the trial
  clock lives entirely in RevenueCat (keyed on the Apple ID / Google
  account), redeploying and getting a new PocketBase `user_id` does not
  reset it — RevenueCat's account-level enforcement covers this for free.
- OAuth-gating the MCP OAuth broker (`oauth-relay`) behind Pro/trial status
  was raised and deliberately deferred to a future design — not addressed
  here.

## Components

### 1. Per-deployment secret generation (`flutter_aeroform`)

Aeroform generates a random, high-entropy secret locally at provisioning
time — same pattern already used for SSH keys (`ISshKeyGenerator`) — instead
of `PN_RELAY_SECRET` being a fixed value supplied externally. This secret is
written into the deployment's own `.env` / `docker-compose` environment,
exactly where `PN_RELAY_SECRET` already lives today; only its origin
changes (locally generated per box, not a shared literal).

*(Existing deployments via `elestio.yml`/`postInstall.sh`'s externally-supplied
`PN_RELAY_SECRET` are out of scope — no production users exist yet, and
Elestio is a separate deployment path from Aeroform; if it needs the same
per-deployment generation, that's a follow-up, not blocking this design.)*

### 2. Trust-on-first-use binding + Supabase table (`workers/push-relay`)

New Supabase table, e.g.:

```sql
create table relay_bindings (
  secret_hash text primary key,
  user_id text not null,
  bound_at timestamptz not null default now()
);
```

On every incoming request, `push-relay`:

1. Computes `secret_hash = SHA-256(X-Relay-Secret header)`.
2. Looks up `relay_bindings` by `secret_hash`.
3. **No row exists** → this is the first time this secret has ever been
   seen. Atomically insert `{secret_hash, user_id: <this request's
   user_id>}` via `INSERT ... ON CONFLICT (secret_hash) DO NOTHING`,
   immediately followed by a `SELECT` of whatever row now exists for that
   `secret_hash` (handles the race where two concurrent first-use requests
   arrive together — exactly one insert wins, both requests then read the
   same winning row). Proceed using the row's `user_id`.
4. **Row exists** → if the request's `user_id` doesn't match the bound
   `user_id`, reject with `403` (`{"error": "user_id_mismatch"}`). Otherwise
   proceed as today.

This closes the tenant-isolation gap: a deployment's secret is permanently
tied to the first `user_id` it was ever used with, so it can never be used
to act on behalf of a different user. It requires no new endpoint and no
coordination between Aeroform and the Worker at provisioning time — the
binding happens lazily, on first real push.

Only the FCM path needs this (see Component 3 for why UnifiedPush is
removed entirely) — the binding check happens once, up top, before the
existing subscription/quota logic in `fetch()`, ahead of the `service ===
'fcm'` branch.

### 3. Remove the `unifiedpush` passthrough (`workers/push-relay`)

Delete the `service === 'unifiedpush'` branch and `sendUnifiedPush()`
entirely. Self-hosted UnifiedPush/ntfy delivery does not need any secret we
hold centrally — the user's own PocketBase already knows their ntfy
endpoint URL and should `POST` to it directly, without routing through
`push-relay` at all. This removes the SSRF primitive by removing the code
path, not by adding a URL allowlist to it.

`push-relay`'s scope narrows to exactly what it exists for: the FCM path,
which is the one thing that genuinely requires a centrally-held secret
(the Firebase service-account key).

### 4. No new trial-tracking code

`checkSubscription()` (`workers/push-relay/src/index.js`) is unchanged.
Once a real trial phase is configured on the RevenueCat product (dashboard
change, not covered by this spec), a trialing user's `active_entitlements`
call already returns the entitlement, and the existing code path treats
that identically to a paid subscription. No Supabase trial-clock table, no
Worker-side date math.

### 5. Remove dead credential-handling routes (`workers/image-relay`)

Delete:

- `POST /upload-image`, `POST /image-status`, `streamImageToLinode()`
- The `queue()` handler and `UPLOAD_QUEUE` binding in `wrangler.toml` (its
  consumer is already commented out there, for the same reason)
- `CustomImageProvisioningStrategy` and its `@Named('customImage')`
  registration in `flutter_aeroform` (confirmed unreachable — nothing looks
  it up by that name; `IInstanceProvisioningStrategy` resolves to the
  unnamed `BootTimePullProvisioningStrategy` binding)

`image-relay` keeps only `GET /image-manifest` and `GET /health` — both
unauthenticated by design (the manifest is public, read-only, CI-published
data; see the existing comment on `handleImageManifest` about why a write
route would be remote code execution on every future deployment). After
this change, `image-relay` never touches a user credential of any kind.

## Error Handling

- `push-relay`: a `user_id` mismatch on a bound secret returns `403
  {"error": "user_id_mismatch"}` — deliberately generic, no detail about
  what the bound `user_id` actually is (that would itself be an oracle).
- `push-relay`: if the Supabase binding lookup/insert fails (network error,
  Supabase outage), fail **closed** for this check specifically — reject
  the push with `502`, do not fall through to sending it unbound. This is
  a deliberate asymmetry from the existing quota/subscription checks
  (which fail open, by product choice, to prioritize delivery over billing
  enforcement) — a binding-check failure is an identity question, not a
  billing question, and identity must not fail open.
- `image-relay`: removed routes simply cease to exist (`404` via the
  existing catch-all), same as any other unmatched path today.

## Testing

- `push-relay`: first-use binding creates a row and accepts the request;
  second request with the same secret and same `user_id` succeeds; second
  request with the same secret and a *different* `user_id` gets `403`.
- `push-relay`: two concurrent first-use requests with different `user_id`s
  on the same never-seen secret — exactly one `user_id` wins the binding,
  both requests complete without erroring, and a subsequent request with
  the losing `user_id` is rejected.
- `push-relay`: `unifiedpush` requests are no longer accepted (`400`
  "Unknown service").
- `push-relay`: Supabase binding-lookup failure returns `502`, not a
  silently-unbound send.
- `image-relay`: `/upload-image`, `/image-status` return `404`.
  `/image-manifest` and `/health` behavior unchanged.
- `flutter_aeroform`: `CustomImageProvisioningStrategy` and its test file
  removed; `DeploymentService` continues to resolve
  `BootTimePullProvisioningStrategy` via DI with no `@Named` lookup
  anywhere in the codebase (grep check, not just unit tests).

## Out of Scope

- OAuth-gating `oauth-relay`'s GitHub (or future MCP-provider) broker
  behind Pro/trial status — deferred to a separate design. Notably, this
  *cannot* reuse the per-deployment secret from Component 1 directly: that
  secret must stay server-side (PocketBase only), while `oauth-relay`'s
  `/authorize` is opened directly by the phone via `FlutterWebAuth2`, not
  brokered through PocketBase. A future design in this space should have
  PocketBase mint a short-lived, single-purpose signed ticket for the app
  to present, rather than exposing the raw deployment secret to a
  less-trusted device.
- Gating Linode's own OAuth (used for provisioning itself, before any
  PocketBase user id or RevenueCat identity exists) — must remain ungated
  regardless of what happens with GitHub/MCP-provider gating, since gating
  it would block new users from ever deploying.
- Migrating already-deployed boxes off the old shared `PN_RELAY_SECRET` —
  moot, no production deployments exist yet.
- A rebind/rotation path for a deployment's secret (e.g. after a leak, or a
  deliberate "start over" without a full redeploy) — TOFU has no built-in
  mechanism for this. Not needed for v1; a natural place to add it later
  would be alongside the ticket-minting endpoint from the deferred
  OAuth-gating design, since both need PocketBase to authenticate a
  privileged action to a central Worker.
- RevenueCat Web Billing (currently a no-op skip on web in
  `RevenueCatBillingService.initialize()`) — Apple/Google's account-level
  trial enforcement does not extend to a Stripe-based web purchase path;
  if that's ever activated, it needs its own trial-abuse consideration.
- Elestio's separately-supplied `PN_RELAY_SECRET`
  (`elestio.yml`/`postInstall.sh`) generating its own per-deployment secret
  rather than an externally-supplied one — follow-up if that deployment
  path is still in active use.

## Sources

- [Restore Behavior — RevenueCat](https://www.revenuecat.com/docs/projects/restore-behavior) —
  default "Transfer to new App User ID" behavior on `logIn()`.
- [Implementing introductory offers — Apple Developer](https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app) —
  per-Apple-ID, per-subscription-group trial eligibility enforced at the
  App Store server.
- [About subscriptions — Play Billing, Android Developers](https://developer.android.com/google/play/billing/subscriptions) —
  per-Google-account "new customer acquisition" offer eligibility.
