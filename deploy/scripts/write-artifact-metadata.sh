#!/bin/sh
set -eu

output=${1:?metadata output path is required}
url=${2:?artifact URL is required}
archive=${3:?artifact archive path is required}
expanded_bytes=${4:?expanded byte count is required}
shift 4

case "$expanded_bytes" in
  '' | *[!0-9]*)
    echo "expanded byte count must be a positive integer" >&2
    exit 1
    ;;
esac
if [ "$expanded_bytes" -le 0 ]; then
  echo "expanded byte count must be a positive integer" >&2
  exit 1
fi

if command -v sha256sum >/dev/null 2>&1; then
  sha256=$(sha256sum "$archive" | cut -d' ' -f1)
else
  sha256=$(shasum -a 256 "$archive" | cut -d' ' -f1)
fi
bytes=$(wc -c < "$archive" | tr -d ' ')
images=$(for image in "$@"; do printf '%s\n' "$image"; done | jq -Rsc 'split("\n")[:-1]')

jq -n \
  --arg url "$url" \
  --arg sha256 "$sha256" \
  --argjson bytes "$bytes" \
  --argjson expandedBytes "$expanded_bytes" \
  --argjson images "$images" \
  '{url: $url, sha256: $sha256, bytes: $bytes,
    expandedBytes: $expandedBytes, images: $images}' \
  > "$output"
