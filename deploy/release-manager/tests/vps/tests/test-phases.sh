. "$VPS_DIR/lib/common.sh"

phase_stub_dir="$TEST_TMP/phasebin"

# Keep phase tests offline: replace the production Dart dispatcher with a
# transport stub while preserving each command's expected SSH payload.
dispatch_ssh_command() {
  case $1 in
    saveBackup) ssh_exec 300 'docker exec pocketcoder-pocketbase /app/backup_db.sh' ;;
    restartPocketCoder) ssh_exec 300 'docker compose restart' ;;
    updatePocketCoder) ssh_exec 3600 'if [ -x /opt/pocketcoder/current/bin/pocketcoder-release ]; then /opt/pocketcoder/current/bin/pocketcoder-release update; else exit 1; fi' ;;
    restartNixOs) ssh_exec 30 'systemctl reboot' ;;
    updateNixOs) ssh_exec 1800 'nixos-rebuild switch --upgrade' ;;
    *) return 1 ;;
  esac
}
vps_connect 203.0.113.10 "$TEST_TMP/key" "$TEST_TMP/known_hosts"
: > "$TEST_TMP/key"
VPS_HOSTNAME=vps.example.test

# --- 40-backup: the freshness assertion is the point ---
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case $last in
  *backup_db.sh*) echo "backup written" ;;
  *"stat -c %Y"*) echo "${STUB_BACKUP_MTIME:-9999999999}" ;;
  *sha256sum*) echo "abc123def4567890abc123def4567890abc123def4567890abc123def4567890  /app/pb_backups/data.db" ;;
  *integrity_check*) echo ok ;;
  *) echo "" ;;
esac'

( . "$VPS_DIR/phases/40-backup.sh"
  PATH="$phase_stub_dir:$PATH" VPS_PHASE_STARTED=1000 \
    STUB_BACKUP_MTIME=2000 phase_run >/dev/null 2>&1 )
check_rc "40-backup: fresh artifact passes" 0 "$?"

( . "$VPS_DIR/phases/40-backup.sh"
  PATH="$phase_stub_dir:$PATH" VPS_PHASE_STARTED=5000 \
    STUB_BACKUP_MTIME=1000 phase_run >/dev/null 2>&1 )
check_rc "40-backup: STALE artifact fails" 1 "$?"

( . "$VPS_DIR/phases/40-backup.sh"; echo "$phase_tier" ) > "$TEST_TMP/tier40"
check "40-backup: is safe-mutating, not disruptive" "safe-mutating" "$(cat "$TEST_TMP/tier40")"

# --- 20-topology: an unhealthy container must fail ---
stub_bin "$phase_stub_dir" curl 'exit 0'
stub_bin "$phase_stub_dir" openssl 'echo'
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case $last in
  *State.Health.Status*) echo "${STUB_HEALTH:-healthy}" ;;
  *169.254.169.254*) exit "${STUB_METADATA_RC:-1}" ;;
  *is-enabled*) echo enabled ;;
  *RandomizedDelaySec*) echo "RandomizedDelaySec=1h" ;;
  *) echo "" ;;
esac'

( . "$VPS_DIR/phases/20-topology.sh"
  PATH="$phase_stub_dir:$PATH" STUB_HEALTH=unhealthy phase_run >/dev/null 2>&1 )
check_rc "20-topology: an unhealthy container fails" 1 "$?"

# Reachable cloud metadata is a firewall breach and must fail.
( . "$VPS_DIR/phases/20-topology.sh"
  PATH="$phase_stub_dir:$PATH" STUB_METADATA_RC=0 phase_run >/dev/null 2>&1 )
check_rc "20-topology: reachable cloud metadata fails" 1 "$?"

# --- 80-reboot: the false-pass regression test (finding F1) ---
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case $last in
  *systemctl\ reboot*) exit 255 ;;
  *random/boot_id*) echo "${STUB_BOOT_ID:-boot-after}" ;;
  *State.Health.Status*) echo healthy ;;
  *) echo "" ;;
esac'
stub_bin "$phase_stub_dir" curl 'exit 0'

( . "$VPS_DIR/phases/80-reboot.sh"
  PATH="$phase_stub_dir:$PATH" VPS_REBOOT_DEADLINE=5 \
    STUB_BOOT_ID=boot-before VPS_BOOT_ID_BEFORE_OVERRIDE=boot-before \
    phase_run >/dev/null 2>&1 )
check_rc "80-reboot: UNCHANGED boot_id fails (F1 regression)" 1 "$?"

( . "$VPS_DIR/phases/80-reboot.sh"
  PATH="$phase_stub_dir:$PATH" VPS_REBOOT_DEADLINE=5 \
    STUB_BOOT_ID=boot-after VPS_BOOT_ID_BEFORE_OVERRIDE=boot-before \
    phase_run >/dev/null 2>&1 )
check_rc "80-reboot: changed boot_id passes despite the dropped connection" 0 "$?"

# --- 50-restart-stack: unchanged StartedAt must fail ---
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case $last in
  *State.StartedAt*) echo "${STUB_STARTED_AT:-2026-08-15T10:00:00Z}" ;;
  *State.Health.Status*) echo healthy ;;
  *) echo "" ;;
esac'

( . "$VPS_DIR/phases/50-restart-stack.sh"
  PATH="$phase_stub_dir:$PATH" STUB_STARTED_AT=2026-08-15T09:00:00Z \
    phase_run >/dev/null 2>&1 )
check_rc "50-restart-stack: unchanged StartedAt fails" 1 "$?"

# --- 90-nixos-update: absent configuration.nix skips with 78, not fails ---
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case $last in
  *"test -f /etc/nixos/configuration.nix"*) exit 1 ;;
  *) echo "" ;;
esac'

( . "$VPS_DIR/phases/90-nixos-update.sh"
  PATH="$phase_stub_dir:$PATH" phase_run >/dev/null 2>&1 )
check_rc "90-nixos-update: absent config skips with 78 (F9)" 78 "$?"

. "$VPS_DIR/phases/70-post-update.sh"

# The precondition must read ON-BOX state, so `--only post-update` against an
# un-updated box is well-defined rather than silently wrong.
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case $last in
  *current.json*) echo "{\"releaseDigest\":\"${STUB_DIGEST:-aaa}\"}" ;;
  *) echo "" ;;
esac'

VPS_RELEASE_B_DIGEST=bbb
reason=$(PATH="$phase_stub_dir:$PATH" STUB_DIGEST=aaa phase_precondition)
check_rc "70-post-update: skips when the box has not been updated" 1 "$?"
check_contains "70-post-update: states why it skipped" "release B" "$reason"

PATH="$phase_stub_dir:$PATH" STUB_DIGEST=bbb phase_precondition >/dev/null
check_rc "70-post-update: runs when the box already reports release B" 0 "$?"

# --- 70-post-update: metadata-status.json's rollback field is only ever
# set when status is "update-available" (BuildMetadataStatus never sets it
# for "current") -- confirmed live: a box freshly updated to the newest
# release reports "current" with no rollback field, which is correct, not
# a missing-data failure. ---
vps_connect 203.0.113.10 "$TEST_TMP/key" "$TEST_TMP/known_hosts"
: > "$TEST_TMP/key"
VPS_HOSTNAME=vps.example.test
stub_bin "$phase_stub_dir" curl 'exit 0'
stub_bin "$phase_stub_dir" openssl 'echo'
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
case $last in
  *State.Health.Status*) echo healthy ;;
  *data.db*) echo "" ;;
  *sha256sum*) echo "deadbeef  /opt/pocketcoder/current/bin/pocketcoder-release" ;;
  *release-metadata.service*) echo "" ;;
  *metadata-status.json*) echo "$STUB_METADATA" ;;
  *) echo "" ;;
esac'

( . "$VPS_DIR/phases/70-post-update.sh"
  PATH="$phase_stub_dir:$PATH" STUB_METADATA='{"status":"current"}' \
    phase_run >/dev/null 2>&1 )
check_rc "70-post-update: status=current passes without a rollback field" 0 "$?"

( . "$VPS_DIR/phases/70-post-update.sh"
  PATH="$phase_stub_dir:$PATH" \
    STUB_METADATA='{"status":"update-available","normalRollbackAvailableAfterSuccess":true}' \
    phase_run >/dev/null 2>&1 )
check_rc "70-post-update: status=update-available with the field passes" 0 "$?"

( . "$VPS_DIR/phases/70-post-update.sh"
  PATH="$phase_stub_dir:$PATH" \
    STUB_METADATA='{"status":"update-available"}' \
    phase_run >/dev/null 2>&1 )
check_rc "70-post-update: status=update-available without the field fails" 1 "$?"

# --- 10-provision: vps_provision's stdout must be ONLY the handoff JSON ---
# Regression test for a bug found live: tee's passthrough copy went to
# stdout, so the whole flutter test log leaked into $handoff when the
# orchestrator captures this function via `handoff=$(vps_provision ...)`.
. "$VPS_DIR/lib/guards.sh"
. "$VPS_DIR/lib/teardown.sh"
. "$VPS_DIR/phases/10-provision.sh"

provisioner="$TEST_TMP/fake-provisioner"
stub_bin "$TEST_TMP" fake-provisioner "
echo 'noisy line one of test output' >&2
echo 'noisy line two of test output' >&2
printf '%s' '{\"instanceId\":\"instance-1\",\"ipAddress\":\"192.0.2.1\",\"hostname\":\"example.test\",\"sshPrivateKeyPath\":\"/tmp/key\",\"releaseDigest\":\"digest-1\"}'
"

provision_run_dir="$TEST_TMP/provision-run"
mkdir -p "$provision_run_dir"

result=$(
  VPS_PROVISIONER="$provisioner" \
    vps_provision "$TEST_TMP" "$provision_run_dir" "test-provision-label"
)
check "vps_provision: stdout is exactly the handoff JSON, not the log" \
  '{"instanceId":"instance-1","ipAddress":"192.0.2.1","hostname":"example.test","sshPrivateKeyPath":"/tmp/key","releaseDigest":"digest-1"}' "$result"

# --- 10-provision: the checked-out branch is forwarded to the provisioner ---
# Regression test for a bug found live: the provisioner had no way to know
# which branch pocketcoder was on, so golden_path_provision_test.dart always
# provisioned from the bare (production) nightly channel regardless of
# branch -- a staging run could never dry-run against the branch-isolated
# nightly-testing channel the way 55-promote.sh already does.
branch_repo="$TEST_TMP/branch-repo"
mkdir -p "$branch_repo"
git -C "$branch_repo" init -q
git -C "$branch_repo" checkout -q -b staging
stub_bin "$TEST_TMP" branch-capturing-provisioner "
printf '%s' \"\$POCKETCODER_GITHUB_WORKFLOW_BRANCH\" > '$TEST_TMP/captured-branch'
printf '%s' '{\"instanceId\":\"instance-1\",\"ipAddress\":\"192.0.2.1\",\"hostname\":\"example.test\",\"sshPrivateKeyPath\":\"/tmp/key\",\"releaseDigest\":\"digest-1\"}'
"
VPS_PROVISIONER="$TEST_TMP/branch-capturing-provisioner" \
  vps_provision "$branch_repo" "$provision_run_dir" "test-provision-label-2" >/dev/null
check "vps_provision: forwards the checked-out branch to the provisioner" \
  "staging" "$(cat "$TEST_TMP/captured-branch")"

# --- 60-update: the remote command must actually be valid shell (F-live) ---
# Regression test for a bug found live: `VAR=val <compound-command>` is
# invalid bash syntax when the shipped command is an `if` statement, not a
# simple command -- `bash -c "VAR=val if ...; then ...; fi"` fails with
# "syntax error near unexpected token `then'". This ran successfully in
# self-test before ever being validated live, because nothing checked that
# the assembled remote command actually parses.
stub_bin "$phase_stub_dir" ssh '
for arg in "$@"; do last=$arg; done
printf "%s" "$last" > "'"$TEST_TMP"'/captured-update-command"
case $last in
  *pocketcoder-release\ update*) echo "" ;;
  *current.json*) echo "{\"releaseDigest\":\"deadbeef\",\"sourceCommit\":\"abc\",\"channel\":\"nightly\",\"channelSequence\":\"3\"}" ;;
  *"readlink /opt/pocketcoder/current"*) echo "/opt/pocketcoder/releases/deadbeef" ;;
  *) echo "" ;;
esac'

( . "$VPS_DIR/phases/60-update.sh"
  PATH="$phase_stub_dir:$PATH" VPS_RELEASE_B_DIGEST=deadbeef \
    VPS_RELEASE_B_SOURCE_COMMIT=abc VPS_RELEASE_B_SEQUENCE=3 VPS_RELEASE_BRANCH=staging \
    phase_run >/dev/null 2>&1 )
check_rc "60-update: happy path passes" 0 "$?"
check_rc "60-update: the assembled remote command is valid shell" 0 \
  "$(bash -n "$TEST_TMP/captured-update-command" >/dev/null 2>&1; echo $?)"
