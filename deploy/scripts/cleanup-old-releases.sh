#!/bin/sh
set -eu

release_state=${1:?release state directory is required}
releases_dir=${2:?release directory is required}

case "$release_state" in '' | / | .) echo "unsafe release state path" >&2; exit 1 ;; esac
case "$releases_dir" in '' | / | .) echo "unsafe releases path" >&2; exit 1 ;; esac

pointer_release() {
  file=$1
  [ -f "$file" ] || return 0
  value=$(jq -r '.release // empty' "$file")
  case "$value" in *[!0-9a-f]* | '') return 0 ;; esac
  [ "${#value}" -eq 40 ] || return 0
  printf '%s\n' "$value"
}

current=$(pointer_release "$release_state/current.json")
previous=$(pointer_release "$release_state/previous.json")
if [ -z "$current" ]; then
  echo "current release pointer is unavailable; refusing cleanup" >&2
  exit 1
fi

keep_images=$(mktemp)
release_images=$(mktemp)
trap 'rm -f "$keep_images" "$release_images"' EXIT HUP INT TERM
for keep in "$current" "$previous"; do
  [ -n "$keep" ] || continue
  keep_manifest="$release_state/manifests/$keep.json"
  [ -f "$keep_manifest" ] || continue
  jq -r '.core.images[], .harnesses[].images[], .optional[]?.images[]?' \
    "$keep_manifest" >> "$keep_images"
done
sort -u "$keep_images" -o "$keep_images"

for manifest in "$release_state"/manifests/*.json; do
  [ -f "$manifest" ] || continue
  release=$(basename -- "$manifest" .json)
  case "$release" in *[!0-9a-f]* | '') continue ;; esac
  [ "${#release}" -eq 40 ] || continue
  if [ "$release" = "$current" ] \
    || { [ -n "$previous" ] && [ "$release" = "$previous" ]; }; then
    continue
  fi

  jq -r '.core.images[], .harnesses[].images[], .optional[]?.images[]?' \
    "$manifest" | sort -u > "$release_images"
  removable=1
  while IFS= read -r image; do
    [ -n "$image" ] || continue
    if grep -Fqx -- "$image" "$keep_images"; then
      continue
    fi
    if ! docker image inspect "$image" >/dev/null 2>&1; then
      continue
    fi
    if ! docker image rm "$image" >/dev/null 2>&1; then
      echo "Retaining release metadata because its image is still in use: $image" >&2
      removable=0
    fi
  done < "$release_images"

  # Keep the manifest and release tree whenever Docker says an old image is
  # still in use. A later cleanup can retry safely; deleting the metadata now
  # would orphan that image and make future scoped cleanup impossible.
  if [ "$removable" -ne 1 ]; then
    continue
  fi

  rm -f "$manifest"
  release_dir="$releases_dir/$release"
  if [ -d "$release_dir" ]; then
    rm -rf "$release_dir"
  fi
done
