#!/bin/sh
set -eu

runtime_env=/var/lib/pocketcoder/config/runtime.env
bootstrap_config=/var/lib/pocketcoder/config/bootstrap.json
release_state=/var/lib/pocketcoder/release
artifact_dir=/var/lib/pocketcoder/artifacts
status_file=/var/lib/pocketcoder/public/status.json
run_id=$(cat /proc/sys/kernel/random/uuid)
source_commit=unknown
current_phase=installing_host
heartbeat_pid=
failure_reported=0
release_stage=

status() {
  current_phase=$1
  detail=${2:-}
  error=${3:-}
  status_tmp="$status_file.tmp.$$"
  jq -n --arg runId "$run_id" --arg phase "$current_phase" \
    --arg detail "$detail" --arg sourceCommit "$source_commit" \
    --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg error "$error" \
    '{schema:1,runId:$runId,phase:$phase,
      detail:(if $detail == "" then null else $detail end),
      sourceCommit:$sourceCommit,updatedAt:$updatedAt,
      error:(if $error == "" then null else $error end)}' > "$status_tmp"
  chmod 0644 "$status_tmp"
  mv -f "$status_tmp" "$status_file"
}

fail_bootstrap() {
  status "$1" failed "$2"
  failure_reported=1
  exit 1
}

heartbeat_start() {
  (while :; do sleep 60; status "$current_phase" working; done) &
  heartbeat_pid=$!
}

heartbeat_stop() {
  if [ -n "$heartbeat_pid" ]; then
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
    heartbeat_pid=
  fi
}

cleanup() {
  rc=$?
  heartbeat_stop
  if [ -n "$release_stage" ] && [ -d "$release_stage" ]; then
    rm -rf "$release_stage"
  fi
  if [ "$rc" -ne 0 ] && [ "$failure_reported" -ne 1 ]; then
    status "$current_phase" failed bootstrap_failed
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

install -d -m 0755 /var/lib/pocketcoder/public /var/lib/pocketcoder/release/manifests
install -d -m 0700 /var/lib/pocketcoder/config /var/lib/pocketcoder/artifacts
install -d -m 0755 /opt/pocketcoder/releases
status installing_host

# POCO:BEGIN bootstrap-owner-config
# The app delivers owner credentials inside cloud-init, while Aeroform handles
# the host packages and firewall. The SSH key is moved into OpenSSH's protected
# file and removed from the application environment before containers start.
install -d -m 0700 /root/.ssh
root_ssh_key=$(sed -n 's/^root_ssh_key=//p' "$runtime_env")
test -n "$root_ssh_key"
printf '%s\n' "$root_ssh_key" > /root/.ssh/authorized_keys
chmod 0600 /root/.ssh/authorized_keys
sed -i '/^root_ssh_key=/d' "$runtime_env"
# POCO:END bootstrap-owner-config

# POCO:BEGIN bootstrap-release-source
# Resolve a mutable discovery pointer once, then use the immutable manifest and
# its checksum to acquire the exact deployment snapshot for this release.
if ! jq -e '
  .schemaVersion == 1 and
  (.requestedCommit == "main" or
    (.requestedCommit | test("^[0-9a-f]{40}$"))) and
  (.selectedHarnesses | type == "array" and length > 0) and
  all(.selectedHarnesses[]; test("^[a-z0-9]+(?:-[a-z0-9]+)*$"))
' "$bootstrap_config" >/dev/null; then
  fail_bootstrap installing_host bootstrap_config_invalid
fi
requested_commit=$(jq -r '.requestedCommit' "$bootstrap_config")
release_base=${RELEASE_BASE:-https://images.pocketcoder.org}
if [ "$requested_commit" = main ]; then
  discovery_url="$release_base/release-manifest.json"
else
  discovery_url="$release_base/release-$requested_commit.json"
fi
manifest_candidate="$artifact_dir/release-manifest.$$.json"
status fetching_release
heartbeat_start
if ! curl -sfL --max-time 30 -o "$manifest_candidate" "$discovery_url"; then
  fail_bootstrap fetching_release release_manifest_unavailable
fi

resolved_commit=$(jq -r '.release // empty' "$manifest_candidate")
case "$resolved_commit" in
  *[!0-9a-f]* | '')
    fail_bootstrap fetching_release release_manifest_identity_invalid
    ;;
esac
if [ "${#resolved_commit}" -ne 40 ]; then
  fail_bootstrap fetching_release release_manifest_identity_invalid
fi
if [ "$requested_commit" != main ] && [ "$requested_commit" != "$resolved_commit" ]; then
  fail_bootstrap fetching_release release_manifest_identity_mismatch
fi
source_commit=$resolved_commit
immutable_url="$release_base/release-$resolved_commit.json"
if [ "$discovery_url" != "$immutable_url" ]; then
  if ! curl -sfL --max-time 30 -o "$manifest_candidate" "$immutable_url"; then
    fail_bootstrap fetching_release immutable_release_manifest_unavailable
  fi
  if [ "$(jq -r '.release // empty' "$manifest_candidate")" != "$resolved_commit" ]; then
    fail_bootstrap fetching_release immutable_release_manifest_mismatch
  fi
fi

deployment_url=$(jq -r '.deployment.url // empty' "$manifest_candidate")
deployment_sha256=$(jq -r '.deployment.sha256 // empty' "$manifest_candidate")
deployment_bytes=$(jq -r '.deployment.bytes // empty' "$manifest_candidate")
deployment_expanded=$(jq -r '.deployment.expandedBytes // empty' "$manifest_candidate")
test -n "$deployment_url"
test -n "$deployment_sha256"
if ! jq -e '
  . as $manifest |
  ($manifest.deployment.bytes |
    type == "number" and . == floor and . > 0) and
  ($manifest.deployment.expandedBytes |
    type == "number" and . == floor and
    . >= $manifest.deployment.bytes) and
  ($manifest.deployment.sha256 | test("^[0-9a-f]{64}$")) and
  ($manifest.deployment.url | startswith("https://"))
' "$manifest_candidate" >/dev/null; then
  fail_bootstrap fetching_release deployment_artifact_metadata_invalid
fi
deployment_file="$artifact_dir/$resolved_commit-deployment.tar.gz.part.$$"
required_blocks=$(((deployment_bytes + deployment_expanded + 1073741824 + 1023) / 1024))
available_blocks=$(df -Pk "$artifact_dir" | awk 'NR == 2 {print $4}')
if [ -z "$available_blocks" ] || [ "$available_blocks" -lt "$required_blocks" ]; then
  fail_bootstrap fetching_release release_artifact_disk_headroom_insufficient
fi
status fetching_release downloading:deployment
if ! curl -fL --retry 3 --retry-delay 2 --max-time 1200 \
  -o "$deployment_file" "$deployment_url"; then
  fail_bootstrap fetching_release deployment_artifact_download_failed
fi
if [ "$(wc -c < "$deployment_file" | tr -d ' ')" -ne "$deployment_bytes" ]; then
  fail_bootstrap fetching_release deployment_artifact_size_mismatch
fi
if [ "$(sha256sum "$deployment_file" | cut -d' ' -f1)" != "$deployment_sha256" ]; then
  fail_bootstrap fetching_release deployment_artifact_checksum_mismatch
fi
if tar -tzf "$deployment_file" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  fail_bootstrap fetching_release deployment_artifact_path_invalid
fi

release_dir="/opt/pocketcoder/releases/$resolved_commit"
release_stage="$release_dir.stage.$$"
if [ ! -d "$release_dir" ]; then
  install -d -m 0755 "$release_stage"
  tar -xzf "$deployment_file" -C "$release_stage"
  if [ "$(jq -r '.release // empty' "$release_stage/release.json")" != "$resolved_commit" ]; then
    fail_bootstrap fetching_release deployment_snapshot_identity_mismatch
  fi
  mv "$release_stage" "$release_dir"
  release_stage=
fi
rm -f "$deployment_file"
heartbeat_stop
# POCO:END bootstrap-release-source

selected_harnesses=$(jq -r '.selectedHarnesses[]' "$bootstrap_config")
# Harness IDs are validated in Dart and contain no shell metacharacters.
# shellcheck disable=SC2086
set -- $selected_harnesses
if ! "$release_dir/deploy/scripts/activate-release.sh" \
  "$manifest_candidate" "$immutable_url" "$runtime_env" "$release_state" \
  "$artifact_dir" "$run_id" "$status_file" "$@"; then
  failure_reported=1
  exit 1
fi

trap - EXIT HUP INT TERM
