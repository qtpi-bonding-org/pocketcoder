. "$VPS_DIR/lib/common.sh"
. "$VPS_DIR/lib/commands.sh"

phase_stub_dir="$TEST_TMP/phasebin"
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

# --- 10-provision: vps_provision's stdout must be ONLY the handoff path ---
# Regression test for a bug found live: tee's passthrough copy went to
# stdout, so the whole flutter test log leaked into $handoff when the
# orchestrator captures this function via `handoff=$(vps_provision ...)`.
. "$VPS_DIR/lib/guards.sh"
. "$VPS_DIR/lib/teardown.sh"
. "$VPS_DIR/phases/10-provision.sh"

fake_aeroform="$TEST_TMP/fake-aeroform"
mkdir -p "$fake_aeroform/test/integration"
: > "$fake_aeroform/test/integration/golden_path_provision_test.dart"

fake_handoff="$TEST_TMP/fake-handoff.json"
echo '{"hostname":"example.test"}' > "$fake_handoff"

stub_bin "$phase_stub_dir" flutter "
echo 'noisy line one of test output'
echo 'noisy line two of test output'
echo 'VPS SCRIPT: retained update handoff $fake_handoff'
echo 'noisy trailing diagnostics line'
"

provision_run_dir="$TEST_TMP/provision-run"
mkdir -p "$provision_run_dir"

result=$(
  FLUTTER_BIN="$phase_stub_dir/flutter" AEROFORM_ROOT="$fake_aeroform" \
    PATH="$phase_stub_dir:$PATH" \
    vps_provision "$TEST_TMP" "$provision_run_dir" "test-provision-label"
)
check "vps_provision: stdout is exactly the handoff path, not the log" "$fake_handoff" "$result"
