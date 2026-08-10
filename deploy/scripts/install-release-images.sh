#!/bin/sh
set -eu

manifest_file=${1:?release manifest file is required}
catalog_file=${2:?harness catalog file is required}
artifact_dir=${3:?artifact staging directory is required}
run_id=${4:?provisioning run ID is required}
status_file=${5:?status file is required}
phase_log=${POCKETCODER_PHASE_LOG:-/var/log/pocketcoder-bootstrap-phases.log}
shift 5

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
release=$(jq -r '.release // empty' "$manifest_file")
reserve_bytes=${POCKETCODER_DISK_RESERVE_BYTES:-1073741824}
resolved_file="$artifact_dir/.resolved-artifacts.$$"
current_file=

cleanup() {
  if [ -n "$current_file" ]; then
    rm -f "$current_file"
  fi
  rm -f "$resolved_file"
}
trap cleanup EXIT HUP INT TERM

write_status() {
  phase=$1
  detail=${2:-}
  error=${3:-}
  status_dir=$(dirname -- "$status_file")
  install -d -m 0755 "$status_dir"
  status_tmp="$status_file.tmp.$$"
  jq -n \
    --arg runId "$run_id" \
    --arg phase "$phase" \
    --arg detail "$detail" \
    --arg sourceCommit "$release" \
    --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg error "$error" \
    '{schema: 1, runId: $runId, phase: $phase,
      detail: (if $detail == "" then null else $detail end),
      sourceCommit: $sourceCommit, updatedAt: $updatedAt,
      error: (if $error == "" then null else $error end)}' \
    > "$status_tmp"
  chmod 0644 "$status_tmp"
  mv -f "$status_tmp" "$status_file"
  if [ -w "$phase_log" ]; then
    printf '%s phase=%s detail=%s sourceCommit=%s error=%s\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$phase" "$detail" "$release" "$error" \
      >> "$phase_log"
  fi
}

fail_artifact() {
  artifact_id=$1
  error=$2
  write_status loading_images "artifact:$artifact_id" "$error"
  echo "$error: $artifact_id" >&2
  exit 1
}

install -d -m 0700 "$artifact_dir"
"$script_dir/resolve-release-artifacts.sh" \
  "$manifest_file" "$catalog_file" "$@" \
  | jq -c '.[] | select(.kind != "deployment")' > "$resolved_file"

while IFS= read -r selected; do
  artifact_id=$(printf '%s' "$selected" | jq -r '.id')
  url=$(printf '%s' "$selected" | jq -r '.artifact.url')
  expected_sha256=$(printf '%s' "$selected" | jq -r '.artifact.sha256')
  expected_bytes=$(printf '%s' "$selected" | jq -r '.artifact.bytes')
  expanded_bytes=$(printf '%s' "$selected" | jq -r '.artifact.expandedBytes')
  required_blocks=$(((expected_bytes + expanded_bytes + reserve_bytes + 1023) / 1024))
  available_blocks=$(df -Pk "$artifact_dir" | awk 'NR == 2 {print $4}')
  if [ -z "$available_blocks" ] || [ "$available_blocks" -lt "$required_blocks" ]; then
    fail_artifact "$artifact_id" release_artifact_disk_headroom_insufficient
  fi

  current_file="$artifact_dir/$release-$artifact_id.tar.gz.part.$$"
  write_status loading_images "downloading:$artifact_id"
  if ! curl -fL --retry 3 --retry-delay 2 --max-time 1200 \
    -o "$current_file" "$url"; then
    fail_artifact "$artifact_id" release_artifact_download_failed
  fi
  actual_bytes=$(wc -c < "$current_file" | tr -d ' ')
  if [ "$actual_bytes" -ne "$expected_bytes" ]; then
    fail_artifact "$artifact_id" release_artifact_size_mismatch
  fi
  actual_sha256=$(sha256sum "$current_file" | cut -d' ' -f1)
  if [ "$actual_sha256" != "$expected_sha256" ]; then
    fail_artifact "$artifact_id" release_artifact_checksum_mismatch
  fi

  write_status loading_images "loading:$artifact_id"
  if ! gzip -dc "$current_file" | docker load >/dev/null; then
    fail_artifact "$artifact_id" release_artifact_load_failed
  fi
  printf '%s' "$selected" | jq -r '.artifact.images[]' | while IFS= read -r image; do
    if ! docker image inspect "$image" >/dev/null 2>&1; then
      fail_artifact "$artifact_id" release_artifact_image_missing
    fi
  done
  rm -f "$current_file"
  current_file=
  write_status loading_images "loaded:$artifact_id"
done < "$resolved_file"

trap - EXIT HUP INT TERM
rm -f "$resolved_file"
