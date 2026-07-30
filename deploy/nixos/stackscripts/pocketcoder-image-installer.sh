#!/bin/bash
# <UDF name="IMAGE_URL" label="NixOS image URL" />
# <UDF name="IMAGE_SHA256" label="Expected sha256 of the gzip" />
# <UDF name="IMAGE_UNCOMPRESSED_BYTES" label="Expected uncompressed size in bytes" />
# <UDF name="ADMIN_USER_DATA" label="Base64-encoded admin config (was Linode metadata.user_data)" />
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
      mount /dev/sdb /mnt/target
      mkdir -p /mnt/target/var/lib
      printf '%s' "$ADMIN_USER_DATA" | base64 -d > /mnt/target/var/lib/pocketcoder-bootstrap-env
      chmod 600 /mnt/target/var/lib/pocketcoder-bootstrap-env
      umount /mnt/target
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
