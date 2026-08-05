# Linode scoped reviewer access — scratch TODO

Not committed. Just a working list so we don't lose track of the pieces
across a few different sittings. See conversation history for the full
reasoning behind each item.

**SUPERSEDED (2026-08-02):** the PAT-vending/bypass approach below (OAuth
app registration, `oauth-relay` Linode provider wiring, the
scope-test PAT, `build-reviewer-ipa.sh`, `LINODE_REVIEWER_PAT` /
`REVIEWER_TOKEN_PASSWORD_HASH` secrets) is replaced by a dedicated real
Linode account with a spend-capped virtual card, whose real credentials
just go in App Store Connect's "Notes for Review" field — no app code,
no Worker route, no bypass at all. See sub-project 3 in
`docs/superpowers/specs/2026-08-02-apple-review-linode-access-overview.md`.
The one still-relevant fact from below: the confirmed `Linodes:
Read/Write`-only scope test result (real instances only need that scope,
not `Images:Read`) — not directly needed anymore since reviewers now do
real OAuth with full account access, but worth keeping as a fact in case
scoped-token work resurfaces later. Everything else below is dead;
`scripts/build-reviewer-ipa.sh` has been deleted.

## All items

### Linode dashboard (Cloud Manager)
- [x] Create scope-test PAT: `Linodes: Read/Write` only, everything else
      `None`, 1-2 day expiry
- [ ] Register a Linode OAuth application: **Public** client (PKCE, no
      secret). **CORRECTION**: Linode's OAuth app registration rejects
      non-http(s) redirect URIs ("Invalid protocol") — the original spec
      (`docs/superpowers/specs/2026-07-27-mcp-oauth-flow-design.md`
      line 91) assumed `pocketcoder://oauth-callback` would be accepted
      directly; that assumption was wrong. **THIRD CORRECTION** (found via
      the actual `deploy_mcp_oauth_relay` output): the real URL is
      `https://oauth.relay.pocketcoder.org/callback`
      — Cloudflare's free `workers.dev` route includes the account
      subdomain (`gp-c53`), it's NOT the bare
      `pocketcoder-oauth-relay.gp-c53.workers.dev` originally guessed (that
      guess matched the existing OAuth relay endpoint configuration
      constant in `external_module.dart` — needs fixing there too when
      task #11 gets implemented). If the OAuth app was registered with
      the bare-domain URL, go fix that registration to the `gp-c53` one.
      NOTE: this only matters for task #11 (real end-user OAuth) — the
      reviewer-bypass PAT approach below never does interactive OAuth at
      all, so this doesn't block that path.
- [x] **SECOND CORRECTION**: Linode's OAuth app registration issues a
      client_secret even for a "Public" client type — same situation as
      GitHub (which the original spec already knew requires one even
      with PKCE). This client_secret goes into the **existing**
      `secrets/oauth-relay.enc.yaml` vault file (same one GitHub's
      already in), as two new keys: `LINODE_OAUTH_CLIENT_ID` and
      `LINODE_OAUTH_CLIENT_SECRET`. **No new actions.json entry needed**
      — `set_mcp_oauth_relay_secrets` and `deploy_mcp_oauth_relay` already
      exist and now handle Linode too:
      - `workers/oauth-relay/src/index.js` — added a `linode` entry to
        `PROVIDERS` (authorizeUrl/tokenUrl/scope, scope matches
        `LinodeOAuthService._requiredScopes`)
      - `workers/oauth-relay/scripts/set-secrets.sh` — now loops over
        `LINODE_OAUTH_CLIENT_ID`/`LINODE_OAUTH_CLIENT_SECRET` too
      - `wrangler.toml` comment updated to document both new keys
- [ ] (LATER, not now) Create the real, longer-lived reviewer-mode PAT
      — same `Linodes: Read/Write`-only scoping, expiry matched to the
      actual App Review / Shipaton judging window (~2-4 weeks)
- [ ] (LATER) Revoke the reviewer-mode PAT once review/judging is done
- [ ] (LATER) Let/confirm the scope-test PAT expires or revoke it once
      the test's answered

### Vault / actions.json (one sops + update.sh cycle covers all of this)
- [x] Add `secrets/linode-scope-test.enc.yaml` (`LINODE_SCOPE_TEST_PAT`)
      + the `linode_scope_test` action (script already written at
      `scripts/linode-scope-test.sh`)
- [x] Script written: `scripts/build-reviewer-ipa.sh` (uses
      `--dart-define-from-file` via a `mktemp` temp file, not a plain
      `--dart-define=KEY=$VALUE`, so the secret never shows up in `ps
      aux` output during the build). Bakes in `USE_TEST_STORE=true`,
      `REVIEWER_MODE=true`, `LINODE_REVIEWER_PAT=$LINODE_REVIEWER_PAT`.
      `REVIEWER_MODE`/`LINODE_REVIEWER_PAT` aren't read by any Dart code
      yet — that's the Phase 3 implementation work below — building with
      them now is harmless, just inert until that lands.
- [x] Add secrets file `secrets/linode-reviewer-build.enc.yaml`
      (`LINODE_REVIEWER_PAT`, placeholder value ok for now) + this action
      block to `actions.json`:
      ```json
      "build_pocketcoder_reviewer_ipa": {
        "secrets": "secrets/linode-reviewer-build.enc.yaml",
        "command": ["/bin/sh", "/Users/aicoder/Documents/pocketcoder/scripts/build-reviewer-ipa.sh"],
        "return_output": true
      }
      ```
      Filling in the real PAT later (Phase 4) is then just a `sops` edit
      against this same file — no second update.sh/lock dance needed.
- [ ] Decide: does `LINODE_CLIENT_ID` (the OAuth app's client_id) need
      vault protection at all? It's a **public** PKCE client id, arguably
      non-secret by design (same category as `REVENUE_CAT_APPLE_KEY`) —
      worth deciding whether it just goes straight into a build command
      as a plain `--dart-define`, or still goes through the daemon given
      the "no .env except one exception" rule. Your call.

### Code / spec work (no more dashboard or vault trips needed for this part)
- [x] **ANSWERED**: `linode_scope_test` ran for real — created a live
      `g6-nanode-1` from `linode/debian12` with a token scoped to ONLY
      `Linodes: Read/Write` (HTTP 200), then deleted it cleanly.
      `RESULT=PASS_LINODES_SCOPE_ALONE_IS_SUFFICIENT`. **`Images:Read` is
      not needed** — the reviewer PAT only ever needs the one scope.
- [ ] Brainstorm + write a real spec/plan (usual skill flow) for: a build
      flag that skips Aeroform's interactive Linode OAuth screen and
      pre-seeds `FlutterSecureStorage`'s `access_token` key directly with
      a provided PAT
- [ ] Verify Aeroform's code never tries to refresh a preseeded PAT via
      the OAuth refresh-token flow (PATs have no refresh token — confirm
      this doesn't break anything)
- [ ] Decide flag naming/composition with the existing `USE_TEST_STORE`
      flag — a reviewer build almost certainly wants both on at once
      (IAP + deploy both need to be really testable)
- [ ] Enforce cost controls in code for reviewer mode: cheapest tier only
      (`g6-nanode-1`), hard cap of 1 instance at a time, reject further
      creates
- [ ] Actually test the real production Linode OAuth consent flow
      end-to-end once the OAuth app is registered (this is the
      pre-existing pending task #11)
- [ ] One pre-existing demo PocketBase account/deployment for whatever
      *doesn't* need live Linode interaction (chat, settings, etc.) —
      separate from all the Linode work

### Final assembly (right before actually submitting)
- [ ] Generate the real reviewer-mode PAT (see "LATER" item above)
- [ ] `sops` the real value into the pre-wired secrets file (no
      update.sh needed, action already exists)
- [ ] Invoke the build action — daemon builds the `.ipa` with the PAT
      injected, never touches disk in plaintext, never seen by the agent
- [ ] Submit to Apple / Shipaton
- [ ] Revoke the reviewer PAT once done

## Dependency order (batched to avoid back-and-forth)

**Phase 1 — one trip to Linode's Cloud Manager:**
1. Create the scope-test PAT
2. Register the OAuth app, grab the client_id
(Do NOT create the real long-lived reviewer PAT yet — its expiry clock
starts the moment it's created, so that one waits until Phase 4.)

**Phase 2 — one sops + update.sh cycle, covers everything we know we'll
need:**
1. Add the scope-test secret + action
2. Pre-wire the reviewer-build secret file (placeholder value) + action
3. Decide + wire `LINODE_CLIENT_ID` handling (vault or plain dart-define)

From here on, no more update.sh/lock-dance is needed — filling in a real
secret value later is just a `sops` edit against a file that already
exists.

**Phase 3 — code and testing, no more dashboard/vault trips:**
1. Run the scope test, get the answer
2. Write the spec/plan for the reviewer-bypass feature
3. Implement: build flag, preseed logic, cost caps
4. Test the real production OAuth flow (task #11)
5. Set up the demo PocketBase account

**Phase 4 — final assembly, right before submitting:**
1. Generate the real reviewer PAT
2. `sops` it into the already-existing secrets file
3. Invoke the build action
4. Submit
5. Revoke the PAT afterward
