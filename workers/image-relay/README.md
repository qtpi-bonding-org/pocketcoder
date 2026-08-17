# image-relay

Serves at `images.relay.pocketcoder.org` (and `images.pocketcoder.org` —
same Worker, older custom-domain route, still attached). Backed by a
single R2 bucket (`pocketcoder-images`, binding `IMAGES`). This Worker
**never holds provider credentials and never writes to R2** — it is a
read-only relay in front of objects CI/promotion tooling writes
directly. All routes are defined in `src/index.ts`.

There are **two route groups** living behind this one Worker: one live
pipeline (§1) and one dead leftover (§2) that happens to still return
200s. Conflating them wastes real time — a live debugging session did
this twice: once chasing a "broken image-manifest pipeline" that was
actually just the wrong channel pointer, and once concluding §2 was a
"deliberate seam" worth preserving before anyone had actually checked
whether real code calls it (it doesn't — see §2).

## 1. Release channel (OTA updates) — the live, actively-developed one

Routes: `/v1/channels/{stable,beta,nightly}[-testing].json`,
`/v1/releases/<sha256>.json`, `/v1/attestations/...`,
`/v1/artifacts/<sha256>.{tar.gz,img.gz}`, `/v1/documents/...`,
`/v1/revocations/releases.json`.

This is what a **running** box's `pocketcoder-release` binary polls to
decide "is there a newer release I should update to." It's entirely
digest-addressed and GitHub-attested (sigstore). The full write path:

1. `.github/workflows/nixos-image.yml` builds + attests an immutable
   candidate, publishes it under `/v1/releases/<digest>.json` and
   friends (`deploy/ci/publish-attested-candidate.sh`).
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
4. `deploy/ci/verify-candidate-published.sh` gates the pointer publish
   on every referenced object actually being publicly fetchable first
   (an R2 eventual-consistency guard, up to ~10 min) — a stale-looking
   pointer for the first several minutes after a promotion run
   "succeeds" is expected, not a bug.

## 2. `/image-manifest`, `/release-manifest` — dead, confirmed by tracing real callers

Routes: `/image-manifest` (reads R2 key `image-manifest.json`),
`/release-manifest` (reads R2 key `release-manifest.json`). Both
return 200 with real-looking JSON (a NixOS `.img.gz` + docker-images
tarball pointer, `sourceCommit`), which made them *look* load-bearing
during a live debugging session — they aren't. **Verified by grepping
every call site across `pocketcoder`, `pocketcoder-pro`, and
`flutter_aeroform`: zero callers.**
`flutter_aeroform/lib/domain/models/app_config.dart`'s
`kImageManifestPath` constant is declared and never referenced again
anywhere in either the library or the real app.

The raw boot image is **not missing automation** — it already
publishes automatically, just through §1's pipeline instead of this
one: `nixos-image.yml`'s `candidate` job embeds the NixOS image's
URL/sha256 as a `nixosImage` field inside the same
`/v1/releases/<digest>.json` manifest it publishes for every build.
Confirmed live in `pocketcoder-pro`'s
`config_adapter.dart` (`nixosArtifact = release.nixos.delivery.artifact`,
around line 140): the real app reads the boot image straight out of
the resolved release object from §1, then hands it to a Linode
StackScript (published once via `deploy/nixos/scripts/publish-stackscript.sh`)
that pulls it directly onto a raw disk at provision time. No manual
step, no gap, no second pipeline actually in use.

`/image-manifest`/`/release-manifest` are **leftovers of an older,
already-replaced provisioning strategy** (streaming an image into a
Linode *custom image* via `/upload-image` + a queue consumer, instead
of today's boot-time StackScript pull) — see `b95978012`'s commit
message. Safe to treat as dead; whatever content happens to still be
sitting in those two R2 keys is stale and unread by anything real.

**Also dead, same era, do not trust without checking first:**
- `flutter_aeroform/scripts/trigger-image-upload.sh` and
  `debug-image-upload.sh` POST to `/upload-image`, which 404s —
  the route and its queue consumer were disabled in `b95978012`
  ("now-non-default upload path") and the route itself is gone from
  current `src/index.ts`.
- `flutter_aeroform/test/integration/golden_path_provision_test.dart`'s
  `_standardLinuxAppBootstrap()` cloud-init (around line 267) hardcodes
  `release_url=https://images.pocketcoder.org/release-manifest.json` —
  same dead pipeline. The *real* shipped `standard_linux_bootstrap.sh`
  asset uses `resolve-signed-release.sh` against §1 instead. This test
  fixture has drifted from production and is worth reconciling.

## Updating everything

- **Redeploy the Worker itself** (after a code change to
  `src/index.ts`/`wrangler.toml`): `cd workers/image-relay && npx
  wrangler deploy`. Requires Cloudflare API credentials in the
  environment. Not automatic on push — see `workers/README.md`.
- **Build a new NixOS release candidate**:
  `deploy/nixos/scripts/trigger-ci-build.sh [--attest-branch]` from a
  checked-out `main` or `staging` branch. Requires `GH_TOKEN` with
  `actions:write`. Pass `--attest-branch` only when you want the built
  image to trust attestations from the current non-`main` branch
  instead of `main` (see the flag's own comment in the script).
- **Promote the latest successful candidate to a channel**:
  `deploy/nixos/scripts/promote-latest-candidate.sh
  <stable|beta|nightly>`, same `GH_TOKEN` requirement. This finds the
  latest successful `nixos-image.yml` run for the currently-checked-out
  commit and dispatches `release-promotion.yml`, which attests and
  publishes the channel pointer under §1's branch-qualified path.
- There is no separate "publish the raw boot image" step — it's
  already covered by the two steps above. §2's routes need nothing.

## Debugging checklist

1. Which pipeline — release channel (§1) or raw boot image (§2)? They
   share a Worker but nothing else.
2. For §1: are you polling the branch-qualified path (`-testing` off
   `main`)? Check `resolver.go`'s `ChannelPath()` against what you're
   curling.
3. Is the Worker's *deployed* code actually current? `git log` on this
   directory doesn't tell you that — Workers don't auto-deploy (see
   `workers/README.md`). Redeploying is cheap and safe to try, but
   don't assume a code-skew fix worked without independently verifying
   the underlying R2 object/pointer actually changed.
4. A 200 with stale-looking data is not the same bug as a 404. Check
   headers (`cache-control`, `etag`) before writing off a value as
   "the same broken data."
