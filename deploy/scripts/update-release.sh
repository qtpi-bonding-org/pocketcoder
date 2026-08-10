#!/bin/sh
set -eu

release_base=${RELEASE_BASE:-https://images.pocketcoder.org}
releases_dir=${POCKETCODER_RELEASES_DIR:-/opt/pocketcoder/releases}
release_state=${POCKETCODER_RELEASE_STATE_DIR:-/var/lib/pocketcoder/release}
artifact_dir=${POCKETCODER_ARTIFACT_DIR:-/var/lib/pocketcoder/artifacts}
status_file=${POCKETCODER_STATUS_FILE:-/var/lib/pocketcoder/public/status.json}
current_link=${POCKETCODER_CURRENT_LINK:-/opt/pocketcoder/current}
runtime_env=${POCKETCODER_RUNTIME_ENV:-/var/lib/pocketcoder/config/runtime.env}
release_stage=
manifest_candidate=
deployment_file=

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
  if [ -n "$manifest_candidate" ]; then
    rm -f "$manifest_candidate"
  fi
  if [ -n "$deployment_file" ]; then
    rm -f "$deployment_file"
  fi
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

install -d -m 0755 "$releases_dir" "$release_state/manifests" \
  "$(dirname -- "$status_file")"
install -d -m 0700 "$artifact_dir"

# Resolve the public pointer once, then pin every remaining operation to the
# immutable manifest named by its exact source commit.
manifest_candidate="$artifact_dir/update-manifest.$$.json"
curl -sfL --max-time 30 -o "$manifest_candidate" \
  "$release_base/release-manifest.json"
release=$(jq -r '.release // empty' "$manifest_candidate")
case "$release" in
  *[!0-9a-f]* | '')
    echo "Release pointer contains an invalid commit" >&2
    exit 1
    ;;
esac
if [ "${#release}" -ne 40 ]; then
  echo "Release pointer contains an invalid commit" >&2
  exit 1
fi

immutable_url="$release_base/release-$release.json"
curl -sfL --max-time 30 -o "$manifest_candidate" "$immutable_url"
if [ "$(jq -r '.release // empty' "$manifest_candidate")" != "$release" ]; then
  echo "Immutable release manifest identity does not match its pointer" >&2
  exit 1
fi

current_release=
if [ -f "$release_state/current.json" ]; then
  current_release=$(jq -r '.release // empty' "$release_state/current.json")
elif [ -f "$current_link/release.json" ]; then
  current_release=$(jq -r '.release // empty' "$current_link/release.json")
fi
if [ "$current_release" = "$release" ]; then
  echo "PocketCoder is already running release $release"
  exit 0
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
  exit 1
fi

echo "Downloading verified PocketCoder release $release"
curl -fL --retry 3 --retry-delay 2 --max-time 1200 \
  -o "$deployment_file" "$deployment_url"
if [ "$(wc -c < "$deployment_file" | tr -d ' ')" -ne "$deployment_bytes" ]; then
  echo "Deployment artifact size does not match its manifest" >&2
  exit 1
fi
if [ "$(sha256sum "$deployment_file" | cut -d' ' -f1)" != "$deployment_sha256" ]; then
  echo "Deployment artifact checksum does not match its manifest" >&2
  exit 1
fi
if tar -tzf "$deployment_file" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  echo "Deployment artifact contains an unsafe path" >&2
  exit 1
fi

release_dir="$releases_dir/$release"
release_stage="$release_dir.stage.$$"
if [ ! -d "$release_dir" ]; then
  install -d -m 0755 "$release_stage"
  tar -xzf "$deployment_file" -C "$release_stage"
  if [ "$(jq -r '.release // empty' "$release_stage/release.json")" != "$release" ]; then
    echo "Deployment snapshot identity does not match its release" >&2
    exit 1
  fi
  mv "$release_stage" "$release_dir"
  release_stage=
fi
rm -f "$deployment_file"
deployment_file=

selected_harnesses=$(sed -n 's/^POCKETCODER_SELECTED_HARNESSES=//p' "$runtime_env")
selected_harnesses=${selected_harnesses:-goose}
# Harness identifiers are validated by the release activator and contain no
# shell metacharacters. Splitting commas supplies its one-argument-per-harness API.
set -f
old_ifs=$IFS
IFS=,
# shellcheck disable=SC2086
set -- $selected_harnesses
IFS=$old_ifs
set +f

run_id="update-$(date -u +%Y%m%dT%H%M%SZ)-$$"
echo "Activating release $release without changing workspace or auth volumes"
"$release_dir/deploy/scripts/activate-release.sh" \
  "$manifest_candidate" "$immutable_url" "$runtime_env" "$release_state" \
  "$artifact_dir" "$run_id" "$status_file" "$@"
manifest_candidate=

trap - EXIT HUP INT TERM
echo "PocketCoder update complete: $release"
