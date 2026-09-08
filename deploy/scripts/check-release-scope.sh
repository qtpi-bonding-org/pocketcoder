#!/bin/sh
set -eu

# Diffs against the promoted commit, not origin/main -- pushed code can
# sit unreleased indefinitely. Cannot see flutter_aeroform or the Pro
# deployment orchestrator; pocketcoder-pro's scripts/check-release-scope.sh
# wraps this and adds those.

ref=${1:-HEAD}
channel=${2:-stable}
base_url=${POCKETCODER_RELEASE_BASE:-https://images.relay.pocketcoder.org}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
cd "$repo_root"

channel_json=$(curl -fsSL "$base_url/v1/channels/$channel.json")
manifest_url=$(printf '%s' "$channel_json" | jq -r '.manifest.url')
manifest_json=$(curl -fsSL "$manifest_url")
source_commit=$(printf '%s' "$manifest_json" | jq -r '.sourceCommit')
source_repo=$(printf '%s' "$manifest_json" | jq -r '.sourceRepository')
promoted_at=$(printf '%s' "$channel_json" | jq -r '.promotedAt')

echo "channel:          $channel"
echo "promoted commit:  $source_commit ($source_repo)"
echo "promoted at:      $promoted_at"
echo "comparing against: $ref"
echo

if ! git cat-file -e "$source_commit" 2>/dev/null; then
  echo "error: promoted commit $source_commit not found locally -- fetch first (git fetch origin)" >&2
  exit 1
fi

image_changed=$(git diff --name-only "$source_commit..$ref" -- deploy/nixos/ deploy/release-manager/)
tooling_changed=$(git diff --name-only "$source_commit..$ref" -- deploy/ci/ deploy/scripts/)
migrations_changed=$(git diff --name-only "$source_commit..$ref" -- server/pocketbase/pb_migrations/)
backend_changed=$(git diff --name-only "$source_commit..$ref" -- server/ api/ contracts/)
workers_changed=$(git diff --name-only "$source_commit..$ref" -- workers/)
flutter_changed=$(git diff --name-only "$source_commit..$ref" -- client/)

report() {
  label=$1
  files=$2
  if [ -z "$files" ]; then
    printf '%-18s no change\n' "$label"
  else
    count=$(printf '%s\n' "$files" | wc -l | tr -d ' ')
    printf '%-18s %s file(s) changed\n' "$label" "$count"
    printf '%s\n' "$files" | sed 's/^/    /'
  fi
}

report "nixos/rel-mgr:" "$image_changed"
report "deploy tooling:" "$tooling_changed"
report "pb migrations:" "$migrations_changed"
report "backend:" "$backend_changed"
report "workers:" "$workers_changed"
report "flutter:" "$flutter_changed"
echo

if [ -n "$image_changed" ]; then
  verdict=FULL_PROVISION
  echo "FULL_PROVISION: deploy/nixos or deploy/release-manager changed -- this moves"
  echo "  the image drv hash. Run the full live-VPS provisioning suite once, on"
  echo "  staging/nightly, before opening the staging->main PR (docs/ops-runbook.md"
  echo "  section 6)."
elif [ -n "$migrations_changed" ] || [ -n "$backend_changed" ]; then
  verdict=UPGRADE_TEST_ONLY
  echo "UPGRADE_TEST_ONLY: backend and/or a PocketBase migration changed, but"
  echo "  deploy/nixos and deploy/release-manager did not. Run"
  echo "  run_vps_script_nixos_full_suite -- it provisions a box on the current"
  echo "  release, builds+promotes this commit to nightly-testing, runs the"
  echo "  in-place update, and verifies data survives. There is no cheaper"
  echo "  substitute that actually exercises the update path."
else
  verdict=SKIP_VPS_TEST
  echo "SKIP_VPS_TEST: nothing in this repo's visible scope needs a live-VPS test"
  echo "  before promoting."
  echo "  (This script cannot see the flutter_aeroform pin or the Pro deployment"
  echo "  orchestrator -- scripts/check-release-scope.sh in pocketcoder-pro checks"
  echo "  those too and can still escalate this verdict.)"
fi

if [ -n "$workers_changed" ]; then
  echo "workers changed -- deploy independently (wrangler), unrelated to this verdict."
fi
if [ -n "$tooling_changed" ]; then
  echo "deploy tooling (ci/scripts) changed -- review directly, not drv-hash-relevant."
fi

echo
echo "VERDICT: $verdict"

case "$verdict" in
  FULL_PROVISION) exit 2 ;;
  UPGRADE_TEST_ONLY) exit 1 ;;
  SKIP_VPS_TEST) exit 0 ;;
esac
