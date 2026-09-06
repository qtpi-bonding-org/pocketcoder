#!/bin/sh
set -eu

# Diffs against the promoted commit, not origin/main -- pushed code can
# sit unreleased indefinitely.

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

nixos_changed=$(git diff --name-only "$source_commit..$ref" -- deploy/)
backend_changed=$(git diff --name-only "$source_commit..$ref" -- server/ api/ contracts/)
workers_changed=$(git diff --name-only "$source_commit..$ref" -- workers/)
flutter_changed=$(git diff --name-only "$source_commit..$ref" -- client/)

report() {
  label=$1
  files=$2
  if [ -z "$files" ]; then
    printf '%-10s no change\n' "$label"
  else
    count=$(printf '%s\n' "$files" | wc -l | tr -d ' ')
    printf '%-10s %s file(s) changed\n' "$label" "$count"
    printf '%s\n' "$files" | sed 's/^/    /'
  fi
}

report "nixos:" "$nixos_changed"
report "backend:" "$backend_changed"
report "workers:" "$workers_changed"
report "flutter:" "$flutter_changed"
echo

if [ -n "$nixos_changed" ] || [ -n "$backend_changed" ]; then
  echo "ALERT: nixos and/or backend changed since the promoted release."
  echo "  -> rebuild + promote required (docs/ops-runbook.md section 6) before app builds go out."
  exit_code=2
elif [ -n "$workers_changed" ]; then
  echo "workers changed -- deploy independently (wrangler), unrelated to the nixos/app pipeline."
  exit_code=0
else
  echo "OK: nixos and backend match the promoted release. Safe to skip the release pipeline."
  exit_code=0
fi

exit "$exit_code"
