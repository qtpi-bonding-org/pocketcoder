#!/usr/bin/env bash
set -euo pipefail

release=${1:?release commit is required}
nixos_metadata=${2:-nixos-release-metadata.json}
artifact_metadata=${3:-release-artifacts-metadata.json}
repository=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}
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
test "$(jq -r .release "$artifact_metadata")" = "$release"

manifest=$(mktemp)
image_manifest=$(mktemp)
trap 'rm -f "$manifest" "$image_manifest"' EXIT

jq -n --arg release "$release" \
  --arg sourceUrl "https://github.com/$repository/tree/$release" \
  --slurpfile nixos "$nixos_metadata" \
  --slurpfile artifacts "$artifact_metadata" \
  '{schemaVersion:2,release:$release,sourceUrl:$sourceUrl,
    nixosImage:$nixos[0],deployment:$artifacts[0].deployment,
    core:$artifacts[0].core,harnesses:$artifacts[0].harnesses,
    optional:$artifacts[0].optional}' > "$manifest"
deploy/scripts/validate-release-contract.sh "$manifest" \
  deploy/release/harnesses.json
deploy/scripts/resolve-release-artifacts.sh "$manifest" \
  deploy/release/harnesses.json goose >/dev/null

# Publish immutable state first. Mutable discovery pointers move only after the
# complete coupled manifest has passed validation.
aws s3 cp "$manifest" "s3://$bucket/release-$release.json" \
  --endpoint-url "$endpoint"
aws s3 cp "s3://$bucket/pocketcoder-nixos-$release.img.gz" \
  "s3://$bucket/pocketcoder-nixos-latest.img.gz" --copy-props none \
  --endpoint-url "$endpoint"
jq -n --arg sourceCommit "$release" --slurpfile nixos "$nixos_metadata" \
  '{sourceCommit:$sourceCommit,url:$nixos[0].url,sha256:$nixos[0].sha256,
    uncompressedBytes:$nixos[0].expandedBytes}' > "$image_manifest"
aws s3 cp "$manifest" "s3://$bucket/release-manifest.json" \
  --endpoint-url "$endpoint"
aws s3 cp "$image_manifest" "s3://$bucket/image-manifest.json" \
  --endpoint-url "$endpoint"
