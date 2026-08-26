#!/bin/sh
# Consolidates what used to be four separate inline CI steps ("Compress
# image", "Compute image metadata", "Check image size", "Write release
# metadata") into one tracked, hashable file -- so a single hashFiles() on
# this script (plus write-artifact-metadata.sh, which it calls) fully
# describes everything that determines the cached artifact/metadata pair's
# shape. See docs/superpowers/specs/2026-08-26-nixos-image-actions-cache.md
# section 3.2 step 6.
set -eu

image=${1:?path to the built nixos.img is required}
metadata_script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

archive=pocketcoder-nixos.img.gz
gzip -c "$image" > "$archive"

if command -v sha256sum >/dev/null 2>&1; then
  sha256=$(sha256sum "$archive" | cut -d' ' -f1)
else
  sha256=$(shasum -a 256 "$archive" | cut -d' ' -f1)
fi
uncompressed_bytes=$(stat -c%s "$image" 2>/dev/null || stat -f%z "$image")
compressed_bytes=$(stat -c%s "$archive" 2>/dev/null || stat -f%z "$archive")
echo "Image sha256: $sha256"
echo "Uncompressed bytes: $uncompressed_bytes"
echo "Compressed image size: $compressed_bytes bytes ($((compressed_bytes / 1024 / 1024)) MiB)"

sh "$metadata_script_dir/write-artifact-metadata.sh" \
  nixos-release-metadata.json \
  auto \
  "$archive" \
  "$uncompressed_bytes"

mkdir -p artifacts
mv "$archive" "artifacts/$sha256.img.gz"
