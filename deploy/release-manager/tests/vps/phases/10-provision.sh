# Not a tiered phase: the orchestrator calls vps_provision directly, before
# host-key pinning and before instance tracking can be recorded.

vps_provision() {
  local repo_root=$1 run_dir=$2 label=$3
  local provisioner provision_log handoff_json

  provisioner=$(resolve_provisioner) || return 1
  provision_log="$run_dir/provision.log"

  # The label is recorded BEFORE provisioning so a crash mid-create still
  # leaves teardown something precise to sweep.
  teardown_set_label "$label"

  handoff_json=$(AEROFORM_INSTANCE_LABEL="$label" "$provisioner" 2>"$provision_log")
  local rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$handoff_json" ]; then
    echo "provisioner failed (exit $rc); see $provision_log" >&2
    cat "$provision_log" >&2
    return 1
  fi

  if ! printf '%s' "$handoff_json" | jq -e \
    '.instanceId and .ipAddress and .hostname and .sshPrivateKeyPath and .releaseDigest' \
    >/dev/null 2>&1; then
    echo "provisioner produced invalid handoff JSON: $handoff_json" >&2
    return 1
  fi

  printf '%s' "$handoff_json"
}
