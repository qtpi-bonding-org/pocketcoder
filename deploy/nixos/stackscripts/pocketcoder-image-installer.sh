#!/bin/bash
# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
# <UDF name="IMAGE_UNCOMPRESSED_BYTES" label="Expected uncompressed size in bytes" />
set -euo pipefail

command -v curl >/dev/null || { apt-get update && apt-get install -y curl; }

[ -b /dev/sdb ] || { echo "FATAL: /dev/sdb not found"; exit 1; }
TARGET_BYTES=$(blockdev --getsize64 /dev/sdb)
[ "$TARGET_BYTES" -ge "$IMAGE_UNCOMPRESSED_BYTES" ] || {
  echo "FATAL: target disk ($TARGET_BYTES bytes) smaller than image ($IMAGE_UNCOMPRESSED_BYTES bytes)"
  exit 1
}

attempt=0
until [ "$attempt" -ge 3 ]; do
  attempt=$((attempt + 1))
  echo "Attempt $attempt..."
  mkfifo /tmp/sumpipe
  sha256sum < /tmp/sumpipe > /tmp/sum &
  SUMPID=$!

  if curl -fsSL --retry 0 --max-time 1800 --speed-limit 1024 --speed-time 60 \
      "$IMAGE_URL" \
      | tee /tmp/sumpipe \
      | gunzip \
      | dd of=/dev/sdb bs=16M conv=fsync status=progress; then
    wait "$SUMPID"
    rm -f /tmp/sumpipe
    read -r ACTUAL_SHA _ < /tmp/sum
    if [ "$ACTUAL_SHA" = "$IMAGE_SHA256" ]; then
      sync
      systemctl poweroff --no-block
      exit 0
    fi
    echo "Checksum mismatch on attempt $attempt (got $ACTUAL_SHA)"
  else
    wait "$SUMPID" 2>/dev/null || true
    rm -f /tmp/sumpipe
    echo "Transfer failed on attempt $attempt"
  fi
done

echo "FATAL: all attempts failed -- leaving instance online for inspection"
exit 1
