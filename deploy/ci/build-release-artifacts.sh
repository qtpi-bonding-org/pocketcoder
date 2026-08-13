#!/usr/bin/env bash
set -euo pipefail

release=${1:?release commit is required}
artifact_dir=${2:-artifacts}
metadata_dir=${3:-metadata}
output=${4:-release-artifacts-metadata.json}

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
test "$(git rev-parse HEAD)" = "$release"
mkdir -p "$artifact_dir" "$metadata_dir"

catalog=deploy/release/harnesses.json
base_url=https://images.pocketcoder.org
compose_snapshot="$artifact_dir/docker-compose.prebuilt.yml"

# Build repository-owned images and give each one its immutable release name.
: "${POCKET_MEMORY_MODEL_URL:?Pocket Memory model artifact URL is required}"
: "${POCKET_MEMORY_MODEL_SHA256:?Pocket Memory model artifact SHA-256 is required}"
export POCKET_MEMORY_REQUIRE_MODEL=1
docker compose -p pocketcoder build pocketbase mcp-gateway pocket-memory
docker tag pocketcoder-pocketbase:latest "pocketcoder-pocketbase:$release"
docker tag pocketcoder-mcp-gateway:latest "pocketcoder-mcp-gateway:$release"
docker tag pocketcoder-memory:latest "pocketcoder-memory:$release"

compose_json=$(docker compose --profile harness-images config --format json)
while IFS=$'\t' read -r id service repository; do
  test -n "$id"
  docker compose -p pocketcoder --profile harness-images build "$service"
  source_image=$(printf '%s' "$compose_json" \
    | jq -r --arg service "$service" '.services[$service].image')
  test -n "$source_image"
  docker tag "$source_image" "$repository:$release"
done < <(jq -r '.harnesses[] | [.id, .composeService, .imageRepository] | @tsv' \
  "$catalog")

ollama_source=$(docker compose --profile local-models config --format json \
  | jq -r '.services.ollama.image')
docker pull "$ollama_source"
docker tag "$ollama_source" "pocketcoder-ollama:$release"

# Pull digest-pinned third-party images and give them local names that remain
# usable after the VPS loads an offline Docker archive.
while IFS= read -r image; do
  test -n "$image"
  if ! docker image inspect "$image" >/dev/null 2>&1; then
    docker pull "$image"
  fi
  if [[ "$image" == *@sha256:* ]]; then
    digest=${image##*@sha256:}
    docker tag "$image" "pocketcoder-bundle-${digest:0:16}"
  fi
done < <(docker compose -p pocketcoder config --images)

deployment_archive="$artifact_dir/pocketcoder-deployment-$release.tar.gz"
deploy/scripts/build-deployment-artifact.sh "$release" "$deployment_archive"
deployment_expanded=$(gzip -dc "$deployment_archive" | wc -c | tr -d ' ')
deploy/scripts/write-artifact-metadata.sh \
  "$metadata_dir/deployment.json" \
  auto \
  "$deployment_archive" "$deployment_expanded"
deployment_sha=$(jq -r '.sha256' "$metadata_dir/deployment.json")
mv "$deployment_archive" "$artifact_dir/$deployment_sha.tar.gz"

deploy/scripts/resolve-release-compose.sh docker-compose.yml \
  "$compose_snapshot" "$release" "$catalog"
mapfile -t core_images < <(deploy/scripts/list-prebuilt-images.sh "$compose_snapshot")
test "${#core_images[@]}" -gt 0
core_archive="$artifact_dir/pocketcoder-core-$release.tar.gz"
core_expanded=$(deploy/scripts/build-docker-artifact.sh \
  "$core_archive" "${core_images[@]}")
deploy/scripts/write-artifact-metadata.sh "$metadata_dir/core.json" \
  auto "$core_archive" \
  "$core_expanded" "${core_images[@]}"
core_sha=$(jq -r '.sha256' "$metadata_dir/core.json")
mv "$core_archive" "$artifact_dir/$core_sha.tar.gz"

while IFS=$'\t' read -r id repository; do
  image="$repository:$release"
  archive="$artifact_dir/pocketcoder-harness-$id-$release.tar.gz"
  expanded=$(deploy/scripts/build-docker-artifact.sh "$archive" "$image")
  deploy/scripts/write-artifact-metadata.sh \
    "$metadata_dir/harness-$id.json" \
    auto \
    "$archive" "$expanded" "$image"
  artifact_sha=$(jq -r '.sha256' "$metadata_dir/harness-$id.json")
  mv "$archive" "$artifact_dir/$artifact_sha.tar.gz"
  jq -n --arg id "$id" --slurpfile artifact "$metadata_dir/harness-$id.json" \
    '{id:$id,artifact:$artifact[0]}' > "$metadata_dir/harness-entry-$id.json"
done < <(jq -r '.harnesses[] | [.id, .imageRepository] | @tsv' "$catalog")

ollama_image="pocketcoder-ollama:$release"
ollama_archive="$artifact_dir/pocketcoder-ollama-$release.tar.gz"
ollama_expanded=$(deploy/scripts/build-docker-artifact.sh \
  "$ollama_archive" "$ollama_image")
deploy/scripts/write-artifact-metadata.sh "$metadata_dir/ollama.json" \
  auto "$ollama_archive" \
  "$ollama_expanded" "$ollama_image"
ollama_sha=$(jq -r '.sha256' "$metadata_dir/ollama.json")
mv "$ollama_archive" "$artifact_dir/$ollama_sha.tar.gz"

jq -n 'reduce inputs as $entry ({}; .[$entry.id] = $entry.artifact)' \
  "$metadata_dir"/harness-entry-*.json > "$metadata_dir/harnesses.json"
jq -n --arg release "$release" \
  --slurpfile deployment "$metadata_dir/deployment.json" \
  --slurpfile core "$metadata_dir/core.json" \
  --slurpfile harnesses "$metadata_dir/harnesses.json" \
  --slurpfile ollama "$metadata_dir/ollama.json" \
  '{schemaVersion:1,sourceCommit:$release,serverFiles:$deployment[0],
    images:{required:{server:$core[0]},
      choices:{"coding-harnesses":$harnesses[0]},
      optional:{ollama:$ollama[0]}}}' > "$output"
