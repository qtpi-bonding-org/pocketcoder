#!/bin/sh
set -eu

runtime_env=/var/lib/pocketcoder/config/runtime.env
bootstrap_config=/var/lib/pocketcoder/config/bootstrap.json
release_state=/var/lib/pocketcoder/release
artifact_dir=/var/lib/pocketcoder/artifacts
status_file=/var/lib/pocketcoder/public/status.json
phase_log=/var/log/pocketcoder-bootstrap-phases.log
run_id=$(cat /proc/sys/kernel/random/uuid)
source_commit=unknown
current_phase=configuring_operating_system
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
  printf '%s phase=%s detail=%s sourceCommit=%s error=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$current_phase" "$detail" \
    "$source_commit" "$error" >> "$phase_log"
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
install -d -m 0755 "$(dirname -- "$phase_log")"
touch "$phase_log"
chmod 0644 "$phase_log"
status configuring_operating_system

# POCO:BEGIN bootstrap-owner-config
# The app delivers owner credentials inside cloud-init, while Aeroform handles
# the OS packages and firewall. The SSH key is moved into OpenSSH's protected
# file and removed from the application environment before containers start.
install -d -m 0700 /root/.ssh
root_ssh_key=$(sed -n 's/^root_ssh_key=//p' "$runtime_env")
test -n "$root_ssh_key"
printf '%s\n' "$root_ssh_key" > /root/.ssh/authorized_keys
chmod 0600 /root/.ssh/authorized_keys
sed -i '/^root_ssh_key=/d' "$runtime_env"
# POCO:END bootstrap-owner-config

# POCO:BEGIN bootstrap-release-source
# Independently resolve and verify the signed release selected by the app, then
# acquire the exact deployment snapshot named by that immutable manifest.
if ! jq -e '
  .schemaVersion == 1 and
  (.releaseChannel | test("^(stable|beta|nightly)$")) and
  (.releaseDigest | test("^[0-9a-f]{64}$")) and
  (.channelSequence | type == "number" and . == floor and . > 0) and
  (.selectedHarnesses | type == "array" and length > 0) and
  all(.selectedHarnesses[]; test("^[a-z0-9]+(?:-[a-z0-9]+)*$"))
' "$bootstrap_config" >/dev/null; then
  fail_bootstrap configuring_operating_system bootstrap_config_invalid
fi
release_channel=$(jq -r '.releaseChannel' "$bootstrap_config")
expected_digest=$(jq -r '.releaseDigest' "$bootstrap_config")
expected_sequence=$(jq -r '.channelSequence' "$bootstrap_config")
release_base=${RELEASE_BASE:-https://images.pocketcoder.org}
resolver=/usr/local/lib/pocketcoder/release/resolve-signed-release.sh
verifier=/usr/local/lib/pocketcoder/release/verify-signed-payload.sh
root_public_key=/etc/pocketcoder/release-root.pem
test -x "$resolver" && test -x "$verifier" && test -s "$root_public_key" ||
  fail_bootstrap fetching_release release_trust_material_unavailable

resolution="$artifact_dir/release-resolution.$$.json"
manifest_candidate="$artifact_dir/release-manifest.$$.json"
status fetching_release
heartbeat_start
if ! RELEASE_BASE="$release_base" \
  POCKETCODER_ROOT_PUBLIC_KEY="$root_public_key" \
  POCKETCODER_VERIFY_SCRIPT="$verifier" \
  "$resolver" "$release_channel" "$release_state" \
    "$release_state/resolved" > "$resolution"; then
  fail_bootstrap fetching_release release_metadata_verification_failed
fi
resolved_digest=$(jq -r '.manifestSha256' "$resolution")
resolved_sequence=$(jq -r '.channelSequence' "$resolution")
if [ "$resolved_digest" != "$expected_digest" ] ||
    [ "$resolved_sequence" -lt "$expected_sequence" ]; then
  fail_bootstrap fetching_release release_selection_changed
fi
immutable_url=$(jq -r '.manifestUrl' "$resolution")
cp "$(jq -r '.manifestPath' "$resolution")" "$manifest_candidate"
export POCKETCODER_RELEASE_CHANNEL="$release_channel"
export POCKETCODER_CHANNEL_SEQUENCE="$resolved_sequence"
POCKETCODER_REVOCATION_SEQUENCE=$(jq -r '.revocationSequence' "$resolution")
export POCKETCODER_REVOCATION_SEQUENCE
rm -f "$resolution"

source_commit=$(jq -r '.sourceCommit' "$manifest_candidate")
deployment_url=$(jq -r '.serverFiles.url // empty' "$manifest_candidate")
deployment_sha256=$(jq -r '.serverFiles.sha256 // empty' "$manifest_candidate")
deployment_bytes=$(jq -r '.serverFiles.downloadBytes // empty' "$manifest_candidate")
deployment_expanded=$(jq -r '.serverFiles.unpackedBytes // empty' "$manifest_candidate")
test -n "$deployment_url"
test -n "$deployment_sha256"
if ! jq -e '
  . as $manifest |
  ($manifest.serverFiles.downloadBytes |
    type == "number" and . == floor and . > 0) and
  ($manifest.serverFiles.unpackedBytes |
    type == "number" and . == floor and
    . >= $manifest.serverFiles.downloadBytes) and
  ($manifest.serverFiles.sha256 | test("^[0-9a-f]{64}$"))
' "$manifest_candidate" >/dev/null; then
  fail_bootstrap fetching_release deployment_artifact_metadata_invalid
fi
if [ "$deployment_url" != "$release_base/v1/artifacts/$deployment_sha256.tar.gz" ]; then
  fail_bootstrap fetching_release deployment_artifact_url_invalid
fi
deployment_file="$artifact_dir/$deployment_sha256.tar.gz.part.$$"
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

release_dir="/opt/pocketcoder/releases/$resolved_digest"
release_stage="$release_dir.stage.$$"
if [ ! -d "$release_dir" ]; then
  install -d -m 0755 "$release_stage"
  tar -xzf "$deployment_file" -C "$release_stage"
  if ! jq -e --slurpfile manifest "$manifest_candidate" '
    .schemaVersion == 1 and
    .serverVersion == $manifest[0].serverVersion and
    .sourceCommit == $manifest[0].sourceCommit and
    .serverApiVersion == $manifest[0].compatibility.server.apiVersion and
    .dataVersion == $manifest[0].dataVersion and
    .deploymentContractVersion ==
      $manifest[0].compatibility.deployment.contractVersion
  ' "$release_stage/release.json" >/dev/null; then
    fail_bootstrap fetching_release deployment_snapshot_identity_mismatch
  fi
  mv "$release_stage" "$release_dir"
  release_stage=
fi
rm -f "$deployment_file"
heartbeat_stop
# POCO:END bootstrap-release-source

selected_harnesses=$(jq -r '.selectedHarnesses[]' "$bootstrap_config")
selected_harness_csv=$(printf '%s\n' "$selected_harnesses" | paste -sd, -)
if ! RELEASE_BASE="$release_base" \
  POCKETCODER_ROOT_PUBLIC_KEY="$root_public_key" \
  POCKETCODER_RELEASE_CHANNEL="$release_channel" \
  POCKETCODER_RELEASE_DIGEST="$expected_digest" \
  POCKETCODER_RELEASE_SEQUENCE="$expected_sequence" \
  POCKETCODER_SELECTED_HARNESSES="$selected_harness_csv" \
  POCKETCODER_RUNTIME_ENV="$runtime_env" \
  POCKETCODER_STATUS_FILE="$status_file" \
  POCKETCODER_STATUS_RUN_ID="$run_id" \
  PC_SOURCE_COMMIT="$source_commit" \
  "$release_dir/bin/pocketcoder-release" install; then
  # The native manager owns status reporting after this handoff, including
  # the exact phase and failure document. Preserve that richer status.
  failure_reported=1
  exit 1
fi
source_commit=$(jq -r '.sourceCommit' "$manifest_candidate")
status bootstrap_complete
"$release_dir/deploy/scripts/install-release-metadata-timer.sh"

trap - EXIT HUP INT TERM
