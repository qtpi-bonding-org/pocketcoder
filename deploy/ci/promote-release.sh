#!/usr/bin/env bash
set -euo pipefail

release=${1:?release commit is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}

case "$release" in
  *[!0-9a-f]* | '')
    echo "invalid release commit: $release" >&2
    exit 1
    ;;
esac
if [[ ${#release} -ne 40 ]]; then
  echo "invalid release commit: $release" >&2
  exit 1
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
cd "$repo_root"
manifest=$(mktemp)
image_manifest=$(mktemp)
trap 'rm -f "$manifest" "$image_manifest"' EXIT

# Promotion consumes an already-built immutable candidate. It never rebuilds
# artifacts, so review/testing and the public pointer move are separate acts.
aws s3 cp "s3://$bucket/release-$release.json" "$manifest" \
  --endpoint-url "$endpoint"
test "$(jq -r '.release // empty' "$manifest")" = "$release"
deploy/scripts/validate-release-contract.sh "$manifest" \
  deploy/release/harnesses.json
deploy/scripts/resolve-release-artifacts.sh "$manifest" \
  deploy/release/harnesses.json goose >/dev/null

# Mutable discovery pointers move only after the immutable candidate has
# passed validation at the exact commit requested by the operator.
aws s3 cp "s3://$bucket/pocketcoder-nixos-$release.img.gz" \
  "s3://$bucket/pocketcoder-nixos-latest.img.gz" --copy-props none \
  --endpoint-url "$endpoint"
jq '{sourceCommit:.release,url:.nixosImage.url,sha256:.nixosImage.sha256,
    uncompressedBytes:.nixosImage.expandedBytes}' "$manifest" > "$image_manifest"
aws s3 cp "$manifest" "s3://$bucket/release-manifest.json" \
  --endpoint-url "$endpoint"
aws s3 cp "$image_manifest" "s3://$bucket/image-manifest.json" \
  --endpoint-url "$endpoint"
