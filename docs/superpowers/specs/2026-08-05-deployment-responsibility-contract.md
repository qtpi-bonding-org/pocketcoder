# PocketCoder Deployment Responsibility Contract

**Status:** Normative design — implementation must follow this document.

## Purpose

This document defines which layer is responsible for each part of deploying a
PocketCoder server. It exists to prevent NixOS, Debian, Docker, Linode, and
Aeroform responsibilities from becoming tangled together.

The user-facing deployment flow must be identical regardless of the selected
host backend:

```text
Linode OAuth
  → region/plan
  → deployment progress
  → PocketCoder ready
  → deployment details
  → PocketBase login
```

Only the provisioning backend changes.

## Responsibility layers

### PocketCoder client

The PocketCoder app owns user interaction and deployment observation:

- collect the desired PocketBase admin email/password;
- let the user choose provider, region, and plan;
- start a deployment;
- display deployment phases and errors;
- persist the deployment ID for resumption;
- poll/resume deployment status;
- show verified deployment details;
- read credentials from secure storage for login handoff;
- continue into harness authentication and the first chat.

The PocketCoder app must not contain NixOS shell logic, Debian package
installation logic, Docker Compose orchestration, or StackScript behavior.

### Aeroform

Aeroform owns provider-neutral deployment orchestration and Linode API access:

- validate the requested plan and region;
- use the Linode OAuth access token;
- generate deployment SSH credentials;
- create and manage Linode resources;
- select the provisioning backend;
- pass a release/bootstrap payload to that backend;
- persist instance credentials in secure storage;
- expose deployment snapshots and phases;
- monitor provider state and server readiness;
- clean up partial resources;
- provide orphan-reaping safety operations.

Aeroform must not own PocketBase business logic or the normal onboarding UI.

## What Linode can and cannot do

Linode can perform simple provider operations directly:

- create a Linode from a supported distribution image;
- create a Linode from an image already available to the account/region;
- attach disks and volumes;
- create configuration profiles;
- boot, shut down, reboot, and delete instances;
- run a StackScript on first boot;
- deliver Metadata/user data to compatible cloud-init distributions;
- report instance state and API events.

Linode cannot take an arbitrary PocketCoder NixOS image URL during ordinary
instance creation and automatically perform our complete conversion workflow.
The API needs either a supported distribution image or a Linode image already
available in the relevant account/region.

Therefore, the Cloud Manager's apparent “create a NixOS Linode” action would
still be implemented as several provider operations behind the scenes. It can
hide the steps from a human, but it cannot replace the image/install workflow
that makes PocketCoder's release image bootable.

## NixOS backend

### Aeroform responsibility

The current NixOS backend performs these provider operations directly through
the Linode API:

1. Create the bare Linode.
2. Fetch the release image manifest.
3. Create the temporary installer disk.
4. Create the target disk.
5. Create the installer boot profile.
6. Boot the installer.
7. Poll until the installer completes.
8. Remove the installer disk and installer profile.
9. Create the final NixOS boot profile.
10. Boot the final NixOS disk.
11. Return the instance handle for server-readiness monitoring.

These operations are implemented by Aeroform's
`LinodeBootTimeInstaller`, behind the NixOS provisioning strategy. The
PocketCoder app calls Aeroform; it does not call these Linode endpoints itself.

### NixOS image responsibility

The NixOS image is a prebuilt host operating system. It provides:

- Docker Engine;
- native Caddy;
- SSH and serial-console support;
- firewall configuration;
- Docker metadata blocking;
- networking;
- required host packages;
- the systemd units needed for first boot.

The NixOS image must not contain user-specific deployment credentials.

### NixOS StackScript responsibility

`deploy/nixos/stackscripts/pocketcoder-image-installer.sh` runs on the
temporary Debian installer disk. It is not the PocketCoder application
bootstrap.

It must only:

1. Download the compressed NixOS image.
2. Verify the image checksum and target size.
3. Decompress the image onto the target disk.
4. Mount the target filesystem.
5. Write the encoded deployment bootstrap payload.
6. Verify the payload was written correctly.
7. Unmount and power off the installer.

It must not install or start Docker, Caddy, PocketBase, Goose, or harnesses.

The StackScript is intentionally NixOS-specific and must not gain Debian
branches.

### NixOS first-boot responsibility

`deploy/nixos/bootstrap.nix` runs from the final NixOS system after the target
disk boots. It must:

1. Read the bootstrap payload.
2. Create the protected PocketCoder environment file.
3. Install the deployment SSH key.
4. Generate internal service secrets.
5. Fetch the exact PocketCoder release.
6. Verify/load the matching Docker image bundle.
7. Build missing images only as a fallback.
8. Start the Compose application stack.
9. Write the bootstrap completion marker.
10. Publish deployment status for the app to observe.

Native Caddy is not part of Docker Compose. `deploy/nixos/caddy.nix` owns:

- public-IP detection;
- `sslip.io` hostname generation;
- native Caddy configuration;
- native Caddy startup;
- reverse proxying to PocketBase.

## Debian backend

### Standard Linux boundary

“Debian backend” is the first implementation name, not the product
abstraction. The long-term backend choices are:

```text
NixOS
Standard Linux
```

The Standard Linux backend may support approved distributions such as Debian
and Ubuntu through a constrained internal parameter:

```text
DeploymentBackendKind.nixos
DeploymentBackendKind.standardLinux

StandardLinuxDistribution.debian
StandardLinuxDistribution.ubuntu
```

The app must not accept arbitrary distribution names, image IDs, package
repositories, or bootstrap URLs. Each supported distribution gets a tested
host adapter and pinned base image.

The common Standard Linux bootstrap owns the application contract. A
distribution adapter owns only host differences such as:

- base image identifier;
- package-manager/repository setup;
- Docker installation;
- native Caddy installation;
- firewall commands;
- service/package paths;
- cloud-init defaults.

This is not a single giant shell script with unbounded distribution branches.
It is one backend with small, explicit Debian and Ubuntu host adapters. Debian
can be the first adapter; Ubuntu can be added later without changing the
onboarding funnel or application stack.

### Standard Linux startup layers

The Standard Linux backend should not use the NixOS installer StackScript.
Prefer Linode's normal distribution image plus cloud-init/Metadata user data.

There are two startup layers:

1. **Distribution adapter / cloud-init** — runs on the first boot and handles
   Debian-versus-Ubuntu host setup:
   - package repositories and package installation;
   - Docker installation;
   - native Caddy installation;
   - firewall setup;
   - metadata access restrictions;
   - creation and enablement of the persistent bootstrap service.
2. **Shared PocketCoder bootstrap service** — runs as a persistent,
   idempotent systemd service and handles:
   - release manifest download and verification;
   - Docker image bundle loading;
   - protected environment-file creation;
   - Compose startup;
   - deployment-status updates;
   - PocketBase readiness;
   - completion marker creation.

Therefore, the Debian-versus-Ubuntu difference is primarily the host adapter,
not the application boot script. The shared bootstrap must receive a stable
host contract and must not need to know which package manager installed Docker
or Caddy.

### Aeroform responsibility

The Debian backend should use the simplest supported Linode operation:

1. Create one Debian Linode directly.
2. Supply cloud-init/Metadata user data or a thin StackScript bootstrap.
3. Return the instance handle immediately after the provider accepts creation.
4. Monitor the Debian bootstrap and PocketCoder readiness.

It should not create a temporary installer disk, raw target disk, or second
boot profile.

### Debian StackScript responsibility

The preferred Debian path uses Metadata user data and cloud-init, so a
StackScript is optional.

If a StackScript is used, it must remain thin. It may:

- install or verify minimal prerequisites;
- install the persistent Debian bootstrap service;
- write non-secret release/bootstrap references;
- start the bootstrap service.

It must not duplicate the full application installation logic or become a
second distribution-specific deployment engine.

### Debian first-boot responsibility

Debian needs a persistent, idempotent equivalent of `bootstrap.nix`, for
example:

```text
pocketcoder-bootstrap.service
  → /usr/local/lib/pocketcoder-bootstrap.sh
```

It must:

1. Wait for networking.
2. Install Docker and Compose.
3. Install and configure native Caddy.
4. Configure the host firewall.
5. Block container access to Linode Metadata where required.
6. Fetch and verify the pinned PocketCoder release.
7. Load the matching Docker image bundle.
8. Write the protected environment file.
9. Start the same PocketCoder Compose stack.
10. Wait for Docker, Caddy, and PocketBase readiness.
11. Publish deployment status.
12. Write an idempotent completion marker.

The Debian host should expose the same external PocketBase URL contract and
the same native-Caddy behavior as NixOS.

## Docker responsibility

Docker is the application runtime, not the host operating system.

The same application release should run on both NixOS and Debian:

- PocketBase;
- Goose;
- MCP gateway;
- Ollama;
- harness image build/load targets;
- volumes and networks;
- migrations and server configuration.

The Compose stack may assume the shared host contract, but it must not assume
that the host kernel or package manager is NixOS-specific.

Native Caddy remains outside Compose intentionally. It must be able to start
after an operating-system reboot even when Docker or PocketBase is not yet
ready.

## Observability responsibility

The deployment controller must expose backend-neutral phases:

```text
creating_provider_resource
preparing_host
installing_application
starting_services
waiting_for_server
ready
failed
```

The NixOS backend may add details such as “copying raw image.” The Debian
backend may add details such as “cloud-init installing Docker.” The UI must
not depend on those backend-specific details to function.

Linode API events are diagnostic evidence. The server deployment-status
contract and PocketBase health check are the readiness authority.

## Release responsibility

The release should be represented as one manifest containing a shared
application release and optional host artifacts:

```json
{
  "sourceCommit": "...",
  "composeBundle": {
    "url": "...",
    "sha256": "..."
  },
  "nixos": {
    "imageUrl": "...",
    "sha256": "..."
  },
  "debian": {
    "bootstrapUrl": "...",
    "sha256": "..."
  }
}
```

The NixOS image, Debian bootstrap, and Docker image bundle should be produced
from the same source commit for a release. They are allowed to be different
artifacts, but must not silently drift across commits.

## Non-negotiable rules

1. The PocketCoder app does not contain shell/bootstrap logic.
2. Aeroform owns Linode API orchestration.
3. NixOS StackScript remains a raw-image installer only.
4. NixOS `bootstrap.nix` remains final-host application bootstrap only.
5. Debian uses a separate bootstrap implementation.
6. Docker application artifacts are shared across hosts.
7. Native Caddy remains host-managed on both hosts.
8. Deployment status is backend-neutral.
9. Credentials never appear in logs, URLs, or public status responses.
10. A failed partial deployment must have bounded cleanup and orphan-reaping.
