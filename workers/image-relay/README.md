# image-relay

Serves at `images.relay.pocketcoder.org` (and `images.pocketcoder.org`,
an older custom-domain route still attached to the same Worker). Backed
by a single R2 bucket (`pocketcoder-images`, binding `IMAGES`). This
Worker **never holds provider credentials and never writes to R2** —
it's a read-only relay in front of objects CI/promotion tooling writes
directly. All routes are defined in `src/index.ts`.

## What it serves

Routes: `/v1/channels/{stable,beta,nightly}[-testing].json`,
`/v1/releases/<sha256>.json`, `/v1/attestations/...`,
`/v1/artifacts/<sha256>.{tar.gz,img.gz}`, `/v1/documents/...`,
`/v1/revocations/releases.json`, plus `/v1/health`/`/health`.

This is what a **running** box's `pocketcoder-release` binary polls to
decide "is there a newer release I should update to," and what a
**fresh** box's provisioning strategy reads to get the raw NixOS boot
image URL — both come from the same digest-addressed, GitHub-attested
(sigstore) manifest system, not two separate pipelines. The full write
path:

1. `.github/workflows/nixos-image.yml` builds + attests an immutable
   candidate, publishes it under `/v1/releases/<digest>.json` and
   friends (`deploy/ci/publish-attested-candidate.sh`). The manifest's
   `osImages.nixos.delivery.artifact` field is the raw boot image's
   URL/sha256 — `pocketcoder-pro`'s `config_adapter.dart` reads it
   straight from there for fresh provisioning; there is no separate
   raw-image publish step.
2. `deploy/nixos/scripts/promote-latest-candidate.sh <channel>` (daemon
   action `promote_latest_nixos_candidate`) dispatches
   `.github/workflows/release-promotion.yml`, which attests and
   publishes the channel pointer (`/v1/channels/<channel>.json`).
3. `internal/release/resolver.go`'s `ChannelPath()` is the
   authoritative logic for which channel-pointer path a given branch's
   build trusts — **`main` writes/reads the bare `nightly.json` etc.;
   every other branch (today, just `staging`) gets a fixed `-testing`
   suffix**, so a staging promotion can never overwrite the pointer a
   real production box polls. `release-promotion.yml`'s "Compute
   branch-qualified channel path" step and the Worker's
   `resolveV1ObjectPath()` regex must both stay in sync with this — if
   you're chasing "the pointer isn't updating," check you're polling
   the `-testing` path before assuming anything is broken.
4. **A promoted image also has to actually trust the branch it was
   promoted on.** `deploy/nixos/scripts/trigger-ci-build.sh`'s
   `--attest-branch` flag bakes `POCKETCODER_GITHUB_WORKFLOW_BRANCH`
   into the image at build time; without it, every image defaults to
   trusting `main` regardless of which branch built it. Promoting a
   non-`--attest-branch` build onto a `-testing` channel produces a
   box that resolves the *bare* production channel at boot instead —
   confirmed live: "resolved release does not match the expected
   digest," 100% reproducible. Always pair a `-testing` promotion with
   an `--attest-branch` build.
5. `deploy/ci/verify-candidate-published.sh` gates the pointer publish
   on every referenced object actually being publicly fetchable first
   (an R2 eventual-consistency guard, up to ~10 min) — a stale-looking
   pointer for the first several minutes after a promotion run
   "succeeds" is expected, not a bug.

## History: the routes that used to live here

`/image-manifest` and `/release-manifest` were an earlier (2026-07-29)
design for publishing the raw boot image before the manifest above grew
an `osImages` field and made a separate endpoint unnecessary. They were
never actually wired to any automated publisher, sat unread by any real
code for weeks, and were removed entirely (commit removing them from
`src/index.ts`, same day as this doc's last rewrite) — both now 404.
`/upload-image` (an even older, fully-disabled custom-Linode-image
upload strategy) was already gone before that. The scripts and R2
objects that referenced any of these are deleted too. If you're reading
old context (commit messages, chat logs, a stale doc) that talks about
"the raw boot image gap" or "§2" — that was a real, resolved point of
confusion during that investigation, not a pipeline that still exists.

## Updating everything

- **Redeploy the Worker itself** (after a code change to
  `src/index.ts`/`wrangler.toml`): `cd workers/image-relay && npx
  wrangler deploy`. Requires Cloudflare API credentials in the
  environment. Not automatic on push — see `workers/README.md`.
- **Build a new NixOS release candidate**:
  `deploy/nixos/scripts/trigger-ci-build.sh [--attest-branch]` from a
  checked-out `main` or `staging` branch. Requires `GH_TOKEN` with
  `actions:write`. Pass `--attest-branch` when the build needs to trust
  a non-`main` branch (see point 4 above — this is not optional for a
  `-testing` promotion).
- **Promote the latest successful candidate to a channel**:
  `deploy/nixos/scripts/promote-latest-candidate.sh
  <stable|beta|nightly>`, same `GH_TOKEN` requirement. This finds the
  latest successful `nixos-image.yml` run for the currently-checked-out
  commit and dispatches `release-promotion.yml`, which attests and
  publishes the channel pointer under the branch-qualified path above.

## R2 bucket layout

Everything under `artifacts/`, `attestations/`, `channels/`,
`documents/`, `releases/`, `revocations/` in `pocketcoder-images` is
live and schema-driven — don't delete anything under these without
first checking it isn't referenced by a currently-live channel pointer
(`curl https://images.relay.pocketcoder.org/v1/channels/<channel>.json`
for each of `stable`/`beta`/`nightly`/`nightly-testing`). Anything
found directly at the bucket root, outside those prefixes, is leftover
from a superseded pipeline generation — a one-time cleanup on
2026-08-17 removed 146 such objects (144GB) after verifying none of the
live channel pointers referenced any of them.

No automated retention/pruning policy exists yet — the bucket will
accumulate real storage over every build indefinitely (roughly
$0.015/GB-month past the 10GB free tier) until one is built. Not
designed yet; see `docs/testing/known-followups-2026-08-17.md` (local
notes, not committed).

## Debugging checklist

1. Is the Worker's *deployed* code actually current? `git log` on this
   directory doesn't tell you that — Workers don't auto-deploy (see
   `workers/README.md`). Redeploying is cheap and safe to try, but
   don't assume a code-skew fix worked without independently verifying
   the underlying R2 object/pointer actually changed.
2. Are you polling the branch-qualified path (`-testing` off `main`)?
   Check `resolver.go`'s `ChannelPath()` against what you're curling.
3. Was the candidate you're chasing built with `--attest-branch` if
   it's promoted onto a `-testing` channel? See point 4 above — this is
   the single most common cause of "resolved release does not match
   the expected digest" on a fresh box.
4. A 200 with stale-looking data is not the same bug as a 404. Check
   headers (`cache-control`, `etag`, `age`) before writing off a value
   as "the same broken data" — R2's eventual-consistency window and
   Cloudflare's edge cache are both real, both usually the actual
   explanation.
