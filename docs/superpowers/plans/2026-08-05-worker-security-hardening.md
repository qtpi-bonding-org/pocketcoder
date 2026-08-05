# Worker Security Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close `push-relay`'s tenant-isolation gap and SSRF primitive, and delete `image-relay`'s dead credential-forwarding routes, per `docs/superpowers/specs/2026-08-05-worker-security-hardening-design.md`.

**Architecture:** Each deployment gets its own random `PN_RELAY_SECRET` (generated at first boot, `deploy/nixos/bootstrap.nix`) instead of one value shared by every deployment. `push-relay` binds a secret to whichever `user_id` it first sees for that secret (trust-on-first-use, backed by a new Supabase table + atomic RPC) and rejects any later request on that secret presenting a different `user_id`. The `unifiedpush` passthrough — an unauthenticated-destination SSRF primitive that real traffic never actually uses — is deleted outright; self-hosted UnifiedPush/ntfy delivery already goes directly from PocketBase to the user's own endpoint (`NtfyDirectProvider` in `server/pocketbase/internal/hooks/notifications.go`) and never touches this Worker. `image-relay`'s `/upload-image` and `/image-status` routes, and the `flutter_aeroform` strategy that's their only caller, are deleted as confirmed-unreachable dead code.

**Tech Stack:** Cloudflare Workers (plain JS/TS, no framework), Supabase (Postgres via PostgREST), Nix (`deploy/nixos/bootstrap.nix`, a first-boot cloud-init-style script), Dart/Flutter + `injectable`/`build_runner` (`flutter_aeroform`).

## Global Constraints

- No production deployments exist yet — no migration path for the old shared `PN_RELAY_SECRET` is needed.
- Follow existing conventions exactly: Supabase schema changes go in `workers/push-relay/scripts/supabase-schema.sql` (applied manually via the Supabase SQL editor or `psql`, no migration framework in this repo); Worker integration tests are hand-written `sh` scripts under `workers/*/scripts/` that hit a real deployed Worker plus real Supabase/RevenueCat (no `vitest`/`miniflare` in this repo — don't introduce one).
- `flutter_aeroform.module.dart` is generated (`// GENERATED CODE - DO NOT MODIFY BY HAND`) — never hand-edit it; delete the source file/annotation and regenerate via `build_runner`.
- A discovery made while planning this work, not in the original spec: `push-relay`'s FCM path only ran the RevenueCat/Supabase checks `if (user_id && ...)` — omitting `user_id` from the request entirely skipped both checks and went straight to a real FCM send. This is a more severe, always-available billing bypass than the documented fail-open behavior (which only triggers during a genuine dependency outage), and this plan closes it by making `user_id` mandatory on the FCM path (Task 3).

---

## File Structure

| File | Change |
|---|---|
| `deploy/nixos/bootstrap.nix` | Add `PN_RELAY_SECRET` to the existing per-box random-secret generation block |
| `workers/push-relay/scripts/supabase-schema.sql` | Add `relay_bindings` table + `bind_relay_secret` RPC |
| `workers/push-relay/src/index.js` | Require `user_id` on the FCM path; add tenant-binding check; delete `unifiedpush` passthrough |
| `workers/push-relay/wrangler.toml` | Drop `PN_RELAY_SECRET` from the secrets comment (no longer a Worker-side secret) |
| `workers/push-relay/scripts/set-secrets.sh` | Drop `PN_RELAY_SECRET` from the required-secrets loop |
| `workers/push-relay/scripts/test-paid-path.sh` | Derive a per-test-user secret so existing stages don't collide with the new binding gate |
| `workers/push-relay/scripts/test-tenant-binding.sh` | New — integration test for the binding gate |
| `workers/image-relay/src/index.ts` | Delete `/upload-image`, `/image-status`, the queue consumer, and their supporting code |
| `workers/image-relay/wrangler.toml` | Remove the queue producer binding and now-unused `NIXOS_IMAGE_KEY` var |
| `flutter_aeroform/lib/infrastructure/deployment/custom_image_provisioning_strategy.dart` | Delete (confirmed unreachable) |
| `flutter_aeroform/test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart` | Delete |
| `flutter_aeroform/lib/flutter_aeroform.module.dart` | Regenerated, not hand-edited |
| `WORKER_AUDIT.md` | Annotate resolved findings |

---

### Task 1: Generate a per-deployment `PN_RELAY_SECRET` at first boot

**Files:**
- Modify: `deploy/nixos/bootstrap.nix:121-129`

**Interfaces:**
- Produces: a `PN_RELAY_SECRET` line in the deployed box's `.env`, in the exact same shape `docker-compose.yml:34`'s `PN_RELAY_SECRET=${PN_RELAY_SECRET}` already expects, and that `server/pocketbase/internal/hooks/notifications.go:116` already reads via `os.Getenv("PN_RELAY_SECRET")`. Nothing downstream needs to change to consume it — this task only changes *how* the value gets into `.env`.

- [ ] **Step 1: Add the secret generation line**

This file already generates several per-box random secrets the same way (`AGENT_PASSWORD`, `GOOSE_SERVER__SECRET_KEY`, both `tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32`) inside the block that fills in "secrets docker-compose.yml needs that Aeroform doesn't generate client-side." Add `PN_RELAY_SECRET` to that same block:

```diff
       if ! grep -q '^POCKETBASE_SUPERUSER_EMAIL=' "$INSTALL_DIR/.env"; then
         cat >> "$INSTALL_DIR/.env" <<EOF
 POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.local
 POCKETBASE_SUPERUSER_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
 AGENT_EMAIL=agent@pocketcoder.local
 AGENT_PASSWORD=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
 GOOSE_SERVER__SECRET_KEY=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
+PN_RELAY_SECRET=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32)
 EOF
       fi
```

- [ ] **Step 2: Verify the heredoc is still well-formed**

This file has no existing test coverage (confirmed: `grep -rl bootstrap.nix` under any `test/` directory in this repo returns nothing), so there's no automated check to run. Verify by eye and by grep:

Run: `grep -n 'PN_RELAY_SECRET' deploy/nixos/bootstrap.nix`
Expected: one line, inside the heredoc, using the identical `tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 32` pattern as its neighbors, and the heredoc's closing `EOF` still immediately follows it.

- [ ] **Step 3: Commit**

```bash
git add deploy/nixos/bootstrap.nix
git commit -m "feat(deploy): generate a per-deployment PN_RELAY_SECRET at first boot"
```

---

### Task 2: Add the `relay_bindings` table and `bind_relay_secret` RPC to Supabase

**Files:**
- Modify: `workers/push-relay/scripts/supabase-schema.sql`

**Interfaces:**
- Produces: a Postgres function `bind_relay_secret(p_secret_hash text, p_user_id text) returns text`, callable via `POST {SUPABASE_URL}/rest/v1/rpc/bind_relay_secret` with body `{"p_secret_hash": "...", "p_user_id": "..."}`, returning the (possibly pre-existing) bound `user_id` as a bare JSON string. Task 3 calls this.

- [ ] **Step 1: Append the table and function**

Follows the exact shape of this file's existing `push_quota`/`increment_push` — a plain `create table if not exists`, an explicit `service_role` grant (Supabase enables RLS with no policies by default, which denies `service_role` too without one), and an atomic upsert-then-read inside a single `plpgsql` function so a race between two concurrent first-use calls can't produce two different "winning" reads — the `insert ... on conflict do nothing` and the `select` are both inside the same function invocation, so whichever insert actually lands is what every concurrent caller reads back.

Add to the end of `workers/push-relay/scripts/supabase-schema.sql`:

```sql

-- relay_bindings: backs push-relay's tenant-isolation gate (src/index.js's
-- checkTenantBinding). Each deployment now generates its own random
-- PN_RELAY_SECRET at first boot (deploy/nixos/bootstrap.nix) instead of
-- every deployment sharing one literal value -- this table records which
-- user_id a given secret is allowed to act as, permanently, from the
-- first request that secret ever makes (trust-on-first-use). See
-- docs/superpowers/specs/2026-08-05-worker-security-hardening-design.md.
--
-- Apply once via the Supabase SQL editor, or:
--   psql "$SUPABASE_DB_URL" -f scripts/supabase-schema.sql

create table if not exists relay_bindings (
  secret_hash text primary key,
  user_id text not null,
  bound_at timestamptz not null default now()
);

grant select, insert on public.relay_bindings to service_role;

-- Atomic bind-or-check: on the first call for a given secret_hash, binds
-- it to p_user_id and returns p_user_id. On every later call, ignores
-- p_user_id and returns whatever user_id actually won the original bind
-- -- checkTenantBinding treats any mismatch between what it passed in and
-- what this returns as unauthorized. The insert and the read-back happen
-- inside one function call so two concurrent first-use requests can't
-- each observe "no row yet" and both believe they won.
create or replace function bind_relay_secret(p_secret_hash text, p_user_id text)
returns text
language plpgsql
as $$
declare
  bound_user_id text;
begin
  insert into relay_bindings (secret_hash, user_id)
  values (p_secret_hash, p_user_id)
  on conflict (secret_hash) do nothing;

  select user_id into bound_user_id
  from relay_bindings
  where secret_hash = p_secret_hash;

  return bound_user_id;
end;
$$;

grant execute on function public.bind_relay_secret(text, text) to service_role;
```

- [ ] **Step 2: Apply it to the Supabase project push-relay already uses**

Run: `psql "$SUPABASE_DB_URL" -f workers/push-relay/scripts/supabase-schema.sql`

(Or paste the new section into the Supabase SQL editor — this file is designed to be safely re-run, per its own header comment and `create table if not exists`/`create or replace function`.)

Expected: no errors. Verify with:

Run: `psql "$SUPABASE_DB_URL" -c "select bind_relay_secret('test-hash-abc', 'test-user-1');"`
Expected: returns `test-user-1`.

Run: `psql "$SUPABASE_DB_URL" -c "select bind_relay_secret('test-hash-abc', 'test-user-2');"`
Expected: still returns `test-user-1` (the first bind wins).

Run: `psql "$SUPABASE_DB_URL" -c "delete from relay_bindings where secret_hash = 'test-hash-abc';"`
(clean up the manual verification rows)

- [ ] **Step 3: Commit**

```bash
git add workers/push-relay/scripts/supabase-schema.sql
git commit -m "feat(push-relay): add relay_bindings table and bind_relay_secret RPC"
```

---

### Task 3: Add the tenant-binding check to `push-relay`, require `user_id` on the FCM path

**Files:**
- Modify: `workers/push-relay/src/index.js:1-94` (header comment + `fetch()`)
- Modify: `workers/push-relay/src/index.js` (add new functions near the other helpers, e.g. after `sendFCM`)
- Modify: `workers/push-relay/wrangler.toml` (drop `PN_RELAY_SECRET` from the secrets comment)
- Modify: `workers/push-relay/scripts/set-secrets.sh` (drop `PN_RELAY_SECRET` from the required-secrets loop)

**Interfaces:**
- Consumes: `bind_relay_secret` RPC from Task 2 (`{SUPABASE_URL}/rest/v1/rpc/bind_relay_secret`).
- Produces: `checkTenantBinding(secret, userId, env): Promise<Response | null>` — returns `null` if the request may proceed, or a `Response` to return immediately (403 mismatch, 502 on lookup failure). `sha256Hex(input: string): Promise<string>` — lowercase hex SHA-256, used both here and by Task 6's test script (which recomputes it independently to look up rows directly).

- [ ] **Step 1: Update the header comment's Flow line**

```diff
  * Flow:
- *   PocketBase POST → validate secret → RevenueCat sub check (cached)
- *   → Supabase daily quota → FCM v1 delivery → device buzzes
+ *   PocketBase POST → verify tenant binding (Supabase) → RevenueCat sub
+ *   check (cached) → Supabase daily quota → FCM v1 delivery → device buzzes
```

- [ ] **Step 2: Loosen the secret check and require `user_id`, add the binding check**

The old check compared against one literal expected value (`env.PN_RELAY_SECRET`) that every deployment shared. There's no longer a single expected value to compare against — each deployment has its own, and `checkTenantBinding` (Step 4) is what actually authenticates it now. This step only checks that *some* secret was sent; keep the `unifiedpush` branch as-is for now (Task 4 removes it separately).

```diff
 export default {
	async fetch(request, env) {
		if (request.method !== 'POST') {
			return json({ status: 'ok', service: 'pocketcoder-push-relay' }, 200);
		}

-		// Step 1: Validate shared secret
		const secret = request.headers.get('X-Relay-Secret');
-		if (secret !== env.PN_RELAY_SECRET) {
+		if (!secret) {
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

-			// Step 2: RevenueCat subscription check
-			if (user_id && env.REVENUECAT_SECRET_KEY) {
+			// user_id is now mandatory on this path: it used to be optional,
+			// and omitting it silently skipped both the RevenueCat and
+			// Supabase checks below (they only ran `if (user_id && ...)`),
+			// which meant anyone holding a relay secret could get
+			// unlimited free FCM sends just by leaving user_id out. See
+			// docs/superpowers/specs/2026-08-05-worker-security-hardening-design.md.
+			if (!user_id) {
+				return json({ error: 'user_id is required for fcm' }, 400);
+			}
+
+			// Step 1: Tenant-binding check -- see checkTenantBinding's own
+			// comment for why this exists and why it fails closed.
+			const bindingError = await checkTenantBinding(secret, user_id, env);
+			if (bindingError) {
+				return bindingError;
+			}
+
+			// Step 2: RevenueCat subscription check
+			if (env.REVENUECAT_SECRET_KEY) {
				const isPremium = await checkSubscription(user_id, env);
				if (!isPremium) {
					return json({ error: 'Subscription required', code: 'NOT_SUBSCRIBED' }, 403);
				}
			}

			// Step 3: Supabase daily quota check
-			if (user_id && env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
+			if (env.SUPABASE_URL && env.SUPABASE_SERVICE_KEY) {
				const count = await checkAndIncrementQuota(user_id, env);
				const limit = parseInt(env.DAILY_PUSH_LIMIT || '1000', 10);
				if (count > limit) {
					return json({ error: 'Daily push limit exceeded', count, limit }, 429);
				}
			}
```

The rest of `fetch()` (Step 4: FCM delivery, the `catch` block) is unchanged.

- [ ] **Step 3: Add `checkTenantBinding` and `sha256Hex`**

Add after `sendFCM` (before the `OAuth2 access token` section, or anywhere among the other helper functions):

```js
// ---------------------------------------------------------------------------
// Tenant-binding check (trust-on-first-use)
// ---------------------------------------------------------------------------

// PN_RELAY_SECRET used to be one literal value shared by every self-hosted
// deployment, so the old check only proved "this caller knows a value
// every deployment already has" -- not which deployment. Each deployment
// now generates its own random secret at first boot
// (deploy/nixos/bootstrap.nix) and this Worker has no single expected
// value to compare against anymore. Instead: the first request seen for a
// given secret permanently binds it to whatever user_id it presented, and
// every later request on that secret must match. A secret this Worker has
// never seen before (including a garbage/probing value) simply self-binds
// to whatever user_id came with it -- that's not a privilege escalation
// (it can't be used to act as any *other* secret's bound user_id), just a
// wasted Supabase row from unauthenticated probing traffic, same
// exposure every unauthenticated endpoint here already has.
//
// Returns null if the request may proceed, or a Response to return
// immediately otherwise.
async function checkTenantBinding(secret, userId, env) {
	const secretHash = await sha256Hex(secret);

	let boundUserId;
	try {
		const resp = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/bind_relay_secret`, {
			method: 'POST',
			headers: {
				apikey: env.SUPABASE_SERVICE_KEY,
				Authorization: `Bearer ${env.SUPABASE_SERVICE_KEY}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({ p_secret_hash: secretHash, p_user_id: userId }),
		});
		if (!resp.ok) {
			console.error(`bind_relay_secret returned ${resp.status}`);
			return json({ error: 'binding_check_failed' }, 502);
		}
		boundUserId = await resp.json();
	} catch (e) {
		console.error('Tenant binding check failed:', e.message);
		// Fail closed -- unlike the subscription/quota checks above (a
		// deliberate product choice to prioritize delivery over billing
		// enforcement during an outage), identity must never fail open.
		return json({ error: 'binding_check_failed' }, 502);
	}

	if (boundUserId !== userId) {
		return json({ error: 'user_id_mismatch' }, 403);
	}
	return null;
}

async function sha256Hex(input) {
	const data = new TextEncoder().encode(input);
	const digest = await crypto.subtle.digest('SHA-256', data);
	return Array.from(new Uint8Array(digest))
		.map((b) => b.toString(16).padStart(2, '0'))
		.join('');
}
```

- [ ] **Step 4: Remove the now-unused `PN_RELAY_SECRET` Worker-secret requirement**

After Step 2, `env.PN_RELAY_SECRET` is never read anywhere in `workers/push-relay/src/index.js` — the comparison it existed for is gone, replaced by `checkTenantBinding`. It's still legitimately needed as a *local test* value (Task 5/6's scripts derive per-test-user secrets from it), but it's no longer a secret this Worker needs configured on the Cloudflare side. Update the two places that still claim otherwise:

`workers/push-relay/wrangler.toml`:

```diff
 # Secrets (set via `wrangler secret put`):
-# PN_RELAY_SECRET       — shared secret with PocketBase
 # REVENUECAT_SECRET_KEY — RevenueCat V2 secret API key
```

`workers/push-relay/scripts/set-secrets.sh`:

```diff
-for name in PN_RELAY_SECRET REVENUECAT_SECRET_KEY REVENUECAT_PROJECT_ID FCM_PROJECT_ID FCM_CLIENT_EMAIL FCM_PRIVATE_KEY SUPABASE_URL SUPABASE_SERVICE_KEY; do
+for name in REVENUECAT_SECRET_KEY REVENUECAT_PROJECT_ID FCM_PROJECT_ID FCM_CLIENT_EMAIL FCM_PRIVATE_KEY SUPABASE_URL SUPABASE_SERVICE_KEY; do
```

Leave `workers/push-relay/.env.template`'s `PN_RELAY_SECRET=` line as-is — Task 5/6's scripts still read it from the local `.env`, just as a base value for derived per-test-user secrets rather than a Worker-side secret.

Run: `grep -rn PN_RELAY_SECRET workers/push-relay/wrangler.toml workers/push-relay/scripts/set-secrets.sh`
Expected: no output.

- [ ] **Step 5: No automated check yet for this task in isolation**

This repo has no unit-test harness for Workers (confirmed in `WORKER_AUDIT.md`'s verification notes — only `dev`/`deploy` scripts exist). This task's behavior is exercised end-to-end by Task 6's `test-tenant-binding.sh` against a real deployment. For now, sanity-check locally:

Run: `cd workers/push-relay && npx wrangler dev`
Then in another terminal:
Run: `curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8787 -H 'X-Relay-Secret: x' -H 'Content-Type: application/json' -d '{"token":"t","service":"fcm"}'`
Expected: `400` (missing `user_id`) — confirms the new mandatory check is wired in without needing real Supabase/RevenueCat credentials.

- [ ] **Step 6: Commit**

```bash
git add workers/push-relay/src/index.js workers/push-relay/wrangler.toml workers/push-relay/scripts/set-secrets.sh
git commit -m "feat(push-relay): add tenant-binding check, require user_id on the FCM path"
```

---

### Task 4: Delete the `unifiedpush` passthrough from `push-relay`

**Files:**
- Modify: `workers/push-relay/src/index.js`

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new — this task only deletes code. Confirmed dead from the real caller's side: `server/pocketbase/internal/hooks/notifications.go`'s `dispatchToDevices` sends UnifiedPush notifications via `NtfyDirectProvider`, which posts straight to the device's own ntfy endpoint and never touches `push-relay` at all. Only `FcmRelayProvider` calls this Worker, always with `service: "fcm"`. A repo-wide grep for `unifiedpush` outside this file, its own test scripts, and unrelated client-side device-registration code (`device.dart`, `ntfy_push_service.dart`, which just label a device's *registered* service — they never call this Worker) turns up no other caller.

- [ ] **Step 1: Remove the branch in `fetch()`**

```diff
-			// UnifiedPush: direct passthrough, no subscription/quota checks
-			if (service === 'unifiedpush') {
-				return await sendUnifiedPush(token, title, message, type, chat);
-			}
-
			if (service !== 'fcm') {
```

- [ ] **Step 2: Delete `sendUnifiedPush` and its section header**

```diff
-// ---------------------------------------------------------------------------
-// UnifiedPush passthrough (ntfy-compatible)
-// ---------------------------------------------------------------------------
-
-async function sendUnifiedPush(endpoint, title, message, type, chat) {
-	const clickUrl = chat ? `pocketcoder://chat/${chat}` : 'pocketcoder://';
-
-	const resp = await fetch(endpoint, {
-		method: 'POST',
-		headers: {
-			'Title': title || 'PocketCoder',
-			'Click': clickUrl,
-			'Priority': 'high',
-			...(type && { 'Tags': type }),
-		},
-		body: message || '',
-	});
-
-	return new Response(await resp.text(), {
-		status: resp.status,
-		headers: { 'Content-Type': 'application/json' },
-	});
-}
-
 // ---------------------------------------------------------------------------
 // Helpers
 // ---------------------------------------------------------------------------
```

- [ ] **Step 3: Verify**

Run: `grep -n unifiedpush workers/push-relay/src/index.js`
Expected: no output (the string no longer appears anywhere in the file).

Run: `cd workers/push-relay && npx wrangler dev`, then in another terminal:
Run: `curl -s -X POST http://localhost:8787 -H 'X-Relay-Secret: x' -H 'Content-Type: application/json' -d '{"token":"t","service":"unifiedpush"}'`
Expected: `{"error":"Unknown service: unifiedpush"}` with HTTP `400`.

- [ ] **Step 4: Commit**

```bash
git add workers/push-relay/src/index.js
git commit -m "fix(push-relay): remove the unifiedpush SSRF primitive (dead code, unused by any real caller)"
```

---

### Task 5: Fix `test-paid-path.sh` to derive per-test-user secrets

**Files:**
- Modify: `workers/push-relay/scripts/test-paid-path.sh:12-13` (header comment)
- Modify: `workers/push-relay/scripts/test-paid-path.sh:122-129` (`call_push_relay`)

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing new. This script currently reuses one `PN_RELAY_SECRET` across four different `user_id`s (`USER_NOSUB`, `USER_SUB`, `QUOTA_USER`, `FCM_USER`) across its three stages. After Task 3 lands, the *first* of those calls would bind that secret to its `user_id`, and every later call with a different `user_id` would get rejected with `403 user_id_mismatch` before ever reaching the RevenueCat/quota logic the script exists to test. This task must land before this script is run again against a Task-3-updated Worker.

- [ ] **Step 1: Update the header comment**

```diff
 # Required:
-#   PN_RELAY_SECRET        shared secret push-relay validates via X-Relay-Secret
+#   PN_RELAY_SECRET        base secret this script derives a distinct
+#                          per-test-user secret from (see
+#                          call_push_relay) -- push-relay now binds each
+#                          secret to the first user_id it sees, so reusing
+#                          one secret across this script's several test
+#                          users would make every call after the first
+#                          fail with 403 user_id_mismatch instead of
+#                          reaching the check under test
```

- [ ] **Step 2: Derive a per-user secret in `call_push_relay`**

```diff
 call_push_relay() {
   user_id="$1"
   token="$2"
+  # Each test user_id needs its own secret now that push-relay binds a
+  # secret to the first user_id it ever sees (trust-on-first-use).
+  secret="${PN_RELAY_SECRET}-${user_id}"
   curl -s -o /tmp/push-relay-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
-    -H "X-Relay-Secret: ${PN_RELAY_SECRET}" \
+    -H "X-Relay-Secret: ${secret}" \
     -H "Content-Type: application/json" \
     -d "{\"token\":\"${token}\",\"user_id\":\"${user_id}\",\"service\":\"fcm\",\"title\":\"test\",\"message\":\"test\",\"type\":\"general\"}"
 }
```

- [ ] **Step 3: Verify the script still runs**

Run: `cd workers/push-relay && set -a && . ./.env && set +a && ./scripts/test-paid-path.sh`
(requires a populated `.env` per `.env.template`, against a deployed Worker with Tasks 2–4 live)
Expected: `=== ALL STAGES PASSED ===`. If Stage 1 or 2 fail with `403 user_id_mismatch` instead of their expected assertions, this step wasn't applied correctly (each `user_id` used in this script must be a first-ever use of its derived secret — if you're re-running against the same Supabase project, either use fresh `RUN_ID`-suffixed user ids, which the script already does, or clear stale rows from `relay_bindings` first).

- [ ] **Step 4: Commit**

```bash
git add workers/push-relay/scripts/test-paid-path.sh
git commit -m "fix(push-relay): derive per-test-user secrets in test-paid-path.sh"
```

---

### Task 6: Add `test-tenant-binding.sh`

**Files:**
- Create: `workers/push-relay/scripts/test-tenant-binding.sh`

**Interfaces:**
- Consumes: the deployed `push-relay` Worker (Tasks 3–4 live), the `relay_bindings` table (Task 2 live).

- [ ] **Step 1: Write the script**

```sh
#!/bin/sh
# Tests push-relay's tenant-binding gate (trust-on-first-use): the first
# request seen for a given X-Relay-Secret permanently binds it to whatever
# user_id it presented; later requests on that secret must match. No
# RevenueCat setup needed here -- the binding check runs and returns
# before the RevenueCat check, so an unrecognized test user_id still lets
# every assertion below distinguish cleanly by response body
# ("user_id_mismatch" is the one string that must never appear when it
# shouldn't).
#
# Reads secrets from the environment (see .env.template /
# scripts/test-paid-path.sh for how to populate them).
#
# Required:
#   SUPABASE_URL           e.g. https://xxx.supabase.co
#   SUPABASE_SERVICE_KEY   Supabase service_role key
set -eu

PUSH_RELAY_URL="${PUSH_RELAY_URL:-https://push.relay.pocketcoder.org}"
: "${SUPABASE_URL:?}"
: "${SUPABASE_SERVICE_KEY:?}"

RUN_ID=$(date +%s)
FAIL=0

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

sha256_hex() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  else
    shasum -a 256 | cut -d' ' -f1
  fi
}

call_push_relay() {
  secret="$1"
  user_id="$2"
  curl -s -o /tmp/push-relay-bind-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
    -H "X-Relay-Secret: ${secret}" \
    -H "Content-Type: application/json" \
    -d "{\"token\":\"fake-token\",\"user_id\":\"${user_id}\",\"service\":\"fcm\",\"title\":\"t\",\"message\":\"m\",\"type\":\"general\"}"
}

row_user_id_for_secret() {
  secret="$1"
  hash=$(printf '%s' "$secret" | sha256_hex)
  curl -sS "${SUPABASE_URL}/rest/v1/relay_bindings?secret_hash=eq.${hash}&select=user_id" \
    -H "apikey: ${SUPABASE_SERVICE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
    | python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['user_id'] if d else '')"
}

echo "=== Stage 1: unifiedpush is gone ==="
code=$(curl -s -o /tmp/push-relay-bind-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
  -H "X-Relay-Secret: test-bind-unknown-${RUN_ID}" \
  -H "Content-Type: application/json" \
  -d '{"token":"anything","service":"unifiedpush"}')
if [ "$code" = "400" ] && grep -q 'Unknown service' /tmp/push-relay-bind-resp.json; then
  pass "unifiedpush is rejected as an unknown service"
else
  fail "expected 400 Unknown service for unifiedpush, got HTTP $code: $(cat /tmp/push-relay-bind-resp.json)"
fi

echo ""
echo "=== Stage 2: first use binds the secret ==="
SECRET_A="test-bind-a-${RUN_ID}"
USER_A="push-relay-test-bind-user-a-${RUN_ID}"
code=$(call_push_relay "$SECRET_A" "$USER_A")
if grep -q 'user_id_mismatch' /tmp/push-relay-bind-resp.json; then
  fail "first use of a never-seen secret was rejected as a mismatch (HTTP $code): $(cat /tmp/push-relay-bind-resp.json)"
else
  pass "first use of a never-seen secret passes the binding gate (HTTP $code)"
fi

bound=$(row_user_id_for_secret "$SECRET_A")
if [ "$bound" = "$USER_A" ]; then
  pass "Supabase relay_bindings row was created for the first user_id"
else
  fail "expected relay_bindings.user_id = $USER_A, got: '$bound'"
fi

echo ""
echo "=== Stage 3: a different user_id on the same secret is rejected ==="
USER_B="push-relay-test-bind-user-b-${RUN_ID}"
code=$(call_push_relay "$SECRET_A" "$USER_B")
if [ "$code" = "403" ] && grep -q 'user_id_mismatch' /tmp/push-relay-bind-resp.json; then
  pass "a mismatched user_id on an already-bound secret is rejected (403 user_id_mismatch)"
else
  fail "expected 403 user_id_mismatch, got HTTP $code: $(cat /tmp/push-relay-bind-resp.json)"
fi

echo ""
echo "=== Stage 4: the original user_id still works on the same secret ==="
code=$(call_push_relay "$SECRET_A" "$USER_A")
if grep -q 'user_id_mismatch' /tmp/push-relay-bind-resp.json; then
  fail "the originally-bound user_id was rejected (HTTP $code): $(cat /tmp/push-relay-bind-resp.json)"
else
  pass "the originally-bound user_id is still accepted (HTTP $code)"
fi

echo ""
echo "=== Stage 5: user_id is mandatory for fcm ==="
code=$(curl -s -o /tmp/push-relay-bind-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
  -H "X-Relay-Secret: test-bind-c-${RUN_ID}" \
  -H "Content-Type: application/json" \
  -d '{"token":"anything","service":"fcm"}')
if [ "$code" = "400" ] && grep -q 'user_id is required' /tmp/push-relay-bind-resp.json; then
  pass "omitting user_id on the fcm path is rejected, not silently allowed through"
else
  fail "expected 400 user_id is required, got HTTP $code: $(cat /tmp/push-relay-bind-resp.json)"
fi

echo ""
echo "=== Stage 6: concurrent first use -- exactly one user_id wins ==="
SECRET_RACE="test-bind-race-${RUN_ID}"
USER_R1="push-relay-test-bind-race-1-${RUN_ID}"
USER_R2="push-relay-test-bind-race-2-${RUN_ID}"
curl -s -o /dev/null -X POST "$PUSH_RELAY_URL" \
  -H "X-Relay-Secret: ${SECRET_RACE}" -H "Content-Type: application/json" \
  -d "{\"token\":\"fake-token\",\"user_id\":\"${USER_R1}\",\"service\":\"fcm\",\"title\":\"t\",\"message\":\"m\",\"type\":\"general\"}" &
pid1=$!
curl -s -o /dev/null -X POST "$PUSH_RELAY_URL" \
  -H "X-Relay-Secret: ${SECRET_RACE}" -H "Content-Type: application/json" \
  -d "{\"token\":\"fake-token\",\"user_id\":\"${USER_R2}\",\"service\":\"fcm\",\"title\":\"t\",\"message\":\"m\",\"type\":\"general\"}" &
pid2=$!
wait "$pid1"
wait "$pid2"
bound_race=$(row_user_id_for_secret "$SECRET_RACE")
if [ "$bound_race" = "$USER_R1" ] || [ "$bound_race" = "$USER_R2" ]; then
  pass "concurrent first-use race resolved to exactly one user_id ($bound_race)"
else
  fail "expected relay_bindings to hold exactly one of $USER_R1/$USER_R2, got: '$bound_race'"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "=== ALL STAGES PASSED ==="
else
  echo "=== ONE OR MORE STAGES FAILED ==="
  exit 1
fi
```

- [ ] **Step 2: Make it executable and run it**

Run: `chmod +x workers/push-relay/scripts/test-tenant-binding.sh`
Run: `cd workers/push-relay && set -a && . ./.env && set +a && ./scripts/test-tenant-binding.sh`
(requires Tasks 2–4 deployed; `.env` needs at least `SUPABASE_URL`/`SUPABASE_SERVICE_KEY` per `.env.template`)
Expected: `=== ALL STAGES PASSED ===`

- [ ] **Step 3: Commit**

```bash
git add workers/push-relay/scripts/test-tenant-binding.sh
git commit -m "test(push-relay): add integration test for the tenant-binding gate"
```

---

### Task 7: Delete `image-relay`'s dead credential-forwarding routes

**Files:**
- Modify: `workers/image-relay/src/index.ts` (full rewrite — most of the file is deleted)
- Modify: `workers/image-relay/wrangler.toml`

**Interfaces:**
- Produces: `image-relay` now only serves `GET /image-manifest` and `GET /health` — the same public contract `BootTimePullProvisioningStrategy` in `flutter_aeroform` already relies on (Task 8 deletes the only other caller).

- [ ] **Step 1: Replace `workers/image-relay/src/index.ts`**

Confirmed unreachable: `flutter_aeroform`'s DI container (`flutter_aeroform.module.dart`) registers `CustomImageProvisioningStrategy` — the only caller of `/upload-image` and `/image-status` — under `@Named('customImage')`, and nothing in the codebase looks it up by that name; `IInstanceProvisioningStrategy` resolves to the unnamed `BootTimePullProvisioningStrategy` binding, which only ever calls `/image-manifest`.

```ts
/**
 * PocketCoder Image Relay Worker
 *
 * Serves the published NixOS image manifest that every deployment's
 * boot-time provisioning strategy reads to find the current image to
 * install. See
 * docs/superpowers/specs/2026-08-05-worker-security-hardening-design.md
 * for why the older upload/status routes (a Linode-bearer-token proxy
 * used only by the now-deleted CustomImageProvisioningStrategy) were
 * removed.
 */

interface Env {
  IMAGES: R2Bucket;
}

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    const url = new URL(request.url);

    if (url.pathname === "/image-manifest" && request.method === "GET") {
      return handleImageManifest(env);
    }

    if (url.pathname === "/health") {
      return json({ status: "ok" });
    }

    return json({ error: "Not found" }, 404);
  },
};

async function handleImageManifest(env: Env): Promise<Response> {
  // Read-only, deliberately: this manifest is the single point of
  // indirection every future deployment trusts for which image to dd
  // onto its root disk. The Worker has no write route for it at all --
  // CI writes the object directly to R2 with its own scoped credential
  // (see .github/workflows/nixos-image.yml). An unauthenticated write
  // route here would be remote code execution on every future
  // deployment (the sha256 the manifest carries provides no protection
  // against a malicious manifest, since the attacker supplies that too).
  const obj = await env.IMAGES.get("image-manifest.json");
  if (!obj) {
    return json({ error: "No manifest published yet" }, 404);
  }
  const manifest = await obj.json();
  return json(manifest);
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}
```

- [ ] **Step 2: Update `wrangler.toml`**

Remove the queue producer binding (its only consumer was already commented out, serving the same now-deleted strategy) and the now-unused `NIXOS_IMAGE_KEY` var:

```toml
name = "pocketcoder-image-relay"
main = "src/index.ts"
compatibility_date = "2024-12-01"

[[r2_buckets]]
binding = "IMAGES"
bucket_name = "pocketcoder-images"
```

Note for whoever deploys this: the underlying Cloudflare Queue (`pocketcoder-image-uploads`) can be deleted separately via `wrangler queues delete pocketcoder-image-uploads` — that's an account-level cleanup action outside version control, not part of this commit.

- [ ] **Step 3: Verify**

Run: `cd workers/image-relay && npx tsc --noEmit` (if a `tsconfig.json` exists in this package; otherwise skip — confirm with `ls tsconfig.json`)
Expected: no type errors (no dangling references to deleted interfaces/functions).

Run: `cd workers/image-relay && npx wrangler dev`, then in another terminal:
Run: `curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8787/upload-image -d '{}'`
Expected: `404`

Run: `curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8787/health`
Expected: `200`

- [ ] **Step 4: Commit**

```bash
git add workers/image-relay/src/index.ts workers/image-relay/wrangler.toml
git commit -m "fix(image-relay): delete dead credential-forwarding routes (/upload-image, /image-status)"
```

---

### Task 8: Delete `CustomImageProvisioningStrategy` from `flutter_aeroform`

**Files:**
- Delete: `flutter_aeroform/lib/infrastructure/deployment/custom_image_provisioning_strategy.dart`
- Delete: `flutter_aeroform/test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart`
- Regenerate (do not hand-edit): `flutter_aeroform/lib/flutter_aeroform.module.dart`

**Interfaces:**
- Produces: `IInstanceProvisioningStrategy` continues to resolve to `BootTimePullProvisioningStrategy` (unaffected — it was never named, `DeploymentService` already consumes the unnamed binding).

- [ ] **Step 1: Delete both files**

```bash
rm flutter_aeroform/lib/infrastructure/deployment/custom_image_provisioning_strategy.dart
rm flutter_aeroform/test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart
```

- [ ] **Step 2: Regenerate DI wiring**

Run: `cd flutter_aeroform && dart run build_runner build --delete-conflicting-outputs`
Expected: completes without error; `flutter_aeroform.module.dart` no longer imports `custom_image_provisioning_strategy.dart` or registers anything under `instanceName: 'customImage'`.

- [ ] **Step 3: Verify nothing else references it**

Run: `grep -rn "CustomImageProvisioningStrategy\|customImage" flutter_aeroform/lib flutter_aeroform/test`
Expected: no output.

- [ ] **Step 4: Run the test suite**

Run: `cd flutter_aeroform && flutter test`
Expected: all tests pass (the deleted strategy's own test file is gone; no other test file referenced it per Step 3's grep).

- [ ] **Step 5: Commit**

```bash
git add -A flutter_aeroform/lib/infrastructure/deployment/custom_image_provisioning_strategy.dart \
  flutter_aeroform/test/infrastructure/deployment/custom_image_provisioning_strategy_test.dart \
  flutter_aeroform/lib/flutter_aeroform.module.dart
git commit -m "fix(flutter_aeroform): delete unreachable CustomImageProvisioningStrategy"
```

---

### Task 9: Annotate resolved findings in `WORKER_AUDIT.md`

**Files:**
- Modify: `WORKER_AUDIT.md`

- [ ] **Step 1: Mark PUSH-001 (SSRF) resolved**

Find the `#### PUSH-001 — UnifiedPush endpoint is an SSRF primitive` heading's remediation line and add directly beneath the section (before the next `####`):

```markdown
**Resolved (2026-08-05):** the `unifiedpush` passthrough was deleted outright rather than hardened — confirmed unused by any real caller (`server/pocketbase/internal/hooks/notifications.go`'s `NtfyDirectProvider` already posts straight to the user's own ntfy endpoint and never touches this Worker). See `docs/superpowers/specs/2026-08-05-worker-security-hardening-design.md`.
```

- [ ] **Step 2: Add a note to PUSH-002 (fail-open) about the more severe bypass found during implementation**

Add beneath the existing PUSH-002 remediation line:

```markdown
**Update (2026-08-05):** a more severe, always-available variant of this was found while implementing the tenant-binding fix: both the RevenueCat and Supabase checks below were only run `if (user_id && ...)`, so omitting `user_id` entirely — not just waiting for a dependency outage — skipped billing enforcement completely. That specific bypass is now closed (`user_id` is mandatory on the fcm path). The originally-documented fail-open-during-a-genuine-outage behavior is unchanged, and remains a deliberate product tradeoff per the code's own comment.
```

- [ ] **Step 3: Mark PUSH-006 and PUSH-007 (reviewer-addendum findings) resolved**

Add beneath PUSH-006's remediation line:

```markdown
**Resolved (2026-08-05):** replaced the single shared secret with a per-deployment secret (generated at first boot, `deploy/nixos/bootstrap.nix`) bound to exactly one `user_id` on first use (`relay_bindings` table + `bind_relay_secret` RPC, checked in `checkTenantBinding`). See the design doc for the full mechanism.
```

Add beneath PUSH-007's remediation line:

```markdown
**Moot (2026-08-05):** the `!== env.PN_RELAY_SECRET` comparison this finding was about no longer exists — there's no single expected value left to compare against (see PUSH-006's resolution). Not a resolved timing-safety fix so much as a removed code path.
```

- [ ] **Step 4: Mark IMAGE-001, IMAGE-002, IMAGE-003 resolved**

Add beneath each of IMAGE-001, IMAGE-002, and IMAGE-003's remediation lines:

```markdown
**Resolved (2026-08-05):** `/upload-image`, `/image-status`, and the queue path were deleted outright as confirmed-unreachable dead code, along with their only caller (`CustomImageProvisioningStrategy` in `flutter_aeroform`), rather than hardened. See the "Dead-code finding" note earlier in this section and `docs/superpowers/specs/2026-08-05-worker-security-hardening-design.md`.
```

- [ ] **Step 5: Commit**

```bash
git add WORKER_AUDIT.md
git commit -m "docs: annotate WORKER_AUDIT.md findings resolved by the worker security hardening work"
```
