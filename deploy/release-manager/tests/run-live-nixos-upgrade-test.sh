#!/usr/bin/env bash
# A billed, end-to-end release test. It verifies the path a user actually
# takes: provision the current nightly release, then update that same NixOS
# VPS to a newly GitHub-attested nightly release using the installed native
# release manager. It requires LINODE_TOKEN and GH_TOKEN only through the
# secrets-daemon action that invokes it.
set -euo pipefail

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../../.." && pwd)
aeroform_root=${AEROFORM_ROOT:-"$repo_root/../flutter_aeroform"}
flutter_bin=${FLUTTER_BIN:-/Users/aicoder/develop/flutter/bin/flutter}
channel=${1:-nightly}
api=https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions
relay=https://images.relay.pocketcoder.org
work_dir=$(mktemp -d)
handoff=
key_path=
instance_created=false

require() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "required command is unavailable: $1" >&2
    exit 1
  }
}

cleanup() {
  status=$?
  if [ "$instance_created" = true ]; then
    "$aeroform_root/scripts/delete-orphaned-instances.sh" || true
  fi
  if [ -n "$key_path" ]; then
    rm -f "$key_path" "$key_path.pub"
  fi
  if [ -n "$handoff" ]; then
    rm -f "$handoff"
  fi
  rm -rf "$work_dir"
  exit "$status"
}
trap cleanup EXIT

case "$channel" in
  nightly) ;;
  *) echo "live upgrade test only permits the nightly channel" >&2; exit 64 ;;
esac
for command in curl git jq "$flutter_bin"; do require "$command"; done
test -d "$aeroform_root" || { echo "flutter_aeroform checkout is unavailable" >&2; exit 1; }
: "${LINODE_TOKEN:?LINODE_TOKEN must be injected by the secrets-daemon}"
: "${GH_TOKEN:?GH_TOKEN must be injected by the secrets-daemon}"

existing_live_instances=$(curl -fsSL \
  -H "Authorization: Bearer $LINODE_TOKEN" \
  https://api.linode.com/v4/linode/instances |
  jq '[.data[] | select(.label | startswith("nixos-live-"))] | length')
test "$existing_live_instances" -eq 0 || {
  echo "refusing to start while another NixOS live-test instance exists" >&2
  exit 1
}

cd "$repo_root"
test -z "$(git status --porcelain)" || {
  echo "live upgrade test requires a clean PocketCoder checkout" >&2
  exit 1
}
source_commit=$(git rev-parse HEAD)
remote_commit=$(git ls-remote origin refs/heads/main | awk '{print $1}')
test "$source_commit" = "$remote_commit" || {
  echo "local main is not the current remote main; refusing to test a stale release" >&2
  exit 1
}

auth=( -H "Authorization: Bearer $GH_TOKEN" -H 'Accept: application/vnd.github+json' )

wait_for_candidate() {
  for attempt in $(seq 1 120); do
    run=$(curl -fsSL "${auth[@]}" \
      "$api/workflows/nixos-image.yml/runs?branch=main&event=workflow_dispatch&per_page=20" |
      jq -r --arg commit "$source_commit" \
        '.workflow_runs[] | select(.head_sha == $commit) | .id' | head -1)
    if [ -n "$run" ]; then
      state=$(curl -fsSL "${auth[@]}" "$api/runs/$run" |
        jq -r '[.status, (.conclusion // "")] | @tsv')
      case "$state" in
        $'completed\tsuccess') return 0 ;;
        completed*) echo "candidate build failed: run $run ($state)" >&2; exit 1 ;;
      esac
    fi
    sleep 15
  done
  echo "timed out waiting for candidate build for $source_commit" >&2
  exit 1
}

wait_for_pointer() {
  expected_digest=$1
  for attempt in $(seq 1 40); do
    pointer=$(curl -fsSL "$relay/v1/channels/$channel.json" || true)
    digest=$(printf '%s' "$pointer" | jq -r '.manifest.sha256 // empty' 2>/dev/null || true)
    sequence=$(printf '%s' "$pointer" | jq -r '.sequence // empty' 2>/dev/null || true)
    if [ "$digest" = "$expected_digest" ] && [ -n "$sequence" ]; then
      printf '%s\t%s\n' "$digest" "$sequence"
      return 0
    fi
    sleep 15
  done
  echo "timed out waiting for the ordinary $channel pointer to serve $expected_digest" >&2
  exit 1
}

echo "LIVE UPGRADE: provisioning baseline $channel release"
instance_created=true
env AEROFORM_LIVE_TEST=1 \
  AEROFORM_KEEP_INSTANCE=1 \
  AEROFORM_GOLDEN_PATH_BACKEND=nixos \
  "$flutter_bin" test "$aeroform_root/test/integration/golden_path_provision_test.dart" |
  tee "$work_dir/provision.log"
handoff=$(sed -n 's/^LIVE: retained update handoff //p' "$work_dir/provision.log" | tail -1)
test -n "$handoff" && test -f "$handoff" || {
  echo "provisioning did not produce an update handoff" >&2
  exit 1
}
key_path=$(jq -er '.sshPrivateKeyPath' "$handoff")
baseline_digest=$(jq -er '.releaseDigest' "$handoff")

echo "LIVE UPGRADE: building GitHub-attested candidate $source_commit"
"$repo_root/deploy/nixos/scripts/trigger-ci-build.sh"
wait_for_candidate

echo "LIVE UPGRADE: promoting candidate to $channel"
promotion=$("$repo_root/deploy/nixos/scripts/promote-latest-candidate.sh" "$channel")
printf '%s\n' "$promotion"
candidate_digest=$(printf '%s\n' "$promotion" | sed -n 's/.*manifest=\([0-9a-f]\{64\}\).*/\1/p')
test -n "$candidate_digest" || { echo "promotion did not report a manifest digest" >&2; exit 1; }
test "$candidate_digest" != "$baseline_digest" || {
  echo "candidate is identical to the provisioned baseline" >&2
  exit 1
}
pointer=$(wait_for_pointer "$candidate_digest")
candidate_sequence=${pointer#*$'\t'}

echo "LIVE UPGRADE: updating baseline to $candidate_digest (sequence $candidate_sequence)"
"$repo_root/deploy/release-manager/tests/run-live-nixos-update-test.sh" \
  "$handoff" "$candidate_digest" "$source_commit" "$candidate_sequence"

echo "LIVE UPGRADE: passed $baseline_digest -> $candidate_digest"
