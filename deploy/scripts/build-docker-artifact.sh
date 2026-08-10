#!/bin/sh
set -eu

output=${1:?Docker artifact output path is required}
shift
if [ "$#" -eq 0 ]; then
  echo "at least one Docker image is required" >&2
  exit 1
fi

seen=''
expanded_bytes=0
for image in "$@"; do
  case " $seen " in
    *" $image "*)
      echo "duplicate Docker image: $image" >&2
      exit 1
      ;;
  esac
  seen="$seen $image"
  size=$(docker image inspect --format '{{.Size}}' "$image")
  expanded_bytes=$((expanded_bytes + size))
done

docker save "$@" | gzip > "$output"
printf '%s\n' "$expanded_bytes"
