#!/bin/sh
# Dispatches the one-time, empty, GitHub-attested revocation baseline.
# GH_TOKEN is injected by secrets-daemon; it is never read from disk or
# printed. Later revocations are deliberate release operations, not this
# bootstrap helper.
set -eu

release_base='https://images.relay.pocketcoder.org'
api='https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions'
auth="Authorization: Bearer $GH_TOKEN"

status=$(curl -sS -o /dev/null -w '%{http_code}' \
  "$release_base/v1/revocations/releases.json")
case "$status" in
  200)
    echo 'revocation baseline already published'
    exit 0
    ;;
  404) ;;
  *)
    echo "unexpected revocation endpoint status: $status" >&2
    exit 1
    ;;
esac

published_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
revocations=$(jq -cn --arg publishedAt "$published_at" \
  '{schemaVersion:1,sequence:1,publishedAt:$publishedAt,revokedReleases:{}}')
payload=$(jq -cn --arg revocations "$revocations" \
  '{ref:"main",inputs:{payload:$revocations}}')

curl -sf -X POST -H "$auth" -H 'Accept: application/vnd.github+json' \
  "$api/workflows/release-revocation.yml/dispatches" -d "$payload"
echo 'initial signed revocation baseline dispatched'
