#!/bin/sh
# Dispatches the promotion workflow for the latest successful NixOS candidate.
# GH_TOKEN is injected by secrets-daemon; this script never reads it from disk.
#
# Usage: promote-latest-candidate.sh <channel> [commit]
#
# The optional [commit] argument overrides which commit to look up a
# successful candidate run for. Without it, the script resolves the
# CURRENT remote tip of the checked-out branch via `git fetch` -- not the
# local checkout's own possibly-stale HEAD. This matters because whatever
# persistent checkout this script runs from (wherever the daemon points
# it) is not guaranteed to have been `git pull`-ed since the last push:
# confirmed live 2026-08-26, where the local checkout's HEAD sat one merge
# commit behind origin/staging, causing this script to look up a candidate
# run for a commit that was never independently built, instead of the one
# that had actually just succeeded in CI.
set -eu

channel=${1:?channel is required}
case "$channel" in stable | beta | nightly) ;; *) echo "invalid channel" >&2; exit 1 ;; esac
commit_override=${2:-}

api='https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions'
auth="Authorization: Bearer $GH_TOKEN"
ref=$(git symbolic-ref --short HEAD 2>/dev/null || true)
case "$ref" in
  main | staging) ;;
  vps-test/*)
    # vps-test/* is reserved for the upgrade-os NixOS-version round-trip
    # (see 92-nixos-upgrade.sh) and must never share nightly-testing.json
    # with the everyday VPS suite's own staging-branch promotions (see
    # 55-promote.sh) -- beta-testing.json is the dedicated, otherwise-
    # unused pointer for this flow. Real beta users are unaffected: they
    # trust main and poll the bare beta.json, never the "-testing" one.
    case "$channel" in
      beta) ;;
      *) echo "vps-test/* branches may only promote to the beta channel" >&2; exit 1 ;;
    esac
    ;;
  *)
    echo "candidate promotion requires a checked-out main, staging, or vps-test/* branch" >&2
    exit 64
    ;;
esac

if [ -n "$commit_override" ]; then
  source_commit=$commit_override
else
  # Fetch the branch's real, current remote tip rather than trusting
  # whatever the local checkout's own HEAD happens to be pointed at --
  # see the usage comment above for why that's not safe to assume.
  git fetch -q origin "$ref"
  source_commit=$(git rev-parse "origin/$ref")
fi
case "$source_commit" in *[!0-9a-f]* | '') echo "invalid commit: $source_commit" >&2; exit 1 ;; esac
test "${#source_commit}" -eq 40 || { echo "invalid commit: $source_commit" >&2; exit 1; }
run=$(curl -sf -H "$auth" "$api/workflows/nixos-image.yml/runs?branch=$ref&status=completed&per_page=20" |
  jq -r --arg source_commit "$source_commit" \
    '.workflow_runs[] | select(.conclusion == "success" and .head_sha == $source_commit) | .id' |
  head -1)
test -n "$run" || {
  echo "no successful NixOS candidate run found for commit $source_commit" >&2
  exit 1
}

artifact=$(curl -sf -H "$auth" "$api/runs/$run/artifacts?per_page=100" |
  jq -r '.artifacts[] | select(.name | startswith("release-candidate-manifest-")) | .archive_download_url' | head -1)
test -n "$artifact" || { echo "no candidate identity artifact found for run $run" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
curl -sfL -H "$auth" "$artifact" -o "$tmp/candidate.zip"
unzip -q "$tmp/candidate.zip" -d "$tmp/candidate"
digest=$(tr -d '[:space:]' < "$tmp/candidate/manifest.sha256")
case "$digest" in *[!0-9a-f]* | '') echo 'candidate identity is not a SHA-256 digest' >&2; exit 1 ;; esac
test "${#digest}" -eq 64

payload=$(jq -n --arg channel "$channel" --arg digest "$digest" \
  --arg ref "$ref" \
  '{ref:$ref,inputs:{channel:$channel,manifest_sha256:$digest,sequence:"next"}}')
curl -sf -X POST -H "$auth" -H 'Accept: application/vnd.github+json' \
  'https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions/workflows/release-promotion.yml/dispatches' \
  -d "$payload"
echo "promotion dispatched: ref=$ref channel=$channel manifest=$digest source_run=$run"
