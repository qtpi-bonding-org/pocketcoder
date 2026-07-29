# Linode Boot-Time Image Provisioning — Design

## Problem

The golden-path Aeroform test (real Linode provisioning, `flutter_aeroform`)
has never completed successfully. Root-caused across several real, live
debugging sessions (not guesses — each finding below was confirmed against
the actual deployed `image-relay` Worker and a real Linode account):

1. **`ctx.waitUntil()` has a hard ~30s budget for background work**
   (confirmed via Cloudflare's own docs and their AI assistant). The
   original code streamed the ~755MB NixOS image to Linode inside
   `ctx.waitUntil()` — nowhere near enough time, regardless of request body
   format. This alone explains the image sitting at
   `status=pending_upload, size=0MB` forever.
2. Moving the transfer to a **Cloudflare Queue consumer** (15 min budget,
   automatic retries) fixed the time-budget problem but surfaced a second,
   distinct failure: `Error: Network connection lost.`, thrown almost
   instantly (~1s) on every attempt, regardless of whether the request body
   was a raw `ReadableStream` with a manual `Content-Length` header or a
   `FixedLengthStream` (the Workers-native fixed-length-streaming
   primitive).
3. An Opus-level research pass (code review + targeted search across
   `cloudflare/workers-sdk` and `cloudflare/containers` GitHub issues, and
   Cloudflare community threads) found this is not a fixable one-line bug:
   **streaming a body of this size out of a Worker via `fetch()` is an
   under-documented, unreliable corner of the platform** with no known
   working reference implementation at this payload size. The standard
   mitigation (multipart/ranged upload) is unavailable because Linode's
   `POST /v4/images/upload` → `upload_to` URL is a single-shot,
   non-multipart presigned-style PUT.
4. Proven via a plain local Python script (bypassing the Worker entirely —
   full R2 object read into memory, then a single buffered `PUT`) that
   Linode's endpoint and our request shape are fine. The problem is
   specifically "stream a multi-hundred-MB body through a Worker's
   `fetch()`," not anything about Linode or our data.

**Conclusion: stop trying to push bytes through a Cloudflare Worker for
this payload size.** Move to a **pull-based** model: the Linode instance
downloads the image directly from R2 at boot time, with no Worker in the
data path at all.

## Non-goal: this is not "rip out the existing path"

`flutter_aeroform`'s current Custom-Image-upload path
(`LinodeAPIClient.findImageByLabel`/`triggerImageUpload`,
`ICloudProviderAPIClient`'s image-related methods,
`DeploymentService._ensureNixosImage`) stays as real, tested code — kept
for its option value, not deleted. One honesty correction from the first
draft of this spec: it is **not actually provider-portable code** — it
calls *our own* `image-relay` Worker's `/upload-image`, which is
Linode-specific glue that happens to be broken for Linode's real payload
size. A future non-Linode provider would reuse the *shape of the idea*
(push-based Custom Images is a real, common API pattern), essentially none
of the *code*. Kept anyway because deleting working-shaped code to save a
few hundred lines isn't a win, and the seam this design introduces
(`IInstanceProvisioningStrategy`) makes keeping it free.

**This design adds a second, additive provisioning path**, selected via
dependency injection (see "Strategy selection," not a user-facing/config
choice — more below on why that distinction matters) — not a replacement.

## Solution

### New abstraction: `IInstanceProvisioningStrategy`

A new interface, narrower than `ICloudProviderAPIClient`, owning exactly
the part of `DeploymentService.deploy()` that today is inlined as
`_ensureNixosImage()` + the `apiClient.createInstance(...)` call:

```dart
abstract class IInstanceProvisioningStrategy {
  /// Provisions a fresh instance that will boot into the target image.
  /// Returns once the instance exists and is either already booting the
  /// target image, or (for pull-based strategies) has finished writing
  /// its target disk and is booting it -- NOT full boot-to-cert-ready
  /// (DeploymentService.monitorDeployment's polling loop, unchanged,
  /// still owns that).
  Future<CloudInstance> provisionInstance({
    required String accessToken,
    required DeploymentConfig config,
    required String userData, // pre-built by config.toUserData(...)
  });
}
```

`DeploymentService` takes this via constructor injection (same pattern as
`ICertificateManager`/`IPasswordGenerator`/etc. today) instead of calling
`_ensureNixosImage`/`createInstance` inline. `deploy()`'s surrounding
structure (validate config, generate admin password + SSH keypair, resolve
access token, store credentials, return `DeploymentResult`) is unchanged.

### Strategy selection: DI, not `DeploymentConfig`

The first draft of this spec put a strategy enum on `DeploymentConfig`.
Reconsidered — which provisioning mechanism a provider uses is not user
deployment intent, it's an implementation detail, and putting it in config
makes a **known-broken-for-Linode code path reachable in production by
misconfiguration**. Instead: `external_module.dart`'s DI wiring registers
`BootTimePullProvisioningStrategy` as the sole
`@LazySingleton(as: IInstanceProvisioningStrategy)` for Linode. Tests that
want `CustomImageProvisioningStrategy` construct it directly via
constructor injection — no flag needed, that's what DI is for. If a manual
override is ever wanted for debugging, it's a `--dart-define`/debug-only
switch, never a `DeploymentConfig` field.

### Strategy 1 (kept, unchanged): `CustomImageProvisioningStrategy`

Wraps exactly today's logic, verbatim:
`findImageByLabel` → if absent, `triggerImageUpload` (relay) → poll
`findImageByLabel` until available → `apiClient.createInstance(image:
imageId, metadata: {user_data: userData})`. Depends only on the existing
`ICloudProviderAPIClient` — no interface changes, no behavior changes.
Fully covered by existing tests (`deployment_service_test.dart`,
`linode_api_client_test.dart`'s `findImageByLabel` group, etc.) — none of
that coverage is touched by this design.

**Not fixing this path's known bugs as part of this work** (the earlier
draft proposed fixing `streamImageToLinode`'s unreachable `pipeDone` await
and the queue's spent-URL-on-retry bug "since they're cheap" — reconsidered:
this path isn't the default going forward and is known-unreliable for its
only real use case; spending effort polishing it is exactly the kind of
scope creep this codebase avoids elsewhere). Instead: **disable the queue
consumer binding** in `workers/image-relay/wrangler.toml` so a stale
enqueued message can't retry-loop against a single-use, already-dead
`upload_to` URL and generate pointless billed activity. Leave a code
comment recording the diagnosis (both bugs, and why they're deliberately
unfixed) so nobody "cleans this up" without the context.

### Strategy 2 (new): `BootTimePullProvisioningStrategy`

Depends on a **capability-level**, genuinely cross-provider interface —
revised from this spec's first draft, which modeled Linode's own
disks/configs *mechanism* (five methods: create installer, create target
volume, wait, switch-and-boot, delete installer) and called that
"cross-provider." It wasn't: DigitalOcean **cannot boot a Droplet from an
attached Block Storage volume at all** (Droplets only ever boot from their
own root disk), and Hetzner has no custom-images concept — the canonical
route there is boot the rescue system and `dd` onto the server's *own*
root disk, no second volume, ever. Both providers would need three of the
five methods to be lying no-op stubs under the old interface. Worse: it
buried DigitalOcean's actually-simpler native answer — their Custom Images
API accepts a URL and pulls the image itself, one call, no installer dance
needed at all.

The contract that's actually shared across providers is much smaller:

```dart
/// Contract for "pull-based" instance provisioning: get a target image
/// (identified by a URL, sha256, and uncompressed size) running as a
/// booted instance's root filesystem, by whatever mechanism this
/// provider supports -- a native pull-from-URL API (DigitalOcean), a
/// rescue-boot-and-dd sequence (Hetzner), an installer-instance-plus-
/// volume-swap sequence (Linode -- see LinodeBootTimeInstaller below), or
/// anything else. Callers don't need to know which.
abstract class IUrlPullProvisioningApi {
  Future<CloudInstance> provisionFromImageUrl({
    required String accessToken,
    required DeploymentConfig config,
    required String userData,
    required String imageUrl,
    required String imageSha256,
    required int uncompressedBytes,
  });
}
```

`BootTimePullProvisioningStrategy` depends only on this — genuinely zero
Linode-specific code in it; it fetches `{imageUrl, imageSha256,
uncompressedBytes}` from the Worker's `/image-manifest` (below) and calls
`provisionFromImageUrl(...)`.

`LinodeAPIClient` implements `IUrlPullProvisioningApi` (alongside its
existing `ICloudProviderAPIClient` implementation — one class, two
interfaces, no conflict) by internally driving a **Linode-specific,
non-portable helper** — named plainly so nobody mistakes it for a
portability boundary:

```dart
/// Linode-only. Not part of any cross-provider contract -- disks and
/// config profiles are Linode API primitives. Used exclusively by
/// LinodeAPIClient's IUrlPullProvisioningApi implementation.
class LinodeBootTimeInstaller { ... }
```

#### The corrected Linode sequence

The first draft's 7 steps were missing the config-profile/boot step
entirely for the installer (disks aren't attached to anything just by
being created — Linode requires an explicit device-slot mapping in a
config profile, and creating one is not implied by creating disks). Full
corrected sequence:

1. `POST /linode/instances` — no `image` field, `booted: false`, no
   `authorized_keys`/`root_pass` at this step (added at disk-creation time
   below, since disks don't exist yet). **Confirmed live against the real
   API (2026-07-29): Linode accepts `metadata.user_data` with no `image`
   field at all** (`"has_user_data": true, "image": null"` in the
   response). This confirms *acceptance* — it does **not** yet confirm
   *delivery* (see "Pre-implementation verification," below — this is the
   most important open item in this whole design, and the earlier draft
   incorrectly presented it as fully resolved).
2. `POST .../disks` — installer disk (~2.5GB), `image: "linode/debian12"`,
   `authorized_keys: [rootSshKey]` **only if D3's mitigation (below) makes
   this safe; otherwise a throwaway random `root_pass` instead of the
   deployment's real key** — `stackscript_id` (our published StackScript,
   see below), `stackscript_data: {IMAGE_URL, IMAGE_SHA256}`.
3. `POST .../disks` — target disk, `filesystem: "raw"`, sized to `plan
   disk − 2.5GB − slack`, floor 8GB (comfortably above the ~4.7GB
   uncompressed image; the plan whitelist in `validation_service.dart`
   only allows `g6-standard-*`, min 50GB disk, so this floor is never
   actually reachable in practice — assert it rather than silently clamp,
   so a future plan-whitelist change fails loudly instead of silently
   under-provisioning).
4. `POST .../configs` — **installer boot profile**: `devices: {sda:
   {disk_id: installerDiskId}, sdb: {disk_id: targetDiskId}}`,
   `kernel: "linode/grub2"` (not `linode/direct-disk` — the target image
   installs its own GRUB with `device = "nodev"` + `forceInstall`, so
   there's no MBR for direct-disk booting to find; this needs to be a
   comment in the implementation so nobody "corrects" it later),
   `root_device: "/dev/sda"`, and **all helpers explicitly disabled**:
   `helpers: {distro: false, modules_dep: false, network: false,
   updatedb_disabled: false, devtmpfs_automount: false}` (Linode's own
   custom-distribution guidance: helpers rewrite `/etc/fstab`,
   `/etc/hosts`, `/etc/resolv.conf`, inittab consoles — fine for a stock
   Debian installer disk, actually, since it *is* a normal Debian system
   at this point; disabling them here is about the config profile being
   reused later, see step 7).
5. `POST .../boot` with that config's id.
6. **Wait for a `running` → `offline` transition**, not a bare `status ==
   "offline"` check — the instance is created `booted: false`, i.e.
   already `offline` before anything runs, so a naive equality check
   races and can pass instantly. Track "have we observed `running`"
   before accepting `offline` as completion. The StackScript's last line
   is `shutdown -h now`, so this transition *is* the "disk write
   finished" signal. Guarded by a hard timeout (see "Failure handling,"
   below, for what happens on timeout).
7. **Delete the installer disk now** (`DELETE .../disks/{installerDiskId}`),
   before creating the final config — not after, as the first draft
   proposed. Reconsidered: Linode's disk-delete likely requires the
   Linode to be powered off (needs live verification, but the instance
   already is powered off here, which is exactly why this ordering is
   safer), and deleting *after* the final boot would mean deleting a disk
   out from under a running, serving instance's sibling disk-slot
   bookkeeping — avoid entirely by never being in that state. Trade-off,
   stated plainly: this gives up "installer disk as a recovery path if
   the target disk is bad" — acceptable, since the actual recovery path
   for a bad deployment is re-running provisioning from scratch (which
   the app already supports), not resurrecting a half-written disk.
8. `POST .../configs` — **final boot profile**: `devices: {sda: {disk_id:
   targetDiskId}}`, `kernel: "linode/grub2"`, `root_device: "/dev/sda"`,
   same disabled-helpers set as step 4 (the target is NixOS with a mostly
   read-only `/etc` — helpers rewriting boot-time files would fight or
   corrupt it).
9. `POST .../boot` with the final config's id. From here,
   `DeploymentService.monitorDeployment`/`_pollForCertificate` (unchanged)
   takes over exactly as it does for the existing path.

`swap_size`: Linode normally provisions a 512MB swap disk automatically;
this sequence's explicit disk list doesn't include one. Decision: no swap
disk (`swap_size: 0` equivalent) — the target NixOS system doesn't
currently configure swap either, and adding it is out of scope here.
Stated explicitly so the disk-size accounting above isn't quietly wrong by
512MB later.

#### Pre-implementation verification (do this before writing any Dart)

The single highest-value unknown in this entire design, understated in
the first draft: confirming Linode's API *accepts* `metadata.user_data`
with no `image` field (already done, 2026-07-29) proves nothing about
whether `http://169.254.169.254/v1/user-data` actually *serves* it once
the target instance boots. `bootstrap.nix` fails closed on empty
user-data, so if this doesn't work, every deployment fails silently at
first boot. Also verify the base64 layering while at it: the Linode API
requires `user_data` to already be base64-encoded on the way in;
`DeploymentConfig.toUserData` already does this; `bootstrap.nix` does
exactly one `base64 -d`. If Linode's metadata endpoint serves the
*decoded* value instead of the encoded one, that single `base64 -d` fails
and every deployment dies the same way. Both of these are cheap to check
with one real instance (boot it with `image: linode/debian12` set this
time, so it actually runs something that can curl the metadata endpoint
and print what it got) before any of the rest of this design is worth
implementing.

### The boot script (Linode implementation: a StackScript, published
once, centrally — see root `CLAUDE.md`'s central-registration principle)

Per this repo's deployment model, anything requiring "a human to register
something once" happens centrally, not per-user — same pattern as the
MCP OAuth Worker holding the shared GitHub OAuth App. Published **once**,
publicly, from our own Linode account; end users never see or interact
with this registration step.

The first draft's version had two real bugs, both corrected here:

- **Checksum race**: `tee >(sha256sum > /tmp/sum)` uses process
  substitution, which bash does not `wait` on — the script could reach
  the `grep` check before `sha256sum` has flushed its output, producing a
  flaky **false** "CHECKSUM MISMATCH" on a perfectly good download. Fixed
  with an explicit FIFO the script does wait on.
- **Retry-into-corruption**: `curl --retry 5 --retry-all-errors` piped
  directly into a running `dd` is actively dangerous — a retry restarts
  the HTTP transfer from byte 0, but `dd` has already consumed and
  written the earlier bytes, so the retried stream gets appended onto
  already-written data instead of replacing it. (This happens to be
  caught by `gunzip`'s own CRC32 check today, but relying on that as the
  *only* thing standing between a mid-stream retry and a corrupt boot
  disk is not a design, it's luck.) Fixed by retrying the **whole
  pipeline** from scratch in a bash loop instead of letting `curl` retry
  internally mid-stream.

```bash
#!/bin/bash
# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
set -euo pipefail

command -v curl >/dev/null || { apt-get update && apt-get install -y curl; }

TARGET_BYTES=$(blockdev --getsize64 /dev/sdb)
# Sanity check before writing anything -- fail loud and early rather than
# discover an undersized target disk mid-transfer.
[ "$TARGET_BYTES" -gt 0 ] || { echo "FATAL: /dev/sdb not found"; exit 1; }

attempt=0
until [ "$attempt" -ge 3 ]; do
  attempt=$((attempt + 1))
  echo "Attempt $attempt..."
  mkfifo /tmp/sumpipe
  sha256sum < /tmp/sumpipe > /tmp/sum &
  SUMPID=$!

  if curl -fsSL --retry 0 "$IMAGE_URL" \
      | tee /tmp/sumpipe \
      | gunzip \
      | dd of=/dev/sdb bs=16M conv=fsync status=progress; then
    wait "$SUMPID"
    rm -f /tmp/sumpipe
    if printf '%s  -\n' "$IMAGE_SHA256" | sha256sum -c - < /tmp/sum >/dev/null 2>&1 \
        || grep -qx "$IMAGE_SHA256" /tmp/sum; then
      sync
      shutdown -h now
      exit 0
    fi
    echo "Checksum mismatch on attempt $attempt"
  else
    wait "$SUMPID" 2>/dev/null || true
    rm -f /tmp/sumpipe
    echo "Transfer failed on attempt $attempt"
  fi
done

echo "FATAL: all attempts failed -- leaving instance online for inspection"
exit 1
```

(The exact `sha256sum -c` invocation above needs a real dry run before
being treated as final — the point to preserve is: exact comparison via
`sha256sum -c`, not a substring `grep`, and reading from a file that's
been `wait`-ed on, not a process substitution.) Fails closed on repeated
failure — does **not** shut down, leaving the instance online so the
app's poll times out loudly instead of booting a corrupt disk (see
"Failure handling" for what the app does with that).

Needs only a few MB of RAM regardless of image size (streaming
`curl | gunzip | dd`, never buffered) — this is what makes the cheapest
Linode plan (`g6-standard-1`, 2GB RAM) still work, unlike a
download-into-RAM-then-swap approach, which would need RAM ≥ the ~4.7GB
uncompressed image size.

### NixOS image change required (this is now in scope, not out of scope)

The first draft claimed zero image changes were needed. Wrong: `dd`-ing
the image onto a bigger raw disk does not grow the filesystem to fill it.
`deploy/nixos/configuration.nix` currently has:

```nix
fileSystems."/" = { device = "/dev/sda"; fsType = "ext4"; };
```

with no `autoResize`, and `deploy/nixos/flake.nix` builds with no
`diskSize` set (defaults to `auto` + 512MB slack) — so the filesystem
written to the target disk is only ever ~4.7GB, regardless of the disk's
real size, and `bootstrap.nix`'s first boot (which runs `docker compose
up -d`, building `pocketbase` from source) needs real room to work in.
This is a **pre-existing latent defect**, not new to this design — the
old Custom-Image path likely masked it, since Linode's own image-deploy
path does its own resize when creating an instance from a Custom Image
(an implicit step this design's raw `dd` doesn't get for free). Fix:

```nix
fileSystems."/".autoResize = true;
```

One line. Verify with a real image build afterward that the filesystem
actually grows to the target disk's real size on first boot (NixOS's
`autoResize` runs `resize2fs`/`btrfs filesystem resize` as part of the
generated `fileSystems` activation script — confirm this fires before
`bootstrap.nix`'s `docker compose up -d` needs the space, not after).

### Worker changes (additive only)

`workers/image-relay` keeps everything it has today (`/upload-image`,
`/image-status`, the Queue binding present-but-disabled per "Strategy 1"
above) — the existing path still needs the code to exist even though its
queue consumer is turned off. One new endpoint is added:

```
GET /image-manifest
→ {"url": "https://<r2-custom-domain>/pocketcoder-nixos-<gitsha>.img.gz",
   "sha256": "...", "uncompressedBytes": 4930000000}
```

Served from a **Cloudflare custom domain in front of the R2 bucket**, not
a raw `r2.dev` URL — R2 egress is free either way, but a custom domain
gets edge caching and is rate-limitable, which matters for an
unauthenticated public 755MB object (cost-amplification/abuse
consideration, not a secrecy one — see Security, D5). The manifest
endpoint is a versioning indirection point: `flutter_aeroform` never
hardcodes an R2 URL or a specific image version, so rotating to a newly
built image needs zero app changes — it just needs CI to update what the
manifest points at (see "CI prerequisite," below).

### CI prerequisite (blocking, not a follow-up)

`.github/workflows/nixos-image.yml` currently uploads to the **mutable**
key `pocketcoder-nixos-latest.img.gz` and computes neither a sha256 nor
an uncompressed size. Both the manifest endpoint and the StackScript's
checksum gate depend on data that doesn't exist yet, and a mutable
`-latest` key means a CI run that happens to land mid-deployment can swap
the object out from under an in-flight `curl`, corrupting that
deployment. Required, before any of the rest of this design can work:

1. CI computes `sha256sum` and the **uncompressed** byte size (`gunzip -l`
   or decompress-and-measure) of the built image as part of the existing
   build step.
2. CI publishes to an **immutable, versioned key** —
   `pocketcoder-nixos-<git-sha>.img.gz` — instead of (or in addition to,
   for now) the mutable `-latest` key.
3. The Worker's `/image-manifest` response is updated (a small
   `PUT`/`env.IMAGES.put` of a JSON object, from the same CI run) to
   point at the new versioned key + its real sha256/size, atomically with
   the image upload finishing — never partially updated.

### Failure handling and lifecycle

Not addressed at all in the first draft — required:

- **Timeout on `waitForInstallerCompletion`**: an instance stuck
  `running` (installer script hung or looping in its own retry-3 failure
  path) bills forever if left alone. On timeout, the strategy deletes the
  instance and throws a diagnosable error — it does not leave it running
  "for inspection" (that's the *script's* fail-closed behavior for a
  human debugging a specific failed run, not the app's default
  unattended behavior).
- **Partial-failure teardown**: every step between "instance created" and
  "final boot" leaves a billable half-built resource if the process
  dies (app crash, network drop, user backgrounds the app on mobile).
  Wrap the whole sequence in a single try/catch that deletes the instance
  on any exception, rather than leaving cleanup to chance.
- **Orphan reaping**: a `list-and-delete-by-label-prefix` sweep (the same
  `pocketcoder`-prefix convention `DeploymentService._pocketCoderLabelPrefix`
  already uses) as a periodic or on-demand safety net, independent of the
  in-line teardown above. This depends on fixing a real pre-existing bug:
  `LinodeAPIClient.listInstances`'s `labelFilter` parameter is computed
  via `uri.replace(...)` but the result is discarded (`Uri.replace`
  returns a new `Uri`, doesn't mutate in place) — the filter is silently
  a no-op today. Fix as part of this work, since orphan-reaping depends
  on it actually filtering.
- **Polling backoff cap**: `_pollForCertificate`'s existing exponential
  backoff (`15s * 2^(attempts-1)`, 20 attempts) has no cap — attempt 20
  waits ~91 hours. This design adds ~5-8 minutes of real wall-clock time
  before NixOS even starts booting (R2→Linode transfer + decompress+`dd`
  of ~4.7GB + two boot cycles), on top of whatever this pre-existing
  backoff was already going to do. Cap the backoff (e.g. max 5 minutes
  per attempt) and state the expected end-to-end deployment time budget
  once real numbers exist from testing.

## Security

- **Confirmed true, and verified by direct audit (not assumed):** the
  NixOS image itself contains no user secrets — no SSH host keys
  (generated fresh on first boot), no `authorized_keys`, no root password
  (`PasswordAuthentication = false`, `PermitRootLogin =
  "prohibit-password"`, no hashed password anywhere in the config), no
  TLS material (Caddy obtains certs at runtime), no tokens. Everything
  either arrives via `user_data` or is generated on-box from
  `/dev/urandom`. Making the image object itself publicly fetchable is a
  sound call on its own.
- **New consideration, not in the first draft**: public distribution of
  the image is a *discoverability* boost for an existing weak point —
  `bootstrap.nix` hardcodes a repo URL and a **non-default branch, with
  no commit pin and no signature verification**
  (`POCKETCODER_REPO`/`POCKETCODER_REF`, `git clone --depth 1 --branch`).
  Every deployed box runs whatever HEAD of that branch happens to be at
  boot time, and now anyone can pull the image and read that pin trivially.
  Not a new secret exposure, but worth stating plainly rather than
  asserting "no new exposure surface" — filing a commit/tag-pin fix as a
  follow-up (out of scope for this design specifically).
- **Real finding, needs a mitigation decision**: the installer disk boots
  stock Debian, which ships cloud-init. Cloud-init on that disk will see
  the instance-level `metadata.user_data` (set at instance-creation time,
  step 1) — the same blob containing `POCKETBASE_ADMIN_PASSWORD` in
  cleartext — fail to parse it as valid cloud-config, and may log it.
  Combined with `authorized_keys: [rootSshKey]` on that same installer
  disk (step 2), anyone who can reach the installer while it's up could
  read the deployment's real admin password from its logs. Two possible
  mitigations, cheapest first: (a) don't set the deployment's real
  `user_data` until *after* the installer completes (a separate
  `PUT`/update call before the final boot, if Linode's API supports
  updating instance metadata post-creation — needs verification); or (b)
  use a throwaway random `root_pass` on the installer disk instead of the
  deployment's real SSH key (the disk-create API only requires *one* auth
  mechanism), relying on Lish for installer-debugging access instead of
  SSH, so a compromised installer never has the real deployment's key
  either way. Pick one before implementing step 2 — the sequence above is
  written to accommodate whichever is chosen.
- Installer SSH/network exposure window (~5-8 min per deployment, stock
  Debian, whichever auth mechanism D3 above lands on): low risk, cheap to
  reduce further — a Cloud Firewall (deny-all inbound except the
  mechanism actually used) on the installer costs nothing and is worth
  adding.
- Serving the image from a Cloudflare custom domain rather than a raw
  `r2.dev` URL (already stated under Worker changes) is partly a security/
  cost consideration: an unauthenticated 755MB object is a real
  cost-amplification vector for R2 Class B operations even though egress
  itself is free.
- **Pre-existing, unrelated, fix while touching this code**:
  `GET /image-status?linodeToken=...` puts a live Linode API token in a
  URL query string, which lands in Cloudflare's own request logs. Its
  sibling `POST /upload-image` correctly puts the token in the request
  body. Fix `/image-status` to match (`POST` or a header) regardless of
  which provisioning path ships.

## Testing

- New unit tests for `BootTimePullProvisioningStrategy` (mocked
  `IUrlPullProvisioningApi` — genuinely provider-agnostic; no Linode
  specifics anywhere in this test file).
- New unit tests for `LinodeAPIClient`'s `IUrlPullProvisioningApi`
  implementation and its internal `LinodeBootTimeInstaller` helper
  (mirroring `linode_api_client_test.dart`'s existing pattern — request
  shape assertions against a mocked `http.Client`), covering: the full
  9-step sequence in order, the `running`→`offline` transition-tracking
  logic specifically (not just a status-equality check), the
  installer-disk-deleted-before-final-boot ordering, and timeout/
  teardown behavior.
- `CustomImageProvisioningStrategy`'s tests are the existing
  `deployment_service_test.dart`/`linode_api_client_test.dart` coverage,
  extracted into the new class but otherwise unchanged.
- `LinodeAPIClient.listInstances`'s label-filter fix gets a real
  regression test (the bug — filter silently discarded — had no coverage
  that would have caught it).
- `test/integration/golden_path_provision_test.dart` gets rewritten for
  the new 9-step sequence (this is the real, live proof — same
  `AEROFORM_LIVE_TEST=1` gating, same real-money/real-instance caveats,
  same auto-teardown requirement as today). Add real-money assertions for
  the new failure paths too: an intentionally-corrupted image URL should
  result in a deleted instance and a clear error, not an orphaned running
  box.

## Known unrelated bugs (fix alongside this work)

- `AppConfig.kImageRelayUrl` defaults to
  `https://pocketcoder-image-relay.workers.dev`, but the actually-deployed
  Worker is `https://pocketcoder-image-relay.gp-c53.workers.dev` — any
  build without an explicit `--dart-define=IMAGE_RELAY_URL` override hits
  a nonexistent host. Fix the default, or better, fail loudly at build/
  boot time on a missing define rather than silently defaulting to a URL
  that can rot again unnoticed.
- `DeploymentConfig.toMetadata()` is dead code — `deploy()` only ever
  passes `user_data` to `createInstance`/the new provisioning strategy,
  so `linodeToken` (the other field `toMetadata()` builds) never actually
  reaches an instance today. Either delete `toMetadata()` or wire it in;
  leaving it as an untested, unused trap isn't a third option.
- `LinodeAPIClient.findImageByLabel` only reads page 1 of
  `/images?page_size=100` — pre-existing, only affects the (now
  non-default) Custom-Image path; leave a comment rather than fix, since
  that path isn't getting further investment per "Strategy 1" above.

## Out of scope

- Removing `/upload-image`/`/image-status`/the Queue's *code* from
  `image-relay` — kept for `CustomImageProvisioningStrategy`. (The queue
  *consumer binding* is disabled, per Strategy 1 — code stays, active
  processing doesn't.)
- Committing to a specific mitigation for the installer-disk credential-
  leak finding (Security, D3) beyond documenting the two real options —
  pick one during implementation, before step 2 of the sequence is
  written.
- Pinning `bootstrap.nix`'s `POCKETCODER_REPO`/`POCKETCODER_REF` to a
  commit/tag with signature verification (Security, second bullet) — real
  finding, real follow-up, not blocking this design.
- **Actually implementing a second `IUrlPullProvisioningApi` provider.**
  The interface is deliberately shaped to be implementable by
  DigitalOcean (trivially — their native pull-from-URL Custom Images API
  fits this contract almost exactly), Hetzner (via rescue+`dd`), AWS/GCP
  (via a boot-disk-swap sequence broadly similar to Linode's, though the
  exact API call sequence for either was not verified in this design pass
  and should be checked fresh when actually implementing one) — but only
  `LinodeAPIClient` implements it here.
- `ICloudProviderAPIClient` itself is untouched by this design —
  `IUrlPullProvisioningApi` is a new, separate interface a client can
  additionally implement.
- Adding a swap disk to the Linode disk layout (stated as a deliberate
  decision above, not an oversight — matches the target NixOS config,
  which doesn't configure swap either).
