#!/bin/bash
# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
# <UDF name="IMAGE_UNCOMPRESSED_BYTES" label="Expected uncompressed size in bytes" />
# <UDF name="ADMIN_USER_DATA" label="Base64-encoded admin config (was Linode metadata.user_data)" />
# <UDF name="BOX_PRIVATE_KEY_PKCS8" label="Box's own P-256 private key, PKCS8 DER, base64" />
# <UDF name="BOX_CREDENTIAL" label="Root-signed credential (compact JWS) naming this box's key" />
# ADMIN_USER_DATA follows the BOOT-ENV SCHEMA documented and validated in
# deploy/nixos/bootstrap.sh (currently SCHEMA=1), including the phone-planted
# host_ssh_private_key (base64), host_ssh_public_key, and public_ip fields.
set -euo pipefail

command -v curl >/dev/null || { apt-get update && apt-get install -y curl; }
command -v xxd >/dev/null || { apt-get update && apt-get install -y xxd; }

[ -b /dev/sdb ] || { echo "FATAL: /dev/sdb not found"; exit 1; }
TARGET_BYTES=$(blockdev --getsize64 /dev/sdb)
[ "$TARGET_BYTES" -ge "$IMAGE_UNCOMPRESSED_BYTES" ] || {
  echo "FATAL: target disk ($TARGET_BYTES bytes) smaller than image ($IMAGE_UNCOMPRESSED_BYTES bytes)"
  exit 1
}

# Live-confirmed 2026-08-25: real boot-time runs failed 10/10 times across
# three separate test runs, always instantly (0 bytes transferred, curl
# HTTP/2 stream reset), always during THIS StackScript's own very-early
# boot-time execution -- while the exact same request (headers, URL,
# pipeline) run manually over SSH minutes later, after boot fully
# settles, succeeded cleanly every single time (confirmed again on the
# third run's own box: HTTP/2, HTTP/1.1, and a HEAD on the real artifact
# all succeeded immediately post-boot). Not a code/header/signing bug, and
# not a bad/stale artifact either (both separately verified -- the
# artifact's own bytes were independently confirmed correct via
# verify_release_artifact_test.dart minutes before the third run started,
# and it still failed with 0 bytes). This network-readiness pre-check +
# preferring HTTP/1.1 for the main download was the first attempted
# mitigation and did NOT fix it (the third run still failed after both
# were already in place) -- kept anyway since it's harmless, but don't
# treat its presence as evidence the timing issue is handled. The
# distinguishing factor is still boot timing specifically, and still
# unexplained. What WAS missing every time this was investigated: the
# actual curl error (exit code, -v trace) was never captured anywhere --
# once the box reaches steady state the detail is gone. Now captured to
# DEBUG_LOG below on every attempt, so the next failure can be read
# directly instead of reconstructed after the fact.
echo "Waiting for network readiness..."
network_ready=0
for _ in $(seq 1 30); do
  if curl -fsS -m 5 --http1.1 https://images.relay.pocketcoder.org/v1/health >/dev/null 2>&1; then
    network_ready=1
    break
  fi
  sleep 2
done
if [ "$network_ready" -eq 1 ]; then
  echo "Network ready."
else
  echo "Network readiness check never succeeded after 60s -- proceeding anyway."
fi

MAX_ATTEMPTS=6
attempt=0
until [ "$attempt" -ge "$MAX_ATTEMPTS" ]; do
  attempt=$((attempt + 1))
  echo "Attempt $attempt..."
  mkfifo /tmp/sumpipe
  sha256sum < /tmp/sumpipe > /tmp/sum &
  SUMPID=$!

  # Sign the DPoP-style proof by hand -- see docs/superpowers/specs/
  # 2026-08-24-image-relay-auth-protocol.md for the exact claim shape.
  # This is the box's OWN key (not the root) -- BOX_PRIVATE_KEY_PKCS8.
  printf '%s' "$BOX_PRIVATE_KEY_PKCS8" | base64 -d > /tmp/box_key.der
  openssl pkey -inform DER -in /tmp/box_key.der -pubout -outform DER -out /tmp/box_pub.der 2>/dev/null

  # A P-256 SPKI DER (algorithm id-ecPublicKey + curve prime256v1) is
  # ALWAYS exactly 91 bytes total. The point itself is the file's last
  # 65 bytes (0x04 || X || Y).
  tail -c 65 /tmp/box_pub.der > /tmp/box_pub_point.bin
  tail -c 64 /tmp/box_pub_point.bin > /tmp/box_pub_xy.bin
  head -c 32 /tmp/box_pub_xy.bin > /tmp/box_pub_x.bin
  tail -c 32 /tmp/box_pub_xy.bin > /tmp/box_pub_y.bin

  b64u_file() { base64 < "$1" | tr '+/' '-_' | tr -d '=' | tr -d '\n'; }
  b64u_str() { printf '%s' "$1" | base64 | tr '+/' '-_' | tr -d '=' | tr -d '\n'; }

  BOX_PUB_X=$(b64u_file /tmp/box_pub_x.bin)
  BOX_PUB_Y=$(b64u_file /tmp/box_pub_y.bin)

  # The Worker verifies htu against TRUSTED_ORIGIN + pathname, never the
  # request's own Host. Strip scheme+host and query/fragment before joining.
  TRUSTED_ORIGIN="https://images.relay.pocketcoder.org"
  IMAGE_URL_PATH=$(printf '%s' "$IMAGE_URL" | sed -E 's#^[A-Za-z][A-Za-z0-9+.-]*://[^/]+##; s#[?#].*$##')
  PROOF_HTU="${TRUSTED_ORIGIN}${IMAGE_URL_PATH}"

  PROOF_HEADER=$(b64u_str "$(printf '{\"alg\":\"ES256\",\"typ\":\"dpop+jwt\",\"jwk\":{\"kty\":\"EC\",\"crv\":\"P-256\",\"x\":\"%s\",\"y\":\"%s\"}}' "$BOX_PUB_X" "$BOX_PUB_Y")")
  PROOF_JTI=$(head -c 16 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=')
  PROOF_IAT=$(date +%s)
  PROOF_CLAIMS=$(b64u_str "$(printf '{\"htm\":\"GET\",\"htu\":\"%s\",\"iat\":%s,\"jti\":\"%s\"}' "$PROOF_HTU" "$PROOF_IAT" "$PROOF_JTI")")
  PROOF_SIGNING_INPUT="${PROOF_HEADER}.${PROOF_CLAIMS}"

  # OpenSSL emits DER ECDSA-Sig-Value. Parse its short-form TLV structure;
  # P-256 signatures are always short enough for one-byte lengths.
  printf '%s' "$PROOF_SIGNING_INPUT" | openssl dgst -sha256 -sign /tmp/box_key.der -keyform DER -out /tmp/proof_sig.der
  SIG_HEX=$(xxd -p -c 999 /tmp/proof_sig.der | tr -d '\n')
  RLEN=$((16#${SIG_HEX:6:2}))
  R_HEX=${SIG_HEX:8:$((RLEN * 2))}
  S_TAG_OFFSET=$((8 + RLEN * 2))
  SLEN=$((16#${SIG_HEX:$((S_TAG_OFFSET + 2)):2}))
  S_HEX=${SIG_HEX:$((S_TAG_OFFSET + 4)):$((SLEN * 2))}
  # DER may pad a positive integer with a leading sign byte.
  [ "$RLEN" -eq 33 ] && R_HEX=${R_HEX:2}
  [ "$SLEN" -eq 33 ] && S_HEX=${S_HEX:2}
  R_HEX=$(printf '%064s' "$R_HEX" | tr ' ' '0')
  S_HEX=$(printf '%064s' "$S_HEX" | tr ' ' '0')
  PROOF_SIG=$(printf '%s' "${R_HEX}${S_HEX}" | xxd -r -p | base64 | tr '+/' '-_' | tr -d '=')
  PROOF="${PROOF_SIGNING_INPUT}.${PROOF_SIG}"
  rm -f /tmp/box_key.der /tmp/box_pub.der /tmp/box_pub_point.bin /tmp/box_pub_xy.bin /tmp/box_pub_x.bin /tmp/box_pub_y.bin /tmp/proof_sig.der

  # Every prior live failure of this download has been an instant, 0-byte
  # curl error during this StackScript's own very-early boot-time
  # execution, with the pipeline's overall exit status (via pipefail)
  # correctly detected but curl's OWN specific error (its exit code, and
  # -v's TLS/HTTP negotiation trace) never captured anywhere -- once the
  # box reaches steady state and this script exits, that detail is gone
  # for good, unlike /tmp/sum or a mount check, which survive. This is the
  # gap that made every past investigation reconstruct after the fact
  # instead of just reading what actually happened: append curl's real
  # exit code and full -v trace to a fixed, persistent log file (survives
  # exactly like /tmp/sum does -- the instance stays online on failure) on
  # every attempt, not just on final failure.
  DEBUG_LOG=/root/pocketcoder-installer-debug.log
  {
    echo "=== attempt $attempt at $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  } >> "$DEBUG_LOG"
  if curl -v -fSL --http1.1 --retry 0 --max-time 1800 --speed-limit 1024 --speed-time 60 \
      -H "Pocketcoder-Credential: $BOX_CREDENTIAL" \
      -H "Pocketcoder-Proof: $PROOF" \
      "$IMAGE_URL" \
      2>> "$DEBUG_LOG" \
      | tee /tmp/sumpipe \
      | gunzip \
      | dd of=/dev/sdb bs=16M conv=fsync status=progress; then
    CURL_EXIT="${PIPESTATUS[0]}"
    echo "curl exit code: $CURL_EXIT" >> "$DEBUG_LOG"
    wait "$SUMPID"
    rm -f /tmp/sumpipe
    read -r ACTUAL_SHA _ < /tmp/sum
    if [ "$ACTUAL_SHA" = "$IMAGE_SHA256" ]; then
      # /dev/sdb is a whole-disk ext4 filesystem (configuration.nix's
      # fileSystems."/" has no partition number), so the freshly-dd'd
      # image is mountable directly, no partition table involved. This
      # replaces Linode's metadata.user_data as the admin-config channel
      # -- metadata.user_data is confirmed (live-tested) to prevent this
      # StackScript from running at all when set on the instance, so the
      # config now rides the same stackscript_data channel as
      # IMAGE_URL/IMAGE_SHA256 instead. bootstrap.nix reads this file
      # directly on first real boot rather than querying Linode's
      # metadata service.
      mkdir -p /mnt/target
      sync
      if ! mount -t ext4 /dev/sdb /mnt/target; then
        echo "FATAL: mount /dev/sdb failed -- leaving instance online for inspection"
        exit 1
      fi
      mkdir -p /mnt/target/var/lib
      printf '%s' "$ADMIN_USER_DATA" | base64 -d > /mnt/target/var/lib/pocketcoder-bootstrap-env
      chmod 600 /mnt/target/var/lib/pocketcoder-bootstrap-env
      # Verify before powering off -- a bad write here means the final
      # NixOS boot fails closed with no admin config and no way to SSH
      # in to diagnose it (bootstrap.nix's own fail-closed check has no
      # fallback once metadata.user_data is no longer set at all). Fail
      # loudly and leave the instance running rather than silently
      # powering off on top of a bad write.
      WRITTEN_B64=$(base64 -w0 /mnt/target/var/lib/pocketcoder-bootstrap-env 2>/dev/null || base64 /mnt/target/var/lib/pocketcoder-bootstrap-env | tr -d '\n')
      if [ "$WRITTEN_B64" != "$ADMIN_USER_DATA" ]; then
        echo "FATAL: bootstrap-env write verification failed -- leaving instance online for inspection"
        # Never print WRITTEN_B64: it includes the delivered host private key.
        WRITTEN_SHA=$(printf '%s' "$WRITTEN_B64" | sha256sum | awk '{print $1}')
        echo "Wrote to /mnt/target/var/lib/pocketcoder-bootstrap-env; re-read byte count $(wc -c < /mnt/target/var/lib/pocketcoder-bootstrap-env), sha256 $WRITTEN_SHA"
        exit 1
      fi
      echo "bootstrap-env write verified OK ($(wc -c < /mnt/target/var/lib/pocketcoder-bootstrap-env) bytes)"
      umount /mnt/target
      sync
      systemctl poweroff --no-block
      exit 0
    fi
    echo "Checksum mismatch on attempt $attempt (got $ACTUAL_SHA)"
  else
    CURL_EXIT="${PIPESTATUS[0]}"
    echo "curl exit code: $CURL_EXIT" >> "$DEBUG_LOG"
    wait "$SUMPID" 2>/dev/null || true
    rm -f /tmp/sumpipe
    echo "Transfer failed on attempt $attempt (curl exit $CURL_EXIT -- see $DEBUG_LOG)"
  fi
  if [ "$attempt" -lt "$MAX_ATTEMPTS" ]; then
    backoff=$((attempt * 10))
    echo "Waiting ${backoff}s before retrying..."
    sleep "$backoff"
  fi
done

echo "FATAL: all attempts failed -- leaving instance online for inspection"
exit 1
