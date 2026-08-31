#!/usr/bin/env bash
set -euo pipefail

# Verifies every object a candidate manifest references is actually fetchable
# through the public image-relay Worker before release-promotion.yml is
# allowed to move a channel pointer at it. R2 uploads (publish-attested-
# candidate.sh) and the public Worker read path can lag by a short window
# after upload -- observed directly: a HEAD on a freshly uploaded artifact
# 404'd, then succeeded a few minutes later with no other change. Promoting
# a channel pointer during that window hands consumers (Aeroform's boot-time
# image pull, in particular) a URL that isn't reliably live yet. This makes
# that race impossible: the channel pointer can only move once every
# referenced object is confirmed reachable through the same public path
# consumers use.
manifest_sha=${1:?manifest sha256 is required}
base_url=${POCKETCODER_RELEASE_BASE:-https://images.relay.pocketcoder.org}
deadline_seconds=${POCKETCODER_VERIFY_DEADLINE:-600}
interval_seconds=${POCKETCODER_VERIFY_INTERVAL:-10}

case "$manifest_sha" in *[!0-9a-f]* | '') echo "invalid manifest digest" >&2; exit 1 ;; esac
test "${#manifest_sha}" -eq 64

wait_for_200() {
  url=$1
  started=$(date +%s)
  while :; do
    status=$(curl -s -o /dev/null -w '%{http_code}' --head --max-time 20 "$url" || echo 000)
    if [ "$status" = 200 ]; then
      echo "reachable: $url"
      return 0
    fi
    if [ $(( $(date +%s) - started )) -ge "$deadline_seconds" ]; then
      echo "not reachable after ${deadline_seconds}s (last status $status): $url" >&2
      return 1
    fi
    sleep "$interval_seconds"
  done
}

# HEAD-only reachability (above) proves the object exists and R2/the Worker
# will respond -- it does NOT prove the bytes a GET actually serves match
# the hash the URL claims. Content-addressed paths embed their own expected
# sha256 in the filename (image-relay's routing.ts only accepts an object
# under that exact scheme), so this streams a real GET through sha256sum
# and compares against the hash parsed out of the URL itself -- catching a
# corrupted upload or (per live incident 2026-08-25: a boot-time installer
# and a manual reproduction both independently got the identical wrong
# hash for the same artifact URL, while a later fetch got the correct one)
# a stale bad copy sitting at some cache layer in front of the Worker, that
# a bare-existence HEAD check can never detect. Retries on the same
# deadline/interval as wait_for_200, since a freshly-uploaded object can
# transiently 200 with an incomplete body during the same propagation
# window that motivated wait_for_200 in the first place.
verify_content_address() {
  url=$1
  hash=$(printf '%s' "$url" | grep -oE '[0-9a-f]{64}' | head -1)
  if [ -z "$hash" ]; then
    return 0
  fi
  started=$(date +%s)
  while :; do
    actual=$(curl -sf --max-time "$deadline_seconds" "$url" | sha256sum | cut -d' ' -f1) || actual=""
    if [ "$actual" = "$hash" ]; then
      echo "content-verified: $url"
      return 0
    fi
    if [ $(( $(date +%s) - started )) -ge "$deadline_seconds" ]; then
      echo "content mismatch after ${deadline_seconds}s: $url expected $hash got ${actual:-<fetch failed>}" >&2
      return 1
    fi
    sleep "$interval_seconds"
  done
}

verify_url() {
  wait_for_200 "$1"
  verify_content_address "$1"
}

manifest_url="$base_url/v1/releases/$manifest_sha.json"
attestation_url="$base_url/v1/attestations/releases/$manifest_sha.sigstore.json"

wait_for_200 "$manifest_url"
wait_for_200 "$attestation_url"

manifest_tmp=$(mktemp)
trap 'rm -f "$manifest_tmp"' EXIT
curl -sf --max-time 20 "$manifest_url" -o "$manifest_tmp"
test "$(sha256sum "$manifest_tmp" | cut -d' ' -f1)" = "$manifest_sha" ||
  { echo "manifest served by the public path does not match its own digest" >&2; exit 1; }

jq -r '[.serverFiles, (.osImages[].delivery | select(.kind == "artifact") | .artifact), .images.required[], .images.choices[].options[]][].url' "$manifest_tmp" |
  while IFS= read -r url; do verify_url "$url"; done
jq -r '.documents[].url' "$manifest_tmp" |
  while IFS= read -r url; do verify_url "$url"; done

echo "candidate $manifest_sha and all referenced objects are publicly reachable and content-verified"
