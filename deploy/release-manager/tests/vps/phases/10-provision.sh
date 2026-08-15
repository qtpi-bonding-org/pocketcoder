# Not a tiered phase: the orchestrator calls vps_provision directly, before
# host-key pinning and before instance tracking can be recorded.

vps_provision() {
  local repo_root=$1 run_dir=$2 label=$3
  local flutter_bin aeroform_root provision_log handoff

  flutter_bin=$(resolve_flutter_bin) || return 1
  aeroform_root=$(resolve_aeroform_root "$repo_root") || return 1
  provision_log="$run_dir/provision.log"

  # The label is recorded BEFORE provisioning so a crash mid-create still
  # leaves teardown something precise to sweep.
  teardown_set_label "$label"

  # vps_provision is called as `handoff=$(vps_provision ...)` by the
  # orchestrator, so anything this function writes to its own stdout
  # becomes part of $handoff. tee's passthrough copy must go to stderr
  # (or be discarded), never stdout, or the flutter test's entire log ends
  # up appended to the handoff path -- confirmed live: it silently
  # corrupted $handoff into megabytes of log text plus the real path, and
  # every downstream jq/file lookup failed on it.
  ( cd "$aeroform_root" &&
    env AEROFORM_VPS_SCRIPT_TEST=1 \
      AEROFORM_KEEP_INSTANCE=1 \
      AEROFORM_GOLDEN_PATH_BACKEND=nixos \
      AEROFORM_INSTANCE_LABEL="$label" \
      "$flutter_bin" test test/integration/golden_path_provision_test.dart ) \
    2>&1 | tee "$provision_log" >&2

  handoff=$(sed -n 's/^VPS SCRIPT: retained update handoff //p' "$provision_log" | tail -1)
  if [ -z "$handoff" ] || [ ! -f "$handoff" ]; then
    echo "provisioning did not produce an update handoff" >&2
    return 1
  fi
  printf '%s' "$handoff"
}
