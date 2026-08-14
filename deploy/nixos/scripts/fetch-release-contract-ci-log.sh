#!/bin/sh
set -eu

: "${GH_TOKEN:?GH_TOKEN is required}"

repo=qtpi-bonding-org/pocketcoder
workflow=release-contract.yml
run_id=${1:-}

if [ -z "$run_id" ]; then
  run_id=$(curl -fsSL \
    -H "Authorization: Bearer $GH_TOKEN" \
    -H 'Accept: application/vnd.github+json' \
    "https://api.github.com/repos/$repo/actions/workflows/$workflow/runs?branch=main&per_page=1" \
    | jq -r '.workflow_runs[0].id // empty')
fi

case "$run_id" in
  ''|*[!0-9]*)
    echo "a numeric release-contract workflow run ID is required" >&2
    exit 1
    ;;
esac

archive=$(mktemp)
trap 'rm -f "$archive"' EXIT HUP INT TERM
curl -fsSL \
  -H "Authorization: Bearer $GH_TOKEN" \
  -H 'Accept: application/vnd.github+json' \
  "https://api.github.com/repos/$repo/actions/runs/$run_id/logs" \
  -o "$archive"

# GitHub masks configured secret values in Actions logs. Extract the relevant
# Flutter step rather than relying on ZIP member ordering.
matches=$(unzip -Z1 "$archive" | grep 'Analyze Flutter Core' || true)
if [ -z "$matches" ]; then
  echo "the workflow log archive contains no Analyze Flutter Core step" >&2
  exit 1
fi
printf '%s\n' "$matches" | while IFS= read -r log_file; do
  unzip -p "$archive" "$log_file"
done
