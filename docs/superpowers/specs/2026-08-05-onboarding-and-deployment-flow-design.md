# PocketCoder Onboarding and Deployment Flow — Design

**Status:** Proposed

## Goal

Make first launch a single, understandable funnel:

```text
Boot
  ├─ Existing authenticated PocketBase server → first chat
  ├─ Reachable server, not authenticated → PocketBase login
  └─ No reachable server → Login or Deploy
                                      │
                                      └─ Deploy
                                           → credentials
                                           → Linode
                                           → Linode OAuth
                                           → region/plan
                                           → deployment progress
                                           → deployment details
                                           → pre-filled PocketBase login
  PocketBase login
    → choose Claude Code or Codex
    → account login
    → provider-specific authorization
    → connected
    → first chat
```

The flow is made of separate routes. No single onboarding widget owns the
entire state machine, and the user does not need to return to Settings to
finish setup.

## Pages

### 1. Boot screen

Existing `BootScreen` remains the launch gate. It checks PocketBase health and
then checks the local auth store.

- Healthy and authenticated: go to `ChatListScreen`.
- Healthy but not authenticated: go to `PocketBaseLoginScreen`.
- Not reachable: go to `ServerChoiceScreen`.

The boot screen should not silently treat an unreachable saved URL as a new
deployment. It should let the user choose whether to log into another server
or deploy one.

### 2. Server choice screen

New `ServerChoiceScreen` with two explicit actions:

- `LOGIN` → `PocketBaseLoginScreen`
- `DEPLOY` → `DeployCredentialsScreen`

This screen has no form state.

### 3. PocketBase login screen

New `PocketBaseLoginScreen` with:

- Server URL
- Email
- Password

It is reusable in two places:

1. Direct login from first launch.
2. Login after deployment, with URL/email/password pre-filled from secure
   storage.

On success it routes to `HarnessChoiceScreen`, unless the user is already
inside an explicitly non-onboarding login flow.

### 4. Deploy credentials screen

New `DeployCredentialsScreen` with:

- Desired PocketBase admin email
- Desired PocketBase admin password

The values are carried forward as an immutable `DeployCredentials` object.
They are not persisted by this page. Aeroform stores the resulting deployment
credentials in secure storage once the deployment has been accepted.

### 5. Deploy provider screen

Existing `DeployPickerScreen`, simplified for the funnel. The initial provider
is Linode. Provider selection is a route transition, not a mode inside a large
onboarding page.

### 6. Linode OAuth screen

Existing `AuthScreen`. It opens the Linode OAuth flow through the OAuth relay
and forwards `DeployCredentials` to the configuration page.

### 7. Deployment configuration screen

Existing `ConfigScreen`. It loads available Linode regions and plans, then
accepts the deployment request.

This page should navigate to progress as soon as a deployment job has been
accepted—not after the complete disk/image installation has finished.

### 8. Deployment progress screen

Existing `ProgressScreen`, redesigned as a standalone deployment monitor.

It displays deployment phases from a deployment controller rather than trying
to own the provisioning algorithm. It should survive route transitions and
resume monitoring if the app is backgrounded or restarted.

Target phases:

```text
Preparing deployment
Creating Linode
Preparing installation disk
Copying PocketCoder image
Booting PocketCoder
Waiting for PocketBase
Ready
```

### 9. Deployment details screen

Existing `DetailsScreen`, redesigned to show verified server details:

- Deployment status
- PocketBase URL
- IP address
- Region
- Plan
- Admin email
- Password reveal/copy controls
- Last successful server health check
- Deployment timestamp

The primary action is `LOG IN NOW`, which opens the reusable
`PocketBaseLoginScreen` with values read from secure storage.

### 10. Harness choice screen

New `HarnessChoiceScreen` with:

- Claude Code
- Codex

This page only chooses the harness. It does not show all Settings controls.

### 11. Claude authorization screen

New `ClaudeAuthScreen`:

1. Starts account authentication for Claude Code.
2. Opens the provider authorization URL.
3. Accepts the authorization code.
4. Submits the code.
5. Shows `CONNECTED`.

### 12. Codex authorization screen

New `CodexAuthScreen`:

1. Starts account authentication for Codex.
2. Opens the device URL.
3. Shows the device code when one is required.
4. Polls the server for completion.
5. Shows `CONNECTED`.

### 13. First chat

Existing `ChatListScreen` remains the destination. Its existing empty-chat
behavior creates and opens the first chat automatically.

## Deployment lifecycle

There are two different kinds of progress and they must not be conflated.

### Linode control-plane progress

The Linode API can provide:

- Linode instance state (`creating`, `provisioning`, `running`, etc.).
- Instance metadata such as ID, label, region, plan, IP addresses, and image.
- Account and instance events for API operations, stored for 90 days.
- Disk/configuration/boot operations represented as API events.

Linode events are useful diagnostic evidence, but they are not a reliable
PocketCoder installation state machine. They tell us that a Linode API action
occurred; they do not tell us that Docker, PocketBase, Caddy, or the harness
images are ready.

### PocketCoder server progress

The deployed server must provide the application-level truth:

- The image has booted.
- First-boot bootstrap has started.
- The PocketBase stack is running.
- Caddy is serving the expected HTTPS endpoint.
- PocketBase health responds successfully.
- The bootstrap marker has been written.

The current client already checks PocketBase's public `/api/health` endpoint.
That should remain the final readiness check. We should additionally expose a
small deployment-status endpoint or signed status document for the pre-login
deployment monitor, rather than exposing logs or credentials.

Suggested status shape:

```json
{
  "phase": "waiting_for_pocketbase",
  "ready": false,
  "version": "<release-commit>",
  "message": "Starting PocketBase",
  "observedAt": "2026-08-05T00:00:00Z"
}
```

The endpoint must not return admin passwords, root keys, environment files, or
raw boot logs. It should be protected by a deployment-specific bootstrap
nonce, or expose only intentionally safe readiness information.

## Timing and mobile UX

The existing boot-time provisioning notes estimate approximately 5–8 minutes
of additional wall-clock time for the R2 download, decompression, disk write,
and the two boot cycles. The golden-path test separately allows approximately
10 minutes of 30-second readiness polling while waiting for the final HTTPS
certificate and server startup.

Six minutes is long for an ordinary mobile interaction, but reasonable for a
one-time “create my server” operation if the app behaves like a deployment
console rather than a normal loading screen. We should not make a Debian
decision solely to remove that wait.

The deployment experience must therefore:

- Enter the progress page as soon as deployment work is accepted.
- Show a changing phase, elapsed time, and last update timestamp.
- Show a reassuring explanation for slow phases such as image transfer.
- Persist the deployment ID and resume monitoring after app backgrounding or
  relaunch.
- Allow the user to leave the page without cancelling the server.
- Send an optional local notification when deployment becomes ready or fails.
- Use a clear timeout/error state with retry and cleanup guidance.

The page should never promise that deployment will finish in a fixed number of
seconds. It should show an estimated range only after we have real production
timing data for the selected region and plan.

## Current implementation findings

The current app flow has several gaps that this design must resolve:

1. `ConfigScreen` creates a `DeploymentCubit` locally, while the progress
   route is a separate route. The deployment controller must be provided at a
   scope shared by configuration, progress, and details, or be reconstructed
   from a persisted deployment ID.
2. `DeploymentCubit.deploy()` currently waits for Aeroform's provisioning call
   before returning. This means the user can remain on the configuration page
   while the installer disk and target disk are created and the NixOS image is
   copied.
3. `DeploymentCubit` then polls the Linode instance state independently. The
   current progress UI therefore shows coarse cloud state rather than the real
   installer phase.
4. Polling needs a bounded backoff and resumable state. A naive exponential
   schedule grows too large for a user-facing flow.
5. Cancel must distinguish “stop watching” from “delete the partially-created
   deployment.” Deleting a billable Linode must be explicit and confirmed.
6. Details should use the secure-storage credentials as the source for the
   login handoff, not rely only on an in-memory route extra.

## Linode capabilities and how we use them

### Metadata service

Linode's Metadata service is available in all regions and is accessible only
from inside the provisioned Linode. It exposes instance data, network data,
SSH key data, and optional user data. Compatible cloud-init versions can
consume the user data during first boot.

This makes Metadata useful for server-side bootstrap, but it cannot directly
report progress to the phone. The phone still needs to poll a public,
restricted readiness endpoint on the server.

### StackScripts

StackScripts run on first boot and support custom user-defined fields. They
are a reasonable bootstrap mechanism, but they execute only after the base
system boots and are not themselves a PocketCoder progress API.

The current boot-time pull design uses a short-lived installer disk and a
StackScript to copy the published PocketCoder image onto the target disk.
That is a valid implementation detail, but the app should report it through a
deployment status contract instead of exposing the StackScript mechanics.

### Instance and account events

The Linode API exposes account events and instance activity. We should record
the event IDs associated with a deployment for diagnostics where practical.
They are useful for messages such as “Linode disk creation failed,” but they
should not be the only readiness signal.

Reading account events requires the `events:read_only` OAuth scope. The
current Linode OAuth scope set is focused on Linodes and images, so adding
event-driven diagnostics would require an explicit scope review rather than
assuming the existing token can call the events endpoint.

### Images and image manifest

The current image relay serves a public image manifest containing the release
image URL, checksum, and uncompressed size. The instance pulls the image
directly during provisioning; the Cloudflare Worker is not in the large image
data path.

This is preferable to streaming a large image through a request-limited Worker
and should remain the default path.

## NixOS versus a Debian deployment

### Recommendation

Do not expose “NixOS versus Debian” as a user-facing onboarding choice.

We should keep NixOS as the production deployment backend while prototyping a
Debian backend separately. If the Debian path proves substantially faster
and more reliable, it can replace the backend without changing the funnel.

### Why keep NixOS for now

- The repository already has a reproducible NixOS image and release pipeline.
- `configuration.nix` defines the expected Docker, Caddy, firewall, and system
  behavior in one versioned configuration.
- The boot-time pull path gives us a checksum-verified release image.
- Upgrades can be tied to a known release commit rather than a mutable package
  installation.
- The current security model already expects fail-closed bootstrap behavior.

### What a Debian path could improve

A supported Debian image with cloud-init and a StackScript could:

- Avoid the temporary installer disk and raw image copy.
- Use Linode Metadata user data directly.
- Install Docker and start the PocketCoder compose stack during first boot.
- Produce more familiar cloud-init logs and failure modes.
- Potentially make first deployment simpler and faster.

Linode explicitly supports cloud-init user data on compatible distributions,
and recommends Metadata as an alternative to StackScripts for new projects.

### What it would cost

- More mutable, distribution-specific setup logic.
- Package repository availability and apt/dnf version drift.
- More work to make upgrades and rollback reproducible.
- A new image/bootstrap test matrix.
- More care around Docker, Caddy, firewall, SSH, disk layout, and service
  ordering.
- A different backup and recovery validation path.

### Decision gate for a prototype

Prototype Debian only if it can satisfy all of these with automated tests:

1. Fresh Linode boots with no manual SSH intervention.
2. Credentials reach the server without appearing in logs.
3. PocketBase health is reachable over HTTPS.
4. The deployment status endpoint reports useful phases.
5. Harness images and the first chat work identically to NixOS.
6. Failed bootstrap is diagnosable and leaves no unbounded orphan resource.
7. A release can be upgraded and rolled back predictably.

Until then, Debian is an implementation choice, not an onboarding option.

## Modular provisioning backends and A/B testing

The onboarding funnel should not know whether the server is built with NixOS,
Debian, or another supported image. That choice belongs behind the deployment
controller.

The repository already has a useful starting seam in Aeroform:
`IInstanceProvisioningStrategy`. The current default implementation is
`BootTimePullProvisioningStrategy`, which delegates Linode-specific disk and
boot operations to `LinodeBootTimeInstaller`.

That seam needs to grow from a blocking “return an instance” call into a
deployment backend contract with progress and resumability:

```text
DeploymentBackend
  start(request) → DeploymentHandle
  status(handle) → DeploymentSnapshot
  cancel(handle) → CleanupResult
```

`DeploymentSnapshot` is provider-neutral:

```text
deploymentId
backend
phase
phaseMessage
linodeId
ipAddress?
serverUrl?
ready
failure?
startedAt
updatedAt
```

The backend may use completely different internal mechanisms, but the UI only
sees this snapshot. This keeps `DeploymentProgressScreen` and
`DeploymentDetailsScreen` identical for both paths.

### NixOS backend

The existing backend would continue to perform:

1. Fetch the signed/current image manifest.
2. Create the temporary installer and target disks.
3. Run the installer StackScript.
4. Copy the release image onto the target disk.
5. Boot the target disk.
6. Wait for PocketCoder server readiness.

Its detailed phases would be emitted by the installer/controller instead of
being hidden inside one long `deploy()` Future.

### Debian backend

The fast path could use a pinned Debian Linode image and create a single Linode
directly:

1. Create the Linode with the selected plan and region.
2. Attach a Cloud Firewall before exposing services where possible.
3. Supply cloud-init-compatible user data through Linode Metadata.
4. On first boot, cloud-init would:
   - create the required filesystem/directories;
   - install Docker and Compose dependencies;
   - install or load the pinned PocketCoder release;
   - write the deployment environment file with restrictive permissions;
   - start the PocketCoder services;
   - wait for Docker, Caddy, and PocketBase;
   - write a signed/nonce-protected deployment status result.
5. The app would poll the same deployment-status contract and then verify
   PocketBase health.

This removes the temporary installer disk, raw image copy, and second boot.
It should be materially faster, but the actual result must be measured on the
real Linode plans and regions rather than promised in the UI.

The Debian path must use a pinned release artifact or commit. It must not
blindly clone a mutable branch during first boot. The bootstrap script also
needs explicit handling for package installation failures, partial Docker
startup, re-entry after reboot, and cleanup after a failed deployment.

### Shared pieces

Both backends should share:

- Linode OAuth and API authorization.
- Region and plan selection.
- User-selected PocketBase admin credentials.
- Deployment IDs and persisted monitoring state.
- Secure credential storage.
- Deployment status snapshots.
- PocketBase readiness checks.
- Details and login handoff.
- Cleanup/orphan-reaping behavior.
- First-run onboarding and harness setup.

Only the provisioning backend should differ.

### A/B testing strategy

For internal testing, select the backend through a constrained enum, not an
arbitrary user-provided value:

```text
DeploymentBackendKind.nixos
DeploymentBackendKind.debian
```

The first rollout can use a build-time or development-only flag. A later
rollout can use a remotely managed percentage or cohort assignment, provided
the app receives only the approved enum and never an arbitrary image URL,
script URL, or shell command.

The assignment must be persisted with the deployment record. A deployment
cannot switch backend halfway through provisioning. Existing deployments keep
their original backend for status, upgrades, and cleanup.

Telemetry should compare at least:

- time to Linode creation;
- time to first server status;
- time to PocketBase readiness;
- failure phase and error category;
- orphaned-resource rate;
- successful first login;
- successful first chat;
- upgrade and recovery results.

### Advanced setting later

If we eventually expose this to users, it should be an advanced deployment
choice such as “Runtime image: Recommended / Advanced,” with a warning that
the choice affects upgrade and recovery behavior. It should not appear in the
normal first-run funnel and should not be changeable for an existing server.

## Coupling audit: NixOS, Docker, and the StackScript

### What is actually coupled

The Docker application stack is not inherently NixOS-specific. The Compose
services mostly need a Linux host with:

- Docker Engine and Compose;
- persistent volumes;
- the expected filesystem paths;
- outbound network access;
- a reverse proxy exposing PocketBase over HTTPS;
- a host firewall and safe Docker networking behavior.

The current deployment makes those host services NixOS-specific in
`deploy/nixos/configuration.nix` and `deploy/nixos/caddy.nix`:

- NixOS enables and configures Docker.
- NixOS configures the host firewall and `DOCKER-USER` metadata blocking.
- NixOS runs Caddy as a host systemd service.
- NixOS detects the public IP and writes the runtime Caddyfile.
- NixOS provides SSH and the serial console.
- NixOS starts `pocketcoder-bootstrap.service` during first boot.

Those are host-runtime responsibilities, not application-container
responsibilities. A Debian backend would need an equivalent host adapter, or
we could move selected responsibilities—especially Caddy—into Compose.

### What the StackScript is coupled to

`pocketcoder-image-installer.sh` is strongly coupled to the current NixOS
boot-time-pull mechanism. It assumes:

- the installer is Debian, but the target is a raw NixOS disk;
- the target disk is `/dev/sdb`;
- the target contains a whole-disk ext4 filesystem;
- the image is a gzip-compressed raw disk image;
- the target can be mounted at `/mnt/target`;
- bootstrap configuration belongs at `/var/lib/pocketcoder-bootstrap-env`;
- the installer should power off after writing the target;
- the final NixOS boot will consume that file and run `bootstrap.nix`.

This script should remain named and owned as a NixOS image installer. It
should not become a generic Debian/NixOS script with distribution branches.
The Debian backend should have a separate cloud-init/bootstrap artifact.

### What is coupled in the release pipeline

The GitHub workflow deliberately builds and promotes the NixOS image and
Docker image bundle together. Both artifacts must have the same source commit,
and the release manifest publishes them as one coupled release.

That is a sensible safety invariant today, but it is stronger than the runtime
needs. The application stack can be shared by multiple host backends if the
release manifest becomes a product release containing optional artifacts:

```json
{
  "sourceCommit": "...",
  "composeBundle": { "url": "...", "sha256": "..." },
  "nixos": { "imageUrl": "...", "sha256": "..." },
  "debian": { "bootstrapUrl": "...", "sha256": "..." }
}
```

Every backend should still validate that its host artifact and Compose/image
bundle were produced from the same source commit. The artifacts become
modular without allowing incompatible releases to drift silently.

### Recommended decomposition

Split deployment artifacts into four explicit layers:

1. **Application release** — PocketBase, Goose, MCP gateway, Ollama policy,
   harness images, Compose configuration, migrations, and server code.
2. **Host contract** — Docker, persistent storage, networking, firewall,
   reverse proxy, SSH/recovery, and service supervision.
3. **Bootstrap contract** — how credentials, release identity, and deployment
   status reach the host and how first boot reports completion.
4. **Provider mechanism** — Linode disks/config profiles for NixOS, or Linode
   instance plus cloud-init for Debian.

The application release should not know whether the host contract is provided
by NixOS or Debian. The provider mechanism should not know PocketBase internals
beyond the bootstrap/status contract.

### Concrete changes for modularity

In broad terms, Aeroform would need:

- a non-blocking `DeploymentBackend`/deployment-handle API;
- a backend-neutral deployment snapshot and phase model;
- a NixOS backend wrapping the existing
  `BootTimePullProvisioningStrategy` and `LinodeBootTimeInstaller`;
- a Debian backend wrapping direct Linode creation plus cloud-init;
- backend-neutral credential/status storage;
- provider-independent cleanup and resumable monitoring;
- DI selection by an approved backend enum.

The PocketCoder repository would need:

- a generic bootstrap/status contract;
- a separate Debian cloud-init artifact;
- host-agnostic Compose assumptions where practical;
- a release manifest that can carry both host artifacts and one shared
  application release;
- removal of hard-coded NixOS assumptions from shared deployment models;
- a clear choice about whether Caddy remains host-managed or becomes a
  Compose-managed service.

The StackScript itself should not be generalized. Keeping it narrowly NixOS
specific is what makes the backend boundary honest.

## Proposed deployment controller

The funnel should use one deployment controller with durable, small state:

```text
DeploymentController
  start(config, credentials)
  watch(deploymentId)
  retry(deploymentId)
  cancel(deploymentId, deleteResource: explicit)
```

The controller stores only:

- Deployment ID / Linode ID
- Current phase
- Last known Linode status
- Last known server status
- Timestamps
- Non-sensitive error information

The UI pages subscribe to the controller. They do not coordinate Linode API
calls themselves.

## Acceptance criteria

- A user always knows which page they are on and what action is next.
- Deployment progress begins immediately after the deployment request is
  accepted.
- Closing and reopening the app can resume deployment monitoring.
- Details are shown only after server readiness is verified.
- Login credentials are prefilled from secure storage and never displayed in
  logs or URLs.
- A successful PocketBase login always continues to harness setup during the
  first-run funnel.
- A connected Claude Code or Codex harness always leads to the first chat.
- The user never needs to visit Settings to complete first-run setup.

## References

- [Akamai Metadata service](https://techdocs.akamai.com/cloud-computing/docs/overview-of-the-metadata-service)
- [Metadata service API](https://techdocs.akamai.com/cloud-computing/docs/metadata-service-api)
- [Akamai StackScripts](https://techdocs.akamai.com/cloud-computing/docs/stackscripts)
- [Deploy using a StackScript](https://techdocs.akamai.com/cloud-computing/docs/deploy-a-compute-instance-using-a-stackscript)
- [Linode API events](https://techdocs.akamai.com/linode-api/reference/events)
- [Cloud Manager events and activity feeds](https://techdocs.akamai.com/cloud-computing/docs/what-are-cloud-manager-events-and-activity-feeds)
- [Akamai Images](https://techdocs.akamai.com/cloud-computing/docs/images)
- [PocketCoder boot-time provisioning design](2026-07-29-linode-boot-time-image-provisioning-design.md)
- [PocketCoder deploy credentials design](2026-08-02-deploy-entry-point-and-admin-credentials-design.md)
