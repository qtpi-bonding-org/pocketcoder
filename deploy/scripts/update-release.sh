#!/bin/sh
set -eu

operation=${1:-update}
case "$operation" in update | rollback) ;; *) echo "usage: $0 [update|rollback]" >&2; exit 1 ;; esac

release_base=${RELEASE_BASE:-https://images.relay.pocketcoder.org}
releases_dir=${POCKETCODER_RELEASES_DIR:-/opt/pocketcoder/releases}
release_state=${POCKETCODER_RELEASE_STATE_DIR:-/var/lib/pocketcoder/release}
artifact_dir=${POCKETCODER_ARTIFACT_DIR:-/var/lib/pocketcoder/artifacts}
status_file=${POCKETCODER_STATUS_FILE:-/var/lib/pocketcoder/public/status.json}
current_link=${POCKETCODER_CURRENT_LINK:-/opt/pocketcoder/current}
runtime_env=${POCKETCODER_RUNTIME_ENV:-/var/lib/pocketcoder/config/runtime.env}
release_stage=
manifest_candidate=
deployment_file=
activation_manifest=
harness_file=
saved_pointer=
saved_previous=
previous_existed=0
include_ollama=0

if [ ! -f "$runtime_env" ] && [ -f /opt/pocketcoder/.env ]; then
  runtime_env=/opt/pocketcoder/.env
fi
if [ ! -f "$runtime_env" ]; then
  echo "PocketCoder runtime environment was not found" >&2
  exit 1
fi

cleanup() {
  rc=$?
  if [ -n "$release_stage" ] && [ -d "$release_stage" ]; then
    rm -rf "$release_stage"
  fi
  for temporary in "$manifest_candidate" "$deployment_file" \
    "$activation_manifest" "$harness_file" "$saved_pointer" \
    "$saved_previous"; do
    [ -n "$temporary" ] && rm -f "$temporary"
  done
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

install -d -m 0755 "$releases_dir" "$release_state/manifests" \
  "$(dirname -- "$status_file")"
install -d -m 0700 "$artifact_dir"

valid_release() {
  candidate=$1
  case "$candidate" in *[!0-9a-f]* | '') return 1 ;; esac
  [ "${#candidate}" -eq 40 ]
}

pointer_release() {
  pointer_file=$1
  [ -f "$pointer_file" ] || return 1
  pointer_value=$(jq -r '.release // empty' "$pointer_file")
  valid_release "$pointer_value" || return 1
  printf '%s\n' "$pointer_value"
}

install_harness_set() {
  install_release_dir=$1
  install_manifest=$2
  install_run_id=$3
  set --
  while IFS= read -r harness_id; do
    [ -n "$harness_id" ] || continue
    set -- "$@" "$harness_id"
  done < "$harness_file"
  if [ "$#" -eq 0 ]; then
    echo "No valid harness selection is available" >&2
    return 1
  fi
  POCKETCODER_INCLUDE_OLLAMA="$include_ollama" \
  "$install_release_dir/deploy/scripts/install-release-images.sh" \
    "$install_manifest" "$install_release_dir/deploy/release/harnesses.json" \
    "$artifact_dir" "$install_run_id" "$status_file" "$@"
}

activate_tree() {
  activate_release_dir=$1
  activate_manifest_source=$2
  activate_manifest_url=$3
  activate_run_id=$4
  activation_manifest="$artifact_dir/activate-manifest.$$.json"
  cp "$activate_manifest_source" "$activation_manifest"
  set --
  while IFS= read -r harness_id; do
    [ -n "$harness_id" ] || continue
    set -- "$@" "$harness_id"
  done < "$harness_file"
  POCKETCODER_ENABLE_OLLAMA="$include_ollama" \
  "$activate_release_dir/deploy/scripts/activate-release.sh" \
    "$activation_manifest" "$activate_manifest_url" "$runtime_env" \
    "$release_state" "$artifact_dir" "$activate_run_id" "$status_file" "$@"
  activation_manifest=
}

restore_release() {
  restore_pointer=$1
  restore_release_id=$(jq -r '.release // empty' "$restore_pointer")
  valid_release "$restore_release_id" || return 1
  restore_dir="$releases_dir/$restore_release_id"
  restore_manifest="$release_state/manifests/$restore_release_id.json"
  [ -d "$restore_dir" ] && [ -f "$restore_manifest" ] || return 1
  echo "Restoring PocketCoder release $restore_release_id"
  install_harness_set "$restore_dir" "$restore_manifest" \
    "restore-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  activate_tree "$restore_dir" "$restore_manifest" \
    "$(jq -r '.manifestUrl' "$restore_pointer")" \
    "restore-$(date -u +%Y%m%dT%H%M%SZ)-$$"
}

restore_previous_pointer() {
  if [ "$previous_existed" -eq 1 ]; then
    previous_tmp="$release_state/previous.json.tmp.$$"
    cp "$saved_previous" "$previous_tmp"
    chmod 0644 "$previous_tmp"
    mv -f "$previous_tmp" "$release_state/previous.json"
  else
    rm -f "$release_state/previous.json"
  fi
}

cleanup_retention() {
  cleanup_script="$current_link/deploy/scripts/cleanup-old-releases.sh"
  if [ -x "$cleanup_script" ]; then
    if ! "$cleanup_script" "$release_state" "$releases_dir"; then
      echo "Release activation succeeded, but old-release cleanup was incomplete" >&2
    fi
  fi
}

run_update() {
  manifest_candidate="$artifact_dir/update-manifest.$$.json"
  curl -sfL --max-time 30 -o "$manifest_candidate" \
    "$release_base/release-manifest.json"
  release=$(jq -r '.release // empty' "$manifest_candidate")
  if ! valid_release "$release"; then
    echo "Release pointer contains an invalid commit" >&2
    return 1
  fi

  immutable_url="$release_base/release-$release.json"
  curl -sfL --max-time 30 -o "$manifest_candidate" "$immutable_url"
  if [ "$(jq -r '.release // empty' "$manifest_candidate")" != "$release" ]; then
    echo "Immutable release manifest identity does not match its pointer" >&2
    return 1
  fi

  current_release=
  if current_release=$(pointer_release "$release_state/current.json"); then :; else current_release=; fi
  if [ "$current_release" = "$release" ]; then
    echo "PocketCoder is already running release $release"
    return 0
  fi

  script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
  catalog="$script_dir/../release/harnesses.json"
  "$script_dir/validate-release-contract.sh" "$manifest_candidate" "$catalog"

  deployment_url=$(jq -r '.deployment.url' "$manifest_candidate")
  deployment_sha256=$(jq -r '.deployment.sha256' "$manifest_candidate")
  deployment_bytes=$(jq -r '.deployment.bytes' "$manifest_candidate")
  deployment_expanded=$(jq -r '.deployment.expandedBytes' "$manifest_candidate")
  deployment_file="$artifact_dir/$release-deployment.tar.gz.part.$$"
  required_blocks=$(((deployment_bytes + deployment_expanded + 1073741824 + 1023) / 1024))
  available_blocks=$(df -Pk "$artifact_dir" | awk 'NR == 2 {print $4}')
  if [ -z "$available_blocks" ] || [ "$available_blocks" -lt "$required_blocks" ]; then
    echo "Not enough disk space to safely stage the release" >&2
    return 1
  fi

  echo "Downloading verified PocketCoder release $release"
  curl -fL --retry 3 --retry-delay 2 --max-time 1200 \
    -o "$deployment_file" "$deployment_url"
  if [ "$(wc -c < "$deployment_file" | tr -d ' ')" -ne "$deployment_bytes" ]; then
    echo "Deployment artifact size does not match its manifest" >&2
    return 1
  fi
  if [ "$(sha256sum "$deployment_file" | cut -d' ' -f1)" != "$deployment_sha256" ]; then
    echo "Deployment artifact checksum does not match its manifest" >&2
    return 1
  fi
  if tar -tzf "$deployment_file" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
    echo "Deployment artifact contains an unsafe path" >&2
    return 1
  fi

  release_dir="$releases_dir/$release"
  release_stage="$release_dir.stage.$$"
  if [ ! -d "$release_dir" ]; then
    install -d -m 0755 "$release_stage"
    tar -xzf "$deployment_file" -C "$release_stage"
    if [ "$(jq -r '.release // empty' "$release_stage/release.json")" != "$release" ]; then
      echo "Deployment snapshot identity does not match its release" >&2
      return 1
    fi
    mv "$release_stage" "$release_dir"
    release_stage=
  fi
  rm -f "$deployment_file"
  deployment_file=

  harness_file="$artifact_dir/update-harnesses.$$.txt"
  if [ -n "$current_release" ] && [ -f "$release_state/manifests/$current_release.json" ]; then
    current_ollama_image=$(jq -r '.optional.ollama.images[0] // empty' \
      "$release_state/manifests/$current_release.json")
    if [ -n "$current_ollama_image" ] \
      && docker image inspect "$current_ollama_image" >/dev/null 2>&1; then
      include_ollama=1
    elif docker inspect pocketcoder-ollama >/dev/null 2>&1; then
      include_ollama=1
    fi
    "$release_dir/deploy/scripts/discover-release-harnesses.sh" \
      "$release_state/manifests/$current_release.json" \
      "$release_dir/deploy/release/harnesses.json" "$runtime_env" > "$harness_file"
  else
    "$release_dir/deploy/scripts/discover-release-harnesses.sh" \
      "$manifest_candidate" "$release_dir/deploy/release/harnesses.json" \
      "$runtime_env" > "$harness_file"
  fi

  # Finish every potentially slow download/load before interrupting a running
  # harness or switching the stable release path.
  install_harness_set "$release_dir" "$manifest_candidate" \
    "update-preload-$(date -u +%Y%m%dT%H%M%SZ)-$$"

  saved_pointer=
  if [ -n "$current_release" ] && [ -f "$release_state/current.json" ]; then
    saved_pointer="$artifact_dir/old-pointer.$$.json"
    cp "$release_state/current.json" "$saved_pointer"
    if [ -f "$release_state/previous.json" ]; then
      saved_previous="$artifact_dir/previous-pointer.$$.json"
      cp "$release_state/previous.json" "$saved_previous"
      previous_existed=1
    fi
    previous_tmp="$release_state/previous.json.tmp.$$"
    cp "$saved_pointer" "$previous_tmp"
    chmod 0644 "$previous_tmp"
    mv -f "$previous_tmp" "$release_state/previous.json"
    "$release_dir/deploy/scripts/remove-managed-release-containers.sh" \
      "$current_release" "$release_state/manifests/$current_release.json"
  fi

  run_id="update-$(date -u +%Y%m%dT%H%M%SZ)-$$"
  echo "Activating release $release without changing workspace or auth volumes"
  if ! activate_tree "$release_dir" "$manifest_candidate" "$immutable_url" "$run_id"; then
    echo "Release $release failed health/activation; rolling back" >&2
    if [ -n "$saved_pointer" ]; then
      "$release_dir/deploy/scripts/remove-managed-release-containers.sh" \
        "$release" "$manifest_candidate" || true
      if restore_release "$saved_pointer"; then
        echo "Rollback restored release $current_release" >&2
      else
        echo "Automatic rollback failed; manual recovery is required" >&2
      fi
      restore_previous_pointer
    fi
    return 1
  fi
  rm -f "$manifest_candidate"
  manifest_candidate=
  cleanup_retention
  echo "PocketCoder update complete: $release"
}

run_rollback() {
  current_pointer="$release_state/current.json"
  previous_pointer="$release_state/previous.json"
  current_release=$(pointer_release "$current_pointer") || {
    echo "Current release pointer is unavailable" >&2
    return 1
  }
  previous_release=$(pointer_release "$previous_pointer") || {
    echo "No previous PocketCoder release is available for rollback" >&2
    return 1
  }
  current_manifest="$release_state/manifests/$current_release.json"
  previous_manifest="$release_state/manifests/$previous_release.json"
  current_dir="$releases_dir/$current_release"
  previous_dir="$releases_dir/$previous_release"
  [ -f "$current_manifest" ] && [ -f "$previous_manifest" ] \
    && [ -d "$current_dir" ] && [ -d "$previous_dir" ] || {
      echo "Rollback release files are incomplete" >&2
      return 1
    }

  harness_file="$artifact_dir/rollback-harnesses.$$.txt"
  current_ollama_image=$(jq -r '.optional.ollama.images[0] // empty' "$current_manifest")
  if [ -n "$current_ollama_image" ] \
    && docker image inspect "$current_ollama_image" >/dev/null 2>&1; then
    include_ollama=1
  elif docker inspect pocketcoder-ollama >/dev/null 2>&1; then
    include_ollama=1
  fi
  "$current_dir/deploy/scripts/discover-release-harnesses.sh" \
    "$current_manifest" "$current_dir/deploy/release/harnesses.json" \
    "$runtime_env" > "$harness_file"
  install_harness_set "$previous_dir" "$previous_manifest" \
    "rollback-preload-$(date -u +%Y%m%dT%H%M%SZ)-$$"

  saved_pointer="$artifact_dir/forward-pointer.$$.json"
  cp "$current_pointer" "$saved_pointer"
  "$current_dir/deploy/scripts/remove-managed-release-containers.sh" \
    "$current_release" "$current_manifest"

  if ! activate_tree "$previous_dir" "$previous_manifest" \
    "$(jq -r '.manifestUrl' "$previous_pointer")" \
    "rollback-$(date -u +%Y%m%dT%H%M%SZ)-$$"; then
    echo "Rollback activation failed; restoring release $current_release" >&2
    if ! restore_release "$saved_pointer"; then
      echo "Forward recovery also failed; manual recovery is required" >&2
    fi
    return 1
  fi

  swapped_tmp="$release_state/previous.json.tmp.$$"
  cp "$saved_pointer" "$swapped_tmp"
  chmod 0644 "$swapped_tmp"
  mv -f "$swapped_tmp" "$release_state/previous.json"
  cleanup_retention
  echo "PocketCoder rollback complete: $previous_release"
}

if [ "$operation" = rollback ]; then
  run_rollback
else
  run_update
fi
