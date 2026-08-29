#!/usr/bin/env bash
set -euo pipefail

# Proves verify-candidate-published.sh's content-address check actually
# catches a body that doesn't match its own URL-embedded hash -- not just
# that it passes on a correct one. Copies verify_content_address()
# verbatim (same technique deploy/nixos/stackscripts/tests/test-proof-
# signing.sh uses for its own shell logic) rather than sourcing the real
# script, since the real script has no test-mode guard around its
# top-level curl/jq calls. Serves fixtures from a local python http.server
# so this needs no network access and no real image-relay deployment.
#
# Motivation: this check didn't exist until 2026-08-25, after a live
# incident where a boot-time installer and a manual reproduction both
# independently got the identical WRONG hash for the same content-
# addressed artifact URL, while a plain HEAD-only reachability check (the
# only check that existed at the time) would have reported it as fine.

deadline_seconds=3
interval_seconds=1

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

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"; [ -n "${server_pid:-}" ] && kill "$server_pid" 2>/dev/null || true' EXIT

good_content='this is the real, correct artifact content'
bad_content='this is NOT what the hash promises'
good_hash=$(printf '%s' "$good_content" | sha256sum | cut -d' ' -f1)

mkdir -p "$tmp/www"
printf '%s' "$good_content" > "$tmp/www/${good_hash}.img.gz"
printf '%s' "$bad_content" > "$tmp/www/${good_hash}-mismatch.img.gz"

port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
(cd "$tmp/www" && python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1) &
server_pid=$!
for _ in $(seq 1 30); do
  curl -sf "http://127.0.0.1:$port/" >/dev/null 2>&1 && break
  sleep 0.1
done

fail=0

echo "== correct content-addressed URL must pass =="
if verify_content_address "http://127.0.0.1:$port/${good_hash}.img.gz"; then
  echo "PASS"
else
  echo "FAIL: correct object was rejected"
  fail=1
fi

echo "== mismatched content-addressed URL must fail, not silently pass =="
# The mismatch fixture's filename embeds good_hash too (that's the whole
# point -- content that doesn't match the hash its own URL claims), so
# reuse it under a name still matching the 64-hex extraction pattern.
mismatch_url="http://127.0.0.1:$port/${good_hash}-mismatch.img.gz"
# grep -oE '[0-9a-f]{64}' would also match inside "-mismatch" only if it
# contained 64 hex chars, which it doesn't -- the URL's only 64-hex run is
# still good_hash, so this exercises exactly the mismatch case.
if verify_content_address "$mismatch_url"; then
  echo "FAIL: mismatched object was accepted"
  fail=1
else
  echo "PASS (correctly rejected)"
fi

echo "== URL with no embedded hash is a no-op pass (non-content-addressed path) =="
if verify_content_address "http://127.0.0.1:$port/plain.json"; then
  echo "PASS"
else
  echo "FAIL: URL with no 64-hex segment should be a no-op"
  fail=1
fi

exit "$fail"
