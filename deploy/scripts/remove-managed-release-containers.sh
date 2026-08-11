#!/bin/sh
set -eu

release=${1:?outgoing release is required}
manifest_file=${2:?outgoing release manifest is required}

case "$release" in
  *[!0-9a-f]* | '') echo "invalid outgoing release: $release" >&2; exit 1 ;;
esac
if [ "${#release}" -ne 40 ]; then
  echo "invalid outgoing release: $release" >&2
  exit 1
fi

ids=$(mktemp)
trap 'rm -f "$ids"' EXIT HUP INT TERM

# Normal path for containers created by current releases.
docker ps -aq \
  --filter label=pc_managed=pocketcoder \
  --filter label=pc_release="$release" >> "$ids"

# Migration path for early artifact releases whose Docker-create client placed
# labels under HostConfig instead of Config. Match both an immutable image from
# the outgoing manifest and PocketCoder's fixed container-name namespace; do
# not touch arbitrary unlabeled containers or anything using a user image.
jq -r '.harnesses[].images[]' "$manifest_file" | while IFS= read -r image; do
  docker ps -aq --filter ancestor="$image" --filter name=pocketcoder-harness- \
    >> "$ids"
done
jq -r '.optional.ollama.images[]?' "$manifest_file" | while IFS= read -r image; do
  docker ps -aq --filter ancestor="$image" --filter name=pocketcoder-ollama \
    >> "$ids"
done

sort -u "$ids" | while IFS= read -r container; do
  [ -n "$container" ] || continue
  echo "Removing PocketCoder-managed release container $container"
  docker rm -f "$container" >/dev/null
done
