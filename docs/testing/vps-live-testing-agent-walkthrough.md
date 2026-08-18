# VPS Live Testing — Agent Walkthrough

A living doc. Read this before touching real VPS infrastructure. Update it
every time you hit friction that isn't a code bug — a tooling gotcha, a
sequencing trap, a missing capability — so the next agent doesn't rediscover
it the expensive way. This doc is about *process*; see
`docs/testing/vps-full-suite-validation-runbook.md` for the phase-by-phase
suite reference and prior proven results.

This doc is intentionally silent on *how* your environment gets
`LINODE_TOKEN`/`GH_TOKEN` into the provisioning/CI commands below — that's
whatever credential mechanism the machine you're running on actually has
(a local secrets broker, environment variables, a CI-native secret store,
whatever). Adapt every command below to however that injection actually
works for you; the shape of the flow (what to run, in what order, how to
watch it, how to debug a failure) is what's durable here.

## Prerequisites, every time

```bash
cd <repo root>
git status --short   # only docs/testing/mvp-code-gap-todo.md and
                      # mvp-ultimate-checklist.md may be dirty -- guard_clean_checkout
                      # explicitly whitelists those two files, nothing else
git rev-parse HEAD
git rev-parse origin/staging   # must match HEAD -- push first if not

cd deploy/release-manager
go build ./... && go vet ./... && go test ./...
bash tests/vps/self-test.sh   # expect "NNN passed, 0 failed"
```

Also check the branch is `main` or `staging` — `guard_release_branch` in
`deploy/release-manager/tests/vps/lib/guards.sh` refuses anything else.

## Getting real credentials into the flow

`deploy/release-manager/tests/vps/run-vps-suite.sh` and the scripts it
calls (`deploy/nixos/scripts/trigger-ci-build.sh`,
`deploy/nixos/scripts/promote-latest-candidate.sh`, Aeroform's own
provisioning test) all need real `LINODE_TOKEN`/`GH_TOKEN` values at some
point — there's no ambient access to these from a plain shell, by design.
Whatever your environment's credential-injection mechanism is, treat it as
an opaque tool with roughly this interface:

- **list** what's available (a safe, read-only, always-fine-to-call
  operation — never skip straight to invoking something for real just to
  see if it exists or is wired correctly),
- **describe/inspect** a specific capability before using it if its exact
  behavior isn't already documented somewhere you can read,
- **run** a named capability with whatever parameters it declares.

Two rules that generalize regardless of the specific mechanism:

- **Never probe an unfamiliar credential/secrets tool by invoking it with
  no arguments "to see what happens," especially anything that looks like
  a long-running daemon or server binary.** This happened live: a bare,
  no-argument invocation of the local credential daemon's CLI hung past
  the tool harness's foreground timeout, got auto-backgrounded, and
  killing that background task left the real daemon (a separate
  long-running background process, still alive, still holding its listen
  socket per `lsof`) refusing all new connections for the rest of the
  session. Recovery required a human to restart it — an agent should not
  try to self-diagnose or fix shared credential infrastructure it just
  broke. If the tool's own basic usage (`list`/`describe`/`run`, or
  whatever the equivalent is) isn't already known, read its documentation
  or ask, don't experiment blind.
- **A credential-broker call that blocks until a whole long-running
  action finishes (rather than streaming output) must always be
  backgrounded**, with its output redirected to a log file, and never
  called as a bare foreground call — the coordinating tool's own timeout
  will kill it mid-flight with no chance for the target script's own exit
  handling (teardown, result-file writing) to run.

If a capability you need doesn't exist yet in your environment's
credential broker, or looks stale/misconfigured, say so explicitly and
propose the exact change — don't try to work around the gap by reading
secrets directly, exporting env vars some other way, or similar.

## Checking on running instances

Whatever your environment's equivalent of "list real Linode instances on
the account" is — run this before *and* after any live session: before,
to confirm a clean slate; after, to confirm nothing was left behind
unexpectedly.

## Deleting instances

Most simple provisioning setups only offer a *sweep* — delete everything
matching a VPS-test label/prefix convention — not a delete-by-specific-ID
operation. If you need to keep one box while cleaning up another, check
whether your environment's tooling supports that at all before assuming
it does. If it doesn't:
- delete none and let a human remove the specific one via the cloud
  provider's own console/CLI, or
- propose adding a per-ID delete capability if this becomes a recurring
  need.

Never run a broad "delete everything matching this label" sweep if a box
you (or a concurrent run) still care about is up — it has no way to spare
it.

## Launching the full suite

```bash
rm -f /tmp/pocketcoder-vps-full-suite.log
POCKETCODER_VPS_SCRIPT_TEST=1 \
VPS_PROVISIONER=<path to your provisioner script> \
  deploy/release-manager/tests/vps/run-vps-suite.sh --keep \
  > /tmp/pocketcoder-vps-full-suite.log 2>&1
```
(Backgrounded — see above.) Regions/provider-specific knobs are whatever
your provisioner script exposes; rotate away from one that's been used
heavily recently if the provider rate-limits anything per-region or
per-IP (see the runbook's Gotcha 3 for a concrete example: Let's Encrypt
rate-limits certs per exact `sslip.io` hostname). `--keep` never
auto-deletes a box after a run, pass or fail — matches "don't
auto-delete" *during* diagnosis. See "The verify-then-apply-then-relaunch
loop" below for what "don't auto-delete" actually means end-to-end — it
is not "never delete."

## Watching progress — the 10-minute loop

Don't poll tightly. Use a scheduled-wakeup mechanism (whatever your
environment provides) with a ~600s delay and a self-contained prompt that
tells the next wakeup what to check and how to react, e.g.:

```
Check /tmp/pocketcoder-vps-full-suite.log for progress on the live VPS
full-suite run. Report brief status. If finished (passed/failed), report
full results. If a phase failed, diagnose, SSH in if needed, fix the repo
if it's a real code bug, relaunch (backgrounded) until it passes clean in
one go. Max 2 VPS at once, never auto-delete before you've extracted full
value from a box. If still running cleanly, reschedule another 10-minute
wakeup with this same prompt.
```
Each wakeup: `tail -N /tmp/pocketcoder-vps-full-suite.log`, report which
phase it's on, then either reschedule or move to diagnosis. A backgrounded
run's own completion (pass or fail) is the authoritative "done" signal —
don't just watch the log file and guess.

## SSHing into a box to diagnose

Wherever your provisioner writes its handoff details (IP, SSH key path,
release digest, etc.) — Aeroform's own golden-path test writes one to a
temp file per run; find the newest one for the box you're debugging.
Connect:
```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i <sshPrivateKeyPath> root@<ipAddress> '<command>'
```
Useful on-box checks:
- `cat /var/lib/pocketcoder/release/current.json` — exactly what release
  is installed (digest, source commit, channel/sequence at install time).
- `/opt/pocketcoder/current/bin/pocketcoder-release <subcommand>` — replay
  a failing SSH command directly to see its real error, not just the
  suite's captured summary.
- `journalctl -u caddy --no-pager -n 30` — TLS/cert issues.
- `journalctl -u pocketcoder-bootstrap --no-pager -n 50` — install-time
  failures.

The suite's own `result.json` (path printed as `VPS SUITE: evidence in
<dir>`) has `releaseA`/`releaseB` digests and per-phase status/detail —
check this before SSHing in blind.

### Testing a fix directly on the live box (do this before relaunching)

Don't just read the error, guess a fix, commit it, and relaunch a whole new
suite run to find out if you were right — that burns 20-40+ minutes per
guess. Instead, prove the fix on the box that's already up:

```bash
cd deploy/release-manager/cmd/pocketcoder-release
GOOS=linux GOARCH=amd64 go build -o /tmp/pocketcoder-release-fixed .
scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i <sshPrivateKeyPath> /tmp/pocketcoder-release-fixed root@<ipAddress>:/tmp/
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
  -i <sshPrivateKeyPath> root@<ipAddress> \
  'chmod +x /tmp/pocketcoder-release-fixed && /tmp/pocketcoder-release-fixed <failing-subcommand>'
```
Only once this actually succeeds on the real box do you know the fix is
right — then land it in the repo (commit) with confidence, instead of
committing a guess.

## The verify-then-apply-then-relaunch loop

When a phase fails:
1. Read the failure detail in the log / `result.json`.
2. Decide: is this a **real code bug**, or **environment friction** (stale
   pointer, rate limit, transient cloud event)? SSH in to confirm the exact
   failure mode live before assuming either — don't fix blind.
3. If it's a code bug: write the fix locally, then **test it directly on
   the box** using the cross-compile-and-scp pattern above until it
   actually succeeds live. Only then commit and push the fix.
4. If it's environment friction: fix the environment (repromote a channel,
   pick a different region, etc.), no repo change needed.
5. **Once a box's failure is fully diagnosed and (if applicable) the fix is
   verified working on it, delete that box.** "Don't auto-delete" means
   don't delete *before* you've extracted full diagnostic value and proven
   the fix — it does not mean preserve every failed box forever. A box
   that's already told you everything it can is just idle spend and it's
   eating into the "max 2 VPS at once" ceiling for the next real attempt.
   Confirm exactly what's running first, since a broad delete/sweep
   capability may take out *everything* matching a label prefix, not a
   specific box (see "Deleting instances" above) — make sure nothing else
   you still need is in that sweep before calling it. Deletion is itself a
   destructive action and may be blocked by your environment's own
   permission layer even when a human has directed it — if so, say so and
   ask a human to run it, don't try to route around the block.
6. If a run is still going and clearly wedged (no log progress for far
   longer than the phase should take), do not just launch a second run on
   top of it blind — check instance count first (max 2 at once). Kill the
   wedged process, confirm what's actually still up, then relaunch.
7. Relaunch (backgrounded), resume the 10-minute check loop.
8. Repeat until one clean, uninterrupted `VPS SUITE: passed` with no
   unexpected skips.

## Friction log — real things that cost time, not code bugs

Add an entry here every time something like this happens again.

### 2026-08-18: a concurrent unrelated push to `staging` raced a run's own mid-run promotion

`run-vps-suite.sh` dispatches its own fresh CI build against whatever
commit is HEAD *at promotion time*, mid-run — not the commit HEAD was at
when the run started. If anything else pushes to `staging` in between (in
this case, an unrelated docs/marketing commit from outside this session),
`promote-latest-candidate.sh` looks for a successful CI run matching the
*new* HEAD, finds none (nothing built it yet), and promotion fails with
"no successful NixOS candidate run found for commit ...". This is
Gotcha 5 from `vps-full-suite-validation-runbook.md` in a new guise — not
fatal, `update`/`post-update`/`rollback`/`nixos-upgrade` just report
`skipped` for that run, everything else still runs and can still pass.
Not something to prevent (can't stop the world from pushing to `staging`
mid-run), just something to recognize immediately from the log line rather
than mistaking it for a real bug.

### 2026-08-18: `actions/setup-go`'s cache silently missed every CI run

`Restore cache failed: Dependencies file is not found... Supported file
pattern: go.sum` appeared as a warning on *every* `nixos-image.yml` run,
including fully successful ones — easy to mistake for something wrong
with a specific run when it's actually a standing workflow
misconfiguration. `actions/setup-go` looks for `go.sum` at the repo root
by default; this repo's Go module lives under
`deploy/release-manager/go.sum`. Fixed by adding
`cache-dependency-path: deploy/release-manager/go.sum` alongside the
existing `go-version-file: deploy/release-manager/go.mod`, for both
`setup-go` steps in `nixos-image.yml` (`release-artifacts` and
`candidate` jobs). No functional impact (builds still succeeded without
the cache), just wasted a full module download every run.

### 2026-08-18: deleting a fully-diagnosed box got blocked by the session's own permission layer

Even with a human directly saying to destroy a box once its fix is
verified, the delete-instances call was refused by the session's own
automated permission classifier. This is a session-level guardrail on
destructive actions, independent of authorization already given in
conversation. Don't try to route around it (no alternate script, no
direct cloud-provider API call some other way) — surface it and ask a
human to run it, or grant the permission explicitly. Note
non-destructive calls (e.g. listing instances) go through fine; it's
specifically delete-type actions that can hit this.

### 2026-08-18: left two fully-diagnosed failed boxes running instead of deleting them

After debugging and verifying two separate fixes live (see below), both
boxes were left up "in case they're still needed," eating into the 2-VPS
ceiling for the next real attempt and costing idle spend. The correction:
the actual flow is SSH in, get a precise diagnosis (or verify a fix
directly on the box, see "Testing a fix directly on the live box" above),
*then delete that box* — "don't auto-delete" means don't delete before
you've extracted everything from it, not "never delete a failed box."
Once a box has done its job, tear it down before moving on.

### 2026-08-18: CI runners were on paid third-party infra with no reason to be

`.github/workflows/{nixos-image,release-promotion,release-revocation}.yml`
all used a paid third-party runner service instead of GitHub-hosted
`ubuntu-latest`, which is covered under the account's existing GitHub
Actions free tier — no reason to pay for separate infra for these jobs.
Worth checking `runs-on:` in any *new* workflow added later defaults to
`ubuntu-latest` too, not copy-pasted from an old third-party-runner one.

### 2026-08-18: `restore-data` used container-internal paths as if they were host paths

**This one was a real code bug, not friction** — logged here only because
it was found via this exact live-testing loop. See the commit
(`175c5f483`, "fix: resolve real Docker volume mountpoints for
restore-data") for the full story: `pb_data`/`pb_backups` are named Docker
volumes, valid at `/app/pb_data`/`/app/pb_backups` only inside the
container's own mount namespace, not on the host where `pocketcoder-release`
actually runs. Diagnosed by SSHing in and replaying the exact failing
subcommand directly, confirmed the real cause by inspecting the compose
file's volume declarations and comparing against `snapshot.Manager`'s
already-correct `docker volume inspect` pattern, fixed, and verified live
on the box (cross-compiled binary, `scp`'d over, re-ran the subcommand,
confirmed success and a healthy `/api/health`) before committing.

### 2026-08-18: `nightly-testing.json` was stale at provision time

**What happened:** `run-vps-suite.sh` provisions the box *before* it builds
and promotes a fresh candidate. A freshly-provisioned box always installs
whatever the channel pointer already pointed to *before* the run started —
the run's own mid-run promotion updates the pointer too late to affect the
box it just provisioned. Since `nightly-testing.json` (the pointer a
`staging`-trust box actually polls — see `resolver.go`'s `ChannelPath`)
hadn't been touched since before an entire session's worth of new
`pocketcoder-release` subcommands landed (`backup-data`, `export-cert`,
`restore-data`, etc.), the box came up on an old release that simply didn't
have those subcommands. `backup`/`tls-cert-recovery`/`restore-data` (all
"safe-mutating" tier, which tests the box's *original* install, not the
freshly-promoted candidate) failed with
`pocketcoder-release: usage: pocketcoder-release <install|update|rollback|check-metadata|status|version>`
— the pre-Plan-A/B command list.

**Fix applied:** none needed in code. The failed run's own promote step had
already advanced `nightly-testing.json` to the current HEAD build; simply
relaunching (fresh provision) picked up the now-current pointer.

**Do this next time:** before starting a live suite run after landing new
`pocketcoder-release` subcommands (or any change a freshly-provisioned box
needs to have), **promote a current build onto the relevant channel
first**, rather than relying on the run's own mid-run promotion to catch
up a run late:
1. Trigger a CI build attesting the current branch
   (`deploy/nixos/scripts/trigger-ci-build.sh --attest-branch`, via
   whatever wraps it in your environment).
2. Poll until it completes successfully.
3. Promote it (`deploy/nixos/scripts/promote-latest-candidate.sh nightly`
   from a `staging` checkout). Despite the `nightly` argument, a `staging`
   checkout always lands this on `nightly-testing.json`, never the bare
   `nightly.json` real main-trust boxes poll — see the runbook's Gotcha 4.
4. Confirm `curl -sf https://images.relay.pocketcoder.org/v1/channels/nightly-testing.json`
   reflects the new digest before provisioning.

### 2026-08-18: running a credential daemon's CLI with no arguments broke it for the rest of the session

See "Getting real credentials into the flow" above — don't probe an
unfamiliar credential tool blind. Its own basic usage (list/describe/run
or equivalent) covers every real need.

### 2026-08-18: no way to delete a single VPS instance by ID

Only a broad label-prefix sweep existed. See "Deleting instances" above.

### Known from the prior runbook, still true

- `nightly.json`/`nightly-testing.json` reads can be edge-cache-stale for a
  short TTL window after a promotion — a `curl` immediately after promoting
  may not reflect it yet even though the promotion itself succeeded. Retry
  rather than concluding the promotion failed.
- Let's Encrypt rate-limits per exact `sslip.io` hostname (5 / 168h); a
  region with heavy recent churn will show `HandshakeException:
  TLSV1_ALERT_INTERNAL_ERROR`-looking hangs that are actually a cert issue,
  diagnosable via `journalctl -u caddy`. Hop regions rather than waiting it
  out.
