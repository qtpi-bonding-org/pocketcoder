# Remaining paid/backend integration tests — status as of 2026-08-02

Working note, not a deliverable doc. Supersedes the old
`TESTFLIGHT_SETUP_STATUS.md` (deleted) — TestFlight signing is resolved,
so that doc's blocker no longer applies. This tracks what's left to
verify across the paid/backend surface.

## Done — live-tested against the real service (not mocks)

- **Linode OAuth relay + provisioning** — real deploy of
  `workers/oauth-relay` (per-provider token flags + `/refresh`
  route), a real `LinodeAPIClient` provisioning run (real instance
  created, NixOS image booted, `/api/health` + passwordless SSH
  confirmed, instance torn down cleanly), and a real corrupted-manifest
  teardown test (no orphaned instance). See
  `docs/superpowers/plans/2026-08-02-linode-oauth-relay-migration.md`.
- **image-relay** (`workers/image-relay`'s `/image-manifest` route) —
  confirmed live and load-bearing as part of the above: boot-time-pull
  provisioning fetches the real image URL/sha256/uncompressedBytes from
  this Worker, not a hardcoded value. If it were down or misconfigured
  the golden-path run above would have failed before creating an
  instance — it didn't, so this counts as exercised for real.
- **Supabase** (push-relay's push-count rate limiting) — RPC driven
  past its daily limit against the real table, enforcement confirmed.
- **RevenueCat entitlement gating** (push-relay's server-side paid-path
  check) — real unsubscribed-user rejection + real promo-granted
  subscriber pass, against the live deployed Worker.
- **GitHub OAuth** (oauth-relay's other provider) — pre-existing,
  proven baseline pattern Linode's migration was modeled on.
- **TestFlight signing/upload** — resolved (confirmed working).

## Still open

| Item | What's needed | Human-only? |
|---|---|---|
| Real Linode browser OAuth consent | Someone clicks through Linode's actual login/consent screen once, end-to-end in the real app | Yes |
| RevenueCat real purchase flow (client-side) | A real sandbox/production App Store transaction on a device | Yes — needs a device with the TestFlight build |
| Real FCM push delivery | A real `FCM_TEST_TOKEN` captured from a physical device running the TestFlight build (push-relay paid-path test's Stage 3) | Yes — now unblocked since TestFlight works |

None of the three remaining items are agent-automatable — each needs a
human on a real device or clicking through a real consent/payment
screen. Once done, the "known-working" list above should be complete
for the paid/backend surface.
