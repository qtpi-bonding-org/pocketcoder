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

if test "$url" = auto; then
  case "$archive" in
    *.tar.gz) suffix=tar.gz ;;
    *.img.gz) suffix=img.gz ;;
    *) echo "cannot derive artifact extension: $archive" >&2; exit 1 ;;
  esac
  url="${POCKETCODER_RELEASE_BASE:-https://images.relay.pocketcoder.org}/v1/artifacts/$sha256.$suffix"
fi

jq -n \
  --arg url "$url" \
  --arg sha256 "$sha256" \
  --argjson downloadBytes "$bytes" \
  --argjson unpackedBytes "$expanded_bytes" \
  --argjson images "$images" \
  '({url: $url, sha256: $sha256, downloadBytes: $downloadBytes,
    unpackedBytes: $unpackedBytes} +
    if ($images | length) > 0 then {images: $images} else {} end)' \
  > "$output"
