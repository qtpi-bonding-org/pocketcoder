#!/bin/sh
# Dispatches the promotion workflow for the latest successful NixOS candidate.
# GH_TOKEN is injected by secrets-daemon; this script never reads it from disk.
set -eu

channel=${1:?channel is required}
case "$channel" in stable | beta | nightly) ;; *) echo "invalid channel" >&2; exit 1 ;; esac

api='https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions'
auth="Authorization: Bearer $GH_TOKEN"
run=$(curl -sf -H "$auth" "$api/workflows/nixos-image.yml/runs?branch=main&status=success&per_page=1" |
  jq -r '.workflow_runs[0].id // empty')
test -n "$run" || { echo 'no successful NixOS candidate run found' >&2; exit 1; }

artifact=$(curl -sf -H "$auth" "$api/runs/$run/artifacts?per_page=100" |
  jq -r '.artifacts[] | select(.name | startswith("release-candidate-")) | .archive_download_url' | head -1)
test -n "$artifact" || { echo "no canonical candidate artifact found for run $run" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -sfL -H "$auth" "$artifact" -o "$tmp/candidate.zip"
unzip -q "$tmp/candidate.zip" -d "$tmp/candidate"
manifest="$tmp/candidate/release-manifest.json"
test -f "$manifest" || { echo 'candidate artifact has no release manifest' >&2; exit 1; }
digest=$(sha256sum "$manifest" | cut -d' ' -f1)

payload=$(jq -n --arg channel "$channel" --arg digest "$digest" \
  '{ref:"main",inputs:{channel:$channel,manifest_sha256:$digest,sequence:"next"}}')
curl -sf -X POST -H "$auth" -H 'Accept: application/vnd.github+json' \
  'https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions/workflows/release-promotion.yml/dispatches' \
  -d "$payload"
echo "promotion dispatched: channel=$channel manifest=$digest source_run=$run"
