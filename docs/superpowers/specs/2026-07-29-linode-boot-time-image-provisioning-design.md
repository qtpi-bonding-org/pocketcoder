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
`DeploymentService._ensureNixosImage`) is **not wrong** — it's a correct,
reasonable implementation of Linode's documented Custom Images API, and the
same shape of API (push an image, get back an ID, `createInstance(image:
...)`) is how most other cloud providers (DigitalOcean, AWS, GCP) handle
custom images, several of which support real multipart upload where Linode
doesn't. Deleting it would be a real regression for any future non-Linode
provider, and Aeroform is explicitly designed to be multi-provider
(`ICloudProviderAPIClient` is the abstraction boundary for exactly this
reason).

**This design adds a second, additive provisioning path alongside the
existing one**, selected at the seam described below — not a replacement.

## Solution

### New abstraction: `IInstanceProvisioningStrategy`

A new interface, narrower than `ICloudProviderAPIClient`, owning exactly
the part of `DeploymentService.deploy()` that today is inlined as
`_ensureNixosImage()` + the `apiClient.createInstance(...)` call:

```dart
abstract class IInstanceProvisioningStrategy {
  /// Provisions a fresh instance that will boot into the target image.
  /// Returns once the instance exists and (for pull-based strategies) has
  /// finished writing its target disk -- NOT full boot-to-cert-ready
  /// (DeploymentService.monitorDeployment's polling loop, unchanged,
  /// still owns that).
  Future<Instance> provisionInstance({
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

### Strategy 1 (kept, unchanged): `CustomImageProvisioningStrategy`

Wraps exactly today's logic, verbatim:
`findImageByLabel` → if absent, `triggerImageUpload` (relay) → poll
`findImageByLabel` until available → `apiClient.createInstance(image:
imageId, metadata: {user_data: userData})`. Depends only on the existing
`ICloudProviderAPIClient` — no interface changes, no behavior changes.
Fully covered by existing tests (`deployment_service_test.dart`,
`linode_api_client_test.dart`'s `findImageByLabel` group, etc.) — none of
that coverage is touched by this design.

Two small, independent bug fixes worth making to this path's Worker code
regardless (found during the Opus review, real bugs, not stylistic):
1. `streamImageToLinode`'s `await pipeDone` is unreachable on the `fetch()`
   failure path — wrap so both the pipe error and the fetch error are
   surfaced (`Promise.allSettled`-style), not silently dropped.
2. Queue retries currently reuse the same, already-consumed `upload_to`
   URL (Linode's upload URLs are single-use) — the queue message needs to
   carry enough to mint a fresh `upload_to` per retry attempt, or retries
   are guaranteed-dead regardless of the original failure's cause.

Neither fix is required for this design to ship (this path isn't the
default going forward), but both are cheap and this path stays real,
tested code that should work correctly if anything ever re-selects it.

### Strategy 2 (new): `BootTimePullProvisioningStrategy`

**Cross-provider from the start, even though Linode is the only real
implementation today.** The initial version of this design scoped the
underlying API surface to Linode only (disks/configs/StackScripts are
Linode API primitives with no obvious shared vocabulary) — reconsidered:
"boot a stock instance, run a first-boot script that streams+writes an
image onto a second volume, then reboot into that volume" is a real,
recognizable pattern most providers support in some form (AWS: user-data +
EBS volume + block-device-mapping swap; DigitalOcean: cloud-init +
volumes; GCP: startup-script metadata + persistent disk swap; Hetzner:
cloud-init + volumes). Users of this codebase will reasonably expect a
second provider to be addable without re-deriving this abstraction from
scratch, so it's worth naming the shared contract now, even though only
Linode implements it today — same posture as `ICloudProviderAPIClient`
itself, which has always had exactly one real implementation
(`LinodeAPIClient`) but was never written Linode-specific.

```dart
/// Contract for "pull-based" instance provisioning: boot a stock/minimal
/// instance, run a first-boot script that streams an image onto a second
/// raw volume, detect completion, then reconfigure the instance to boot
/// from that volume instead. Each method's *mechanism* is provider-
/// specific (documented per Linode implementation below); the *contract*
/// (what each step accomplishes) is not.
abstract class IPullBasedProvisioningApi {
  /// Creates a bare/minimal instance with no pre-made target OS image
  /// applied, configured to run [bootScript] (with [bootScriptVariables]
  /// substituted in) on first boot, via whatever first-boot-script
  /// mechanism this provider offers (Linode: StackScript; other
  /// providers: cloud-init user-data, startup-script metadata, etc).
  /// [metadata] (e.g. {user_data: ...}) is stored for the *final* boot,
  /// not the installer boot -- carried through unused until step 6 below.
  Future<String> createInstallerInstance({
    required String accessToken,
    required String planType,
    required String region,
    required String label,
    required String bootScript,
    required Map<String, String> bootScriptVariables,
    required String rootSshKey,
    required Map<String, String> metadata,
  });

  /// Creates the raw target volume the boot script will write the image
  /// onto, sized to comfortably exceed the image's uncompressed size.
  Future<String> createTargetVolume({
    required String accessToken,
    required String instanceId,
    required int sizeMB,
  });

  /// Blocks until the installer's boot script signals completion
  /// (provider-specific: Linode = instance status "offline" after the
  /// script's own `shutdown -h now`; a future provider might use a
  /// different completion signal appropriate to its platform).
  Future<void> waitForInstallerCompletion({
    required String accessToken,
    required String instanceId,
  });

  /// Reconfigures the instance to boot from the target volume (carrying
  /// through the final-boot [metadata] passed at installer-creation time)
  /// instead of the installer's own stock disk, and boots it. From here
  /// on the instance behaves exactly like one created via
  /// `CustomImageProvisioningStrategy` -- same metadata/user_data
  /// contract, same cert-polling handoff.
  Future<void> switchToTargetVolumeAndBoot({
    required String accessToken,
    required String instanceId,
    required String targetVolumeId,
  });

  /// Cleans up the installer's stock disk/volume -- call only after the
  /// target volume has been proven to boot successfully (keeping it
  /// around until then is the recovery path if the target turns out bad).
  Future<void> deleteInstallerVolume({
    required String accessToken,
    required String instanceId,
  });
}
```

`BootTimePullProvisioningStrategy` depends only on
`IPullBasedProvisioningApi` — it has zero Linode-specific code in it. All
Linode-specific mechanics live in `LinodeAPIClient`'s implementation of
this interface (implemented alongside its existing
`ICloudProviderAPIClient` implementation — one class, two interfaces, no
conflict):

- `createInstallerInstance`: `POST /linode/instances` with no `image`
  field, `booted: false` (**confirmed live against the real API,
  2026-07-29 — a real instance was created and deleted: Linode accepts
  `metadata.user_data` with no `image` field at all**,
  `"has_user_data": true, "image": null"` in the response — this was the
  one open risk in this design and it's resolved; `bootstrap.nix` and
  `DeploymentConfig.toUserData(...)` need **zero changes**), then
  `POST .../disks` for a small (2.5GB) stock Debian installer disk running
  a Linode **StackScript** (`bootScript` compiled to StackScript UDF
  syntax, `bootScriptVariables` passed as `stackscript_data`),
  `authorized_keys: [rootSshKey]` for debugging access to the installer if
  something goes wrong (separate from the final NixOS box's own
  passwordless-SSH setup, unaffected by this design).
- `createTargetVolume`: `POST .../disks`, `filesystem: "raw"`, sized to
  the plan's disk minus the installer's 2.5GB minus slack (≥ 8GB floor,
  comfortably above the ~4.7GB uncompressed image size).
- `waitForInstallerCompletion`: polls `getInstance` (existing method,
  reused) until `status == "offline"` — the StackScript's last line is
  `shutdown -h now`, so instance-offline *is* the "disk write finished"
  signal. Guarded by a hard timeout.
- `switchToTargetVolumeAndBoot`: `POST .../configs` (`sda` → target
  volume only, `root_device: /dev/sda`, `kernel: "linode/grub2"`) then
  `POST .../boot`. From here, `DeploymentService.monitorDeployment`/
  `_pollForCertificate` (unchanged) takes over exactly as it does for the
  existing path.
- `deleteInstallerVolume`: `DELETE .../disks/{id}`, called by the strategy
  only after the first successful cert-fingerprint poll.

### The boot script (Linode implementation: a StackScript, published
once, centrally — see root `CLAUDE.md`'s central-registration principle)

Per this repo's deployment model, anything requiring "a human to register
something once" happens centrally, not per-user — same pattern as the
MCP OAuth Worker holding the shared GitHub OAuth App. Linode's
implementation of `bootScript` is published **once**, publicly, from our
own Linode account, as a StackScript; end users never see or interact
with this registration step. (A future provider's implementation of the
same `bootScript` contract would deliver it differently — e.g. as
cloud-init user-data — but the script content itself, below, is portable
as-is.)

```bash
#!/bin/bash
# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
set -euo pipefail
curl -fsSL --retry 5 --retry-all-errors "$IMAGE_URL" \
  | tee >(sha256sum > /tmp/sum) \
  | gunzip \
  | dd of=/dev/sdb bs=16M conv=fsync status=progress
grep -q "$IMAGE_SHA256" /tmp/sum || { echo "CHECKSUM MISMATCH"; exit 1; }
sync
shutdown -h now
```

Fails closed on checksum mismatch (does **not** shut down — leaves the
instance online so the app's poll times out loudly instead of booting a
corrupt disk). Needs only a few MB of RAM regardless of image size
(streaming `curl | gunzip | dd`, never buffered) — this is what makes the
cheapest Linode plan (`g6-standard-1`, 2GB RAM) still work, unlike a
download-into-RAM-then-pivot approach, which would need RAM ≥ the
~4.7GB uncompressed image size.

### Worker changes (additive only)

`workers/image-relay` keeps everything it has today (`/upload-image`,
`/image-status`, the Queue infra) — the existing path still needs it. One
new, tiny endpoint is added:

```
GET /image-manifest
→ {"url": "https://<r2-public-domain>/pocketcoder-nixos-latest.img.gz",
   "sha256": "...", "uncompressedBytes": 4930000000}
```

The image itself is served directly from a public R2 bucket/custom domain
(R2 egress is free) — the Worker never touches the bytes for this path
either, matching the "no Worker in the data path" goal. The manifest
endpoint exists purely as a versioning indirection point: `flutter_aeroform`
never hardcodes an R2 URL, so rotating to a new built image (new CI run)
needs zero app changes. The image contains no user secrets (those all
arrive later via `user_data`, unaffected by this design), so making it
publicly fetchable is not a new secret-exposure surface.

### `flutter_aeroform` wiring

`DeploymentConfig` gains an explicit selector so both strategies stay
independently exercisable (by tests, and by any future per-provider DI
choice) rather than only one being reachable at all:

```dart
enum InstanceProvisioningStrategy { customImage, bootTimePull }
```

(default: `bootTimePull`, since that's what real Linode deployments should
use going forward). `external_module.dart`'s DI wiring registers both
`CustomImageProvisioningStrategy` and `BootTimePullProvisioningStrategy`
concretely, and `DeploymentService` picks between them per-config rather
than via a single fixed `@LazySingleton(as: IInstanceProvisioningStrategy)`
— this is the concrete form of "keep both paths modular and selectable."

## Testing

- New unit tests for `BootTimePullProvisioningStrategy` (mocked
  `IPullBasedProvisioningApi` — provider-agnostic, no Linode specifics
  leak into this test file at all), mirroring the existing
  `deployment_service_test.dart` mocking pattern.
- New unit tests for `LinodeAPIClient`'s `IPullBasedProvisioningApi`
  implementation (mirroring the existing `linode_api_client_test.dart`
  pattern — request shape assertions against a mocked `http.Client`,
  covering the actual StackScript/disk/config request bodies).
- `CustomImageProvisioningStrategy`'s tests are the existing
  `deployment_service_test.dart`/`linode_api_client_test.dart` coverage,
  extracted into the new class but otherwise unchanged.
- `test/integration/golden_path_provision_test.dart` gets rewritten for
  the new 7-step sequence (this is the real, live proof — same
  AEROFORM_LIVE_TEST=1 gating, same real-money/real-instance caveats,
  same auto-teardown requirement as today).

## Known unrelated bug (fix alongside this work)

`AppConfig.kImageRelayUrl` defaults to
`https://pocketcoder-image-relay.workers.dev`, but the actually-deployed
Worker is `https://pocketcoder-image-relay.gp-c53.workers.dev` — any build
without an explicit `--dart-define=IMAGE_RELAY_URL` override hits a
nonexistent host. Fix the default (or fail loudly on a missing define)
regardless of which provisioning path is active, since both need a correct
relay/manifest URL.

## Out of scope

- Removing `/upload-image`/`/image-status`/the Queue from `image-relay` —
  explicitly kept for `CustomImageProvisioningStrategy`.
- Any change to `bootstrap.nix` or the NixOS image build itself — the
  image is already built in exactly the right unpartitioned raw format for
  `dd` (confirmed: `deploy/nixos/flake.nix` already uses
  `partitionTableType = "none"`, `format = "raw"`; `configuration.nix`
  already does GRUB `device = "nodev"` + `forceInstall`).
- **Actually implementing a second `IPullBasedProvisioningApi` provider.**
  The interface is deliberately cross-provider-shaped now (see Strategy 2),
  but only `LinodeAPIClient` implements it in this design — no DigitalOcean/
  AWS/GCP/Hetzner client exists yet, and none is added here. Adding one
  later is exactly the point of naming the contract now, but it's a
  separate, future body of work.
- `ICloudProviderAPIClient` itself is untouched by this design —
  `IPullBasedProvisioningApi` is a new, separate interface a client can
  additionally implement, not a change to the existing one.
