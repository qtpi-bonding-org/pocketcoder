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
own root disk). Both providers would need three of the five methods to be
lying no-op stubs under the old interface. Worse: it buried DigitalOcean's
actually-simpler native answer — **DigitalOcean's Custom Images API
(`POST /v2/images`) takes a URL directly** (gzip/bzip2-compressed
raw/qcow2/vhdx/vdi/vmdk, under 100GB decompressed — our existing `.img.gz`
artifact is usable as-is) and pulls/imports the image itself, one call, no
installer dance needed at all; a DO implementation of
`IUrlPullProvisioningApi` would ignore `imageSha256`/`uncompressedBytes`
(DO doesn't take either) and need one extra provider-specific value (a
`distribution` string) supplied some other way, but otherwise fits this
contract directly.

Hetzner is a weaker fit than an earlier pass of this spec claimed, worth
being honest about rather than citing as a clean third example: Hetzner
Cloud has no image-import-from-URL API at all, and its rescue-mode API
only *boots* the rescue system and hands back a root password — there's
no API-driven command execution, so the real-world flow is "SSH into
rescue and run `dd` by hand." That's compatible with this interface in
principle (an SSH executor would live inside a Hetzner implementation's
constructor, not leak into the method signature), but it's not
implementable *in this project* without a new dependency this repo
deliberately doesn't carry — `flutter_aeroform`'s only SSH-related package
is key serialization (`openssh_ed25519`), no SSH client, and root
`CLAUDE.md` states Aeroform provisions with "no SSH step at all." A future
Hetzner implementation is possible, just not free the way DigitalOcean's
would be.

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

**Linode's disk create/delete are asynchronous** — a just-created disk
comes back `status: "not ready"` and the Linode is held busy until the
event completes; issuing the next call too soon 400s with `Linode busy`
(documented Linode behavior, not speculative). Every step below that
follows a disk create or delete is preceded by a poll-until-ready/poll-
until-gone wait, and every API call in this sequence is wrapped in a
bounded retry specifically for `400 Linode busy` (a handful of retries
with a short fixed delay — this is a normal, expected transient state on
every run, not an error condition).

1. `POST /linode/instances` — no `image` field, `booted: false`, no
   `authorized_keys`/`root_pass` at this step (added at disk-creation time
   below, since disks don't exist yet). **Confirmed live against the real
   API (2026-07-29): Linode accepts `metadata.user_data` with no `image`
   field at all** (`"has_user_data": true, "image": null"` in the
   response). This confirms *acceptance* — it does **not** yet confirm
   *delivery* (see "Pre-implementation verification," below — this is the
   most important open item in this whole design, and the earlier draft
   incorrectly presented it as fully resolved).
2. Fetch the plan's real disk size via `GET /linode/types/{type}` (not
   hardcoded — `LinodeAPIClient` has no method for this today; add one).
3. `POST .../disks` — installer disk (~2.5GB), `image: "linode/debian12"`,
   `authorized_keys: [rootSshKey]` **only if D3's mitigation (below) makes
   this safe; otherwise a throwaway random `root_pass` instead of the
   deployment's real key** — `stackscript_id` (our published StackScript,
   see below), `stackscript_data: {IMAGE_URL, IMAGE_SHA256,
   IMAGE_UNCOMPRESSED_BYTES}`. **Wait for this disk's `status: "ready"`**
   before continuing.
4. `POST .../disks` — target disk, `filesystem: "raw"`, sized to `plan
   disk (from step 2) − 2.5GB − slack`, floor 8GB (comfortably above the
   ~4.7GB uncompressed image; the plan whitelist in `validation_service.dart`
   only allows `g6-standard-*`, min 50GB disk, so this floor is never
   actually reachable in practice — assert it rather than silently clamp,
   so a future plan-whitelist change fails loudly instead of silently
   under-provisioning). **Wait for `status: "ready"`.**
5. `POST .../configs` — **installer boot profile**: `devices: {sda:
   {disk_id: installerDiskId}, sdb: {disk_id: targetDiskId}}`,
   `kernel: "linode/grub2"` (not `linode/direct-disk` — the target image
   installs its own GRUB with `device = "nodev"` + `forceInstall`, so
   there's no MBR for direct-disk booting to find; this needs to be a
   comment in the implementation so nobody "corrects" it later),
   `root_device: "/dev/sda"`, and **helpers left at their defaults** —
   *not* disabled, unlike the final profile below. This is a live stock
   Debian system with no guarantee its own boot-time expectations
   (network config, `/etc/fstab`, etc.) survive helpers being turned off
   the way NixOS's do; only the final (NixOS) profile in step 9 disables
   them.
6. `POST .../boot` with that config's **id passed explicitly** (Linode's
   "last booted config" default becomes ambiguous once a second profile
   exists later — always pass `config_id` on every boot call in this
   sequence, never rely on the default).
7. **Wait for a `running` → `offline` transition**, not a bare `status ==
   "offline"` check — the instance is created `booted: false`, i.e.
   already `offline` before anything runs, so a naive equality check
   races and can pass instantly. Track "have we observed `running`"
   before accepting `offline` as completion. The StackScript's last line
   is a poweroff, so this transition *is* the "disk write finished"
   signal. Guarded by a hard timeout (see "Failure handling," below, for
   what happens on timeout).
8. **Delete the installer disk now** (`DELETE .../disks/{installerDiskId}`)
   and the installer config profile (`DELETE .../configs/{installerConfigId}`
   — otherwise every box carries a permanently dangling profile pointing
   at a disk that no longer exists), before creating the final config —
   not after, as an earlier draft proposed. Deleting a disk a config
   profile still references is fine (Linode clears the device slot, it
   doesn't error), but deleting a disk out from under a *running, serving*
   instance is the state worth avoiding entirely — this ordering never
   goes there. **Wait for the delete to complete** (poll until the disk
   404s) before continuing — the same busy-window concern as creates.
   Trade-off, stated plainly: this gives up "installer disk as a recovery
   path if the target disk is bad" — acceptable, since the actual recovery
   path for a bad deployment is re-running provisioning from scratch
   (which the app already supports), not resurrecting a half-written disk.
9. `POST .../configs` — **final boot profile**: `devices: {sda: {disk_id:
   targetDiskId}}`, `kernel: "linode/grub2"`, `root_device: "/dev/sda"`,
   **all helpers explicitly disabled**: `helpers: {distro: false,
   modules_dep: false, network: false, updatedb_disabled: true,
   devtmpfs_automount: false}` (Linode's own custom-distribution guidance:
   helpers rewrite `/etc/fstab`, `/etc/hosts`, `/etc/resolv.conf`, inittab
   consoles; the target is NixOS with a mostly read-only `/etc`, so
   helpers rewriting boot-time files would fight or corrupt it — this is
   *only* safe for the final NixOS profile, not the installer's stock
   Debian one, hence the split from step 5). Note `updatedb_disabled` is
   inverted from the others — `true` is what turns updatedb *off*.
10. `POST .../boot` with the final config's **id passed explicitly**. From
    here, `DeploymentService.monitorDeployment`/`_pollForCertificate`
    (unchanged) takes over exactly as it does for the existing path.

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

Also verify in that same test: instance-level `metadata.user_data` (step
1) and a *later*, disk-level `stackscript_id`/`stackscript_data` (step 3)
actually coexist without conflict — Linode's docs position Metadata and
StackScripts as alternatives and are silent on using both together in the
same deployment (they're technically different API calls here — instance
metadata vs. a disk's stackscript — which is likely why it's fine, but
"likely" isn't good enough for something this design fully depends on).

(Region/Metadata-service compatibility, flagged as a concern in an
earlier draft, turned out to be moot — Linode's current docs state the
Metadata service is available in all regions. No region validation needed
beyond what `validation_service.dart` already does.)

### The boot script (Linode implementation: a StackScript, published
once, centrally — see root `CLAUDE.md`'s central-registration principle)

Per this repo's deployment model, anything requiring "a human to register
something once" happens centrally, not per-user — same pattern as the
MCP OAuth Worker holding the shared GitHub OAuth App. Published **once**,
publicly, from our own Linode account; end users never see or interact
with this registration step.

Bugs found and fixed across two review passes:

- **Checksum race** (first pass): `tee >(sha256sum > /tmp/sum)` uses
  process substitution, which bash does not `wait` on — the script could
  reach the check before `sha256sum` has flushed its output, producing a
  flaky **false** mismatch on a perfectly good download. Fixed with an
  explicit FIFO the script does `wait` on.
- **Retry-into-corruption** (first pass): `curl --retry 5
  --retry-all-errors` piped directly into a running `dd` is actively
  dangerous — a retry restarts the HTTP transfer from byte 0, but `dd`
  has already consumed and written the earlier bytes, so the retried
  stream gets appended onto already-written data instead of replacing
  it. Fixed by retrying the **whole pipeline** from scratch in a bash
  loop instead of letting `curl` retry internally mid-stream.
- **Checksum comparison was actually broken** (second pass — a bug
  introduced by the first pass's own fix): `sha256sum -c - < /tmp/sum`
  redirects `sha256sum`'s **stdin** from `/tmp/sum`, which silently
  discards the `printf` output piped into it — `sha256sum -c` ends up
  reading `/tmp/sum`'s line as its checklist, then tries to hash a file
  literally named `-` (stdin, already at EOF), hashes the empty string,
  and the comparison fails unconditionally. The `grep -qx` fallback also
  never matches, since `/tmp/sum` contains `<hash>  -`, never a bare
  hash. Net effect: every attempt reports a mismatch and the script
  always fails, burning 3 full downloads every run. Fixed by reading the
  hash out of the file directly instead of trying to feed it through
  `sha256sum -c`.
- **Target disk size never actually passed in or checked** (second
  pass): `uncompressedBytes` flows all the way through
  `IUrlPullProvisioningApi` but a first pass never threaded it into the
  StackScript's UDFs, so there was nothing to check against. Also, the
  size-check under `set -e` ran `blockdev --getsize64 /dev/sdb` as a bare
  assignment — if `/dev/sdb` doesn't exist, that command fails and the
  script exits *before* reaching the "not found" error message, making
  it dead code. Fixed: added a real device-existence test before the
  assignment, and a real size comparison against a new
  `IMAGE_UNCOMPRESSED_BYTES` UDF.

```bash
#!/bin/bash
# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
# <UDF name="IMAGE_UNCOMPRESSED_BYTES" label="Expected uncompressed size in bytes" />
set -euo pipefail

command -v curl >/dev/null || { apt-get update && apt-get install -y curl; }

[ -b /dev/sdb ] || { echo "FATAL: /dev/sdb not found"; exit 1; }
TARGET_BYTES=$(blockdev --getsize64 /dev/sdb)
[ "$TARGET_BYTES" -ge "$IMAGE_UNCOMPRESSED_BYTES" ] || {
  echo "FATAL: target disk ($TARGET_BYTES bytes) smaller than image ($IMAGE_UNCOMPRESSED_BYTES bytes)"
  exit 1
}

attempt=0
until [ "$attempt" -ge 3 ]; do
  attempt=$((attempt + 1))
  echo "Attempt $attempt..."
  mkfifo /tmp/sumpipe
  sha256sum < /tmp/sumpipe > /tmp/sum &
  SUMPID=$!

  # --max-time/--speed-limit/--speed-time: without these a stalled TCP
  # connection hangs indefinitely -- rely on curl's own stall detection
  # rather than only the app-level timeout in "Failure handling."
  if curl -fsSL --retry 0 --max-time 1800 --speed-limit 1024 --speed-time 60 \
      "$IMAGE_URL" \
      | tee /tmp/sumpipe \
      | gunzip \
      | dd of=/dev/sdb bs=16M conv=fsync status=progress; then
    wait "$SUMPID"
    rm -f /tmp/sumpipe
    read -r ACTUAL_SHA _ < /tmp/sum
    if [ "$ACTUAL_SHA" = "$IMAGE_SHA256" ]; then
      sync
      systemctl poweroff --no-block
      exit 0
    fi
    echo "Checksum mismatch on attempt $attempt (got $ACTUAL_SHA)"
  else
    wait "$SUMPID" 2>/dev/null || true
    rm -f /tmp/sumpipe
    echo "Transfer failed on attempt $attempt"
  fi
done

echo "FATAL: all attempts failed -- leaving instance online for inspection"
exit 1
```

Fails closed on repeated failure — does **not** shut down, leaving the
instance online so the app's poll times out loudly instead of booting a
corrupt disk (see "Failure handling" for what the app does with that —
notably, this is the *script's* fail-closed behavior for a human
debugging a specific run, not something the app should ever rely on by
default; the app-level timeout still deletes the instance rather than
leaving it running unattended).

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

**`/image-manifest` is read-only, on purpose — the Worker has no route
that writes it.** This needs to be explicit: this manifest is the single
point of indirection every future deployment trusts for "which image to
`dd` onto my root disk," and `workers/image-relay` currently has no
authentication on any route and `Access-Control-Allow-Origin: *`. An
unauthenticated write endpoint here would mean anyone who found the URL
could point every future PocketCoder deployment at an arbitrary image —
and the sha256 gate provides no protection against that, since the
attacker supplies the sha256 too. CI already has a scoped R2 credential
(used to upload the image itself); it writes the manifest JSON object
directly to the R2 bucket with that same credential, no Worker route
involved. The Worker's `/image-manifest` handler only ever reads that
object back out.

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
3. CI writes the manifest JSON object (new versioned key + its real
   sha256/size) directly to R2 with its existing scoped credential —
   same run, right after the image upload finishes, never partially
   updated. The Worker never writes this object, only reads it (see
   "Worker changes," above).

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
- `bootstrap.nix`'s secrets heredoc (`cat >> ... <<EOF` with an indented
  body) writes six-space-indented lines into `.env` — leading whitespace
  on a key isn't valid for docker compose's `env_file` parsing. Pre-existing,
  but first boot is now squarely on this design's critical path (the
  first real proof this whole design worked is a successful first boot),
  so worth fixing alongside rather than discovering it as a fresh mystery
  during golden-path testing.
- Confirmed **not** a new problem worth solving here: `g6-standard-1`
  (2GB RAM, the cheapest whitelisted plan) still builds `pocketbase` from
  source on first boot via `docker compose up -d`. Earlier local testing
  this session (real `docker build`, memory-capped) showed this is a
  lightweight Go compile, not the Rust build an early assumption feared —
  low real risk. `fileSystems."/".autoResize` (disk) and plan RAM sizing
  are separate concerns; this note exists only so a future reader doesn't
  conflate the two or think the disk fix also covers memory.

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
