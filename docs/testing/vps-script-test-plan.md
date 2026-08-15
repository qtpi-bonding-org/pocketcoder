# PocketCoder VPS Script Test Suite

This plan defines the single real-VPS verification run to complete before
Flutter iOS/Android E2E. It tests the NixOS deployment created by Aeroform,
the deployed PocketCoder stack, and the owner controls exposed by the app.

This is a verification suite, not a second deployment implementation. It
should reuse the existing provision and update paths:

- `deploy/release-manager/tests/vps/run-vps-suite.sh` (the single orchestrator;
  see below)
- Aeroform's `golden_path_provision_test.dart`
- the deployed native `pocketcoder-release` command

Standard Linux is out of scope for this suite. The launch path under test is
NixOS.

## Terminology and where this fits

The codebase previously called every test that hits a real external system
(instead of Docker/mocks) a "live" test. That collided in practice with
Flutter E2E — both are "real" tests against a real backend, and the shared
word made it easy to conflate a scripted VPS test with UI-driven E2E
automation. This suite (and its siblings) now use **"VPS script test"**
instead: a scripted driver (shell/Go) that provisions or drives a real VPS,
as opposed to Flutter E2E, which drives the app UI. The rename applies to
code — script filenames, env vars, build tags, secrets-daemon action names —
not to existing prose in older docs, which may still say "live" until
touched.

[`VPS_SCRIPT_TEST_EXECUTION.md`](../../VPS_SCRIPT_TEST_EXECUTION.md) (repo root) documents the first two VPS
script test layers: Aeroform host provisioning
(`golden_path_provision_test.dart`, gated by `AEROFORM_VPS_SCRIPT_TEST=1`)
and the PocketCoder Standard Linux acceptance test. This suite is the
**third layer** — it assumes provisioning already succeeded and verifies the
deployed PocketCoder stack's health and owner-control operations. It should
be cross-linked from that doc once implemented, not left to be discovered
separately.

The suite runs as a scripted driver (shell/Go, following the
`run-vps-script-nixos-*.sh` pattern), not as a `pocketcoder_pro` Flutter
integration test. `pocketcoder_pro` and its VPS-script-test driver files
(`standard_linux_vps_script_test.dart`,
`ssh_server_update_service_live_test.dart`) do not exist on `main` yet —
they exist only in the `ui-chat-ux` worktree — so Phases 3 and 4's "test
driver first, Flutter E2E later" means: a script that calls the same
underlying operation a `RootSshCommand` triggers, not an existing Flutter
test harness.

The single entrypoint is
[`deploy/release-manager/tests/vps/run-vps-suite.sh`](../../deploy/release-manager/tests/vps/run-vps-suite.sh).
It provisions the disposable VPS itself (unless pointed at a retained
handoff via `--handoff`), then runs every phase tier-by-tier
(`readonly` → `safe-mutating` → `disruptive`), tearing the instance down on
exit. The three legacy script names
(`run-vps-script-suite.sh`, `run-vps-script-nixos-upgrade-test.sh`,
`run-vps-script-nixos-update-test.sh`) have been removed — there is no
compatibility shim, and both secrets-daemon actions
(`run_vps_script_nixos_upgrade_test`, `run_vps_script_nixos_full_suite`) now
invoke the orchestrator directly. Every invocation requires
`POCKETCODER_VPS_SCRIPT_TEST=1` and writes a JSON result (schema v2) into its
run directory, which is never deleted.

The old upgrade-test script promoted a candidate release B inline (querying
the GitHub Actions API and image-relay for a new attested nightly) before
invoking the update path. That promotion logic is now ported into the
orchestrator as `phases/55-promote.sh` — a non-tiered helper (like
`10-provision.sh`) that the orchestrator calls directly, before the
disruptive tier, whenever `update` or `post-update` is selected and
`VPS_RELEASE_B_DIGEST` is not already set: it triggers a fresh CI build for
the checked-out commit, waits for it, promotes it to the `nightly` channel,
and waits for the public channel pointer to actually serve it before setting
`VPS_RELEASE_B_DIGEST`/`VPS_RELEASE_B_SOURCE_COMMIT`/`VPS_RELEASE_B_SEQUENCE`
for `60-update`/`70-post-update` to consume. `run_vps_script_nixos_full_suite`
no longer skips `update`/`post-update`.

Example invocation after Aeroform has retained its handoff:

```sh
POCKETCODER_VPS_SCRIPT_TEST=1 \
  deploy/release-manager/tests/vps/run-vps-suite.sh --handoff /path/to/handoff.json --keep
```

Pass `--only`/`--skip` (comma-separated phase names) to select a subset, and
`--reap-orphans` to clean up a stale VPS-script instance from a prior crashed
run before continuing.

## Important distinction

The existing live upgrade test proves that the installed native release
manager updates PocketCoder from release A to release B and leaves the stack
healthy. It does not prove the user-facing backup operation.

The release-manager Docker tests prove internal snapshot/rollback recovery.
They do not prove that a real VPS backup can be created and recovered through
the owner control path.

## Preconditions

- The suite is gated behind an explicit opt-in env var, following the
  existing `AEROFORM_VPS_SCRIPT_TEST=1` convention (e.g.
  `POCKETCODER_VPS_SCRIPT_TEST=1`) — it must never run as a side effect of a
  normal test invocation.
- Core and Pro checkouts are clean and on the intended remote commits.
- GitHub-attested release artifacts and the channel pointer are available.
- The test runs against a disposable NixOS VPS created by Aeroform.
- Linode and GitHub credentials are injected only through the secrets daemon.
- The run refuses to start if another live-test VPS exists.
- The run records a JSON result and always deletes the disposable VPS and local
  temporary credentials in its exit trap.
- No Docker Desktop stop, global Docker prune, or unrelated container cleanup
  is allowed.

## Phase 1 — Provision the disposable VPS

Reuse the existing Aeroform golden-path provisioning flow and retain its
handoff temporarily. Record:

- instance ID, IP address, hostname, and SSH host identity;
- provisioned release digest, source commit, channel, and sequence;
- the generated root SSH credential handoff path;
- the selected deployment configuration.

Assertions:

- the server is NixOS;
- the signed release was resolved before activation;
- the PocketCoder stack starts;
- the HTTPS hostname is reachable;
- `/api/health` succeeds.

## Phase 2 — Read-only deployed-stack checks

Run these before any control operation:

- HTTPS reaches the expected VPS using the hostname and certificate path;
- PocketBase health returns success;
- public compatibility reports the expected schema and API versions;
- authenticated release status reports the active release and metadata status;
- Pocket Memory reports ready.

The following former VPS checks are superseded by faster, deterministic local
coverage and are no longer Phase 2 VPS requirements:

- Memory MCP create/read/account isolation: `tests/compose/memory/memory.bats:61`;
- MCP gateway tool authorization: `tests/compose/agent/`;
- harness authentication flows: `server/pocketbase/internal/api/harness_auth_test.go`.

The remaining deployed-stack checks are implemented by the
[`deploy/release-manager/tests/vps/`](../../deploy/release-manager/tests/vps/)
suite. This keeps the VPS run focused on deployment, networking, and
production-like operational behavior rather than duplicating local service
tests.

Read-only failures stop the suite before disruptive operations.

## Phase 3 — Safe operational checks

Run through the same typed owner-control boundary used by Pro
(`RootSshCommand` in
`client/packages/pocketcoder_flutter/lib/domain/os_control/root_ssh_command.dart`),
using a test driver first and Flutter E2E later:

- release inspection returns the active release;
- typed `saveBackup` creates a timestamped, checksum-verifiable artifact;
- the backup artifact is visible at the documented recovery location;
- a disposable restore check proves the artifact is readable and does not
  modify the live database;
- release-manager health/recovery metadata is consistent with the active
  release.

The backup check must prove the actual backup command and artifact, not merely
the release manager's internal rollback snapshot.

## Phase 4 — PocketCoder restart

This phase is explicitly disruptive and independently gated:

- invoke typed `RootSshCommand.restartPocketCoder`;
- expect a short connectivity interruption;
- poll HTTPS and PocketBase health until the service returns;
- confirm compatibility and release status still match the pre-restart
  release;
- confirm Memory and MCP gateway health return.

If restart does not recover within the bounded timeout, stop and preserve the
result for diagnosis. Do not continue to update or reboot the VPS.

## Phase 5 — PocketCoder update

Implemented as the orchestrator's `60-update` and `70-post-update` phases.
Release B promotion itself (selecting a distinct attested candidate) is the
known gap noted above — until it is ported, these phases only run when the
caller has already set `VPS_RELEASE_B_DIGEST`/`VPS_RELEASE_B_SOURCE_COMMIT`/
`VPS_RELEASE_B_SEQUENCE`:

- record release A metadata;
- promote or select a distinct attested release B;
- invoke typed `RootSshCommand.updatePocketCoder` (the installed native
  updater);
- confirm release B digest, source commit, channel, sequence, and symlink;
- confirm PocketBase health, compatibility, release status, Memory, MCP, and
  the Compose stack after activation;
- confirm the backup artifact from Phase 3 remains available;
- record whether normal rollback is allowed across the data-version boundary.

## Phase 6 — Optional NixOS restart/update

Run only when explicitly enabled:

- invoke typed `RootSshCommand.restartNixOs`;
- wait for SSH and HTTPS recovery;
- verify the same release and service health;
- optionally invoke typed `RootSshCommand.updateNixOs`;
- verify the NixOS generation and PocketCoder stack recover.

The suite must treat a NixOS update as a separate opt-in operation. It must not
silently run because it can exceed the normal PocketCoder restart risk.

## Results and cleanup

The suite writes one machine-readable result containing:

- suite version and Git commits;
- VPS instance ID and provider region;
- release A/B identity;
- each phase's start time, end time, and status;
- backup artifact checksum and recovery result;
- restart/update/reboot recovery durations;
- failure phase and bounded diagnostic output.

On success, delete the disposable VPS and remove local temporary keys and
handoffs. On failure, preserve the result JSON and relevant bounded logs,
attempt cleanup, and report whether cleanup succeeded. Never delete unrelated
instances, volumes, containers, or Docker data.

## Exit criteria before Flutter E2E

- All read-only checks pass against the real VPS.
- The local Memory MCP, MCP gateway authorization, and harness-auth coverage
  listed in Phase 2 passes; the VPS suite does not duplicate those checks.
- Real backup creation and read-only recovery pass.
- PocketCoder restart and post-restart health pass.
- PocketCoder A → B update and post-update health pass.
- Optional NixOS phases either pass or are explicitly recorded as deferred.
- Cleanup succeeds and the result JSON is retained as evidence.
