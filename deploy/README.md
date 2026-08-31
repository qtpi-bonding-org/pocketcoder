# Manual PocketCoder deployment

This guide reaches the same user-owned PocketCoder server state without
`flutter_aeroform` or the private PocketCoder Pro app. **NixOS is the
recommended and tested deployment target.** Standard Linux/Docker remains a
public self-hosting option, but it is best-effort and is not the guaranteed
support path. A cloud provider is still needed to create a VPS or install a
disk image; provider account and machine creation steps are intentionally
provider-specific.

## What the release CLI does

`pocketcoder-release` is a local root CLI, not a network service:

| Command | Behavior |
| --- | --- |
| `check-metadata` | Fetches and verifies release metadata and records status. It does not update or activate anything. |
| `install` | Performs the first signed release installation during bootstrap. |
| `update` | Explicitly resolves, verifies, snapshots, activates, health-checks, and commits a new PocketCoder release. |
| `rollback` | Explicitly restores the previous release when the data-version and revocation rules allow it. |
| `restart-pocketcoder` | Restarts the active Compose deployment. |
| `backup-data` / `restore-data` | Creates or restores the PocketBase data backup through Docker volumes. |
| `restart-os` | Reboots NixOS. |
| `update-os` / `upgrade-os` | Explicitly applies an OS update; `upgrade-os` selects the signed release's NixOS version and uses the transaction/health-check path. |
| `rollback-os` | Restores the previous NixOS generation through the transaction/health-check path. |

The NixOS metadata timer runs `check-metadata` periodically. It does not run
`update`, activate a release, or reboot the OS. Updates are explicit.

## Path A: standard Linux / Docker (best-effort)

This is the simplest provider-independent self-hosting path, but it is not the
recommended or guaranteed-support path. Start with a fresh Ubuntu or
Debian VPS with Docker Compose v2, root or sudo access, a stable public IP, and
at least 2 GiB RAM. 4 GiB is recommended for operational headroom.

From a checked-out public PocketCoder commit on the VPS:

```bash
git clone https://github.com/qtpi-bonding-org/pocketcoder.git
cd pocketcoder
git checkout <reviewed-commit>
./deploy.sh
```

`deploy.sh` generates the local `.env`, applies the public Linux host baseline,
configures native Caddy on Linux, builds the Compose stack, and starts it. Do
not commit `.env`; it contains deployment secrets. Configure harness and model
credentials through the app after the stack is healthy.

Verify the result:

```bash
docker compose ps
curl -fsS http://127.0.0.1:8090/api/health
docker compose logs --tail=100 pocketbase
```

For a public HTTPS endpoint, point a DNS name at the VPS and configure Caddy,
or use the documented `sslip.io`/native-Caddy path in the public deployment
scripts. PocketBase should remain behind Caddy rather than being exposed
directly.

This path provides a public self-hosted Docker deployment. It does not receive
the same NixOS image lifecycle, OS upgrade/rollback guarantees, or live-suite
support as the recommended NixOS path. The signed NixOS release-manager
lifecycle is specific to the NixOS path below.

## Path B: NixOS without Aeroform (recommended)

The public repository contains the NixOS image and bootstrap source. This is
the deployment path exercised by the VPS suite and used by the supported Pro
provisioning flow. The image is the OS layer; first boot then resolves the
signed PocketCoder release and installs the Compose application.

Build the image on an x86_64 Linux/Nix builder:

```bash
cd deploy/nixos
nix build .#linode-image
```

The result is a raw image under `result/`. Install that image onto a provider
VPS using the provider's documented custom-image, rescue, or raw-disk method.
The repository's `deploy/nixos/stackscripts/pocketcoder-image-installer.sh` is
an optional Linode-specific disk writer; it is not required by the NixOS
configuration and is not the general deployment interface.

Before first boot, provide the equivalent of the protected
`/var/lib/pocketcoder-bootstrap-env` file with mode `0600`:

```text
root_ssh_key=<single-line-authorized-public-key>
POCKETCODER_RELEASE_CHANNEL=stable
POCKETCODER_RELEASE_DIGEST=<64-hex-signed-release-digest>
POCKETCODER_RELEASE_SEQUENCE=<positive-channel-sequence>
POCKETCODER_SELECTED_HARNESSES=goose
```

The exact digest and sequence must come from the signed channel pointer and
manifest you have reviewed. Never invent them or copy private credentials into
the image. On first boot, `pocketcoder-bootstrap.service` verifies the release,
runs `pocketcoder-release install`, configures Caddy, and starts the Compose
stack. It retries interrupted first installs and fails closed if owner config
or the SSH key is missing.

After boot:

```bash
systemctl status pocketcoder-bootstrap.service
systemctl status caddy.service
/opt/pocketcoder/current/bin/pocketcoder-release status
curl -fsS http://127.0.0.1:8090/api/health
```

The public NixOS configuration exposes only SSH, HTTP, and HTTPS. The
PocketCoder control commands are reached by SSH and execute locally as root;
they are not a PocketCoder HTTP API.

## Manual operations after deployment

Run these over an authenticated SSH session as root. Review the command and
its expected interruption before executing it:

```bash
/opt/pocketcoder/current/bin/pocketcoder-release status
/opt/pocketcoder/current/bin/pocketcoder-release backup-data
/opt/pocketcoder/current/bin/pocketcoder-release update
/opt/pocketcoder/current/bin/pocketcoder-release restart-pocketcoder
/opt/pocketcoder/current/bin/pocketcoder-release update-os
/opt/pocketcoder/current/bin/pocketcoder-release restart-os
```

Use `rollback` or `rollback-os` only when the corresponding health/recovery
conditions permit it. A successful data-version-changing application release
intentionally prevents an unsafe normal application rollback.

## Verification

The same phases used to validate the managed deployment are public in
`deploy/release-manager/tests/vps/`:

```bash
bash deploy/release-manager/tests/vps/self-test.sh
```

The real VPS suite is `run-vps-suite.sh`. It is provider-agnostic after a VPS
provisioner supplies a machine and SSH handoff, and it checks topology,
release status, backup/restore, restart, update, reboot, NixOS compatibility,
and recovery behavior. Aeroform is one provisioning adapter; it is not a
runtime dependency of the deployed PocketCoder server.
