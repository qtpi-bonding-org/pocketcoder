#!/bin/sh
set -eu

input=${1:?input Compose file is required}
output=${2:?output Compose file is required}
release=${3:?40-character release commit is required}
catalog_file=${4:?harness catalog file is required}

case "$release" in
  *[!0-9a-f]*)
    echo "release must be a 40-character lowercase Git commit" >&2
    exit 1
    ;;
esac
if [ "${#release}" -ne 40 ]; then
  echo "release must be a 40-character lowercase Git commit" >&2
  exit 1
fi

mapping_file=$(mktemp)
trap 'rm -f "$mapping_file"' EXIT
jq -r '.harnesses[] | [.composeService, .imageRepository] | @tsv' \
  "$catalog_file" > "$mapping_file"

awk -v release="$release" '
  NR == FNR {
    harness_image[$1] = $2
    next
  }
  /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
    service = $1
    sub(/:$/, "", service)
  }
  /^    build:[[:space:]]*$/ {
    skipping_build = 1
    next
  }
  skipping_build && /^      / { next }
  skipping_build { skipping_build = 0 }
  /^    image:[[:space:]]+/ {
    image = $2
    if (service == "pocketbase") {
      image = "pocketcoder-pocketbase:" release
    } else if (service == "mcp-gateway") {
      image = "pocketcoder-mcp-gateway:" release
    } else if (service == "pocket-memory") {
      image = "pocketcoder-memory:" release
    } else if (service == "ollama") {
      image = "pocketcoder-ollama:" release
    } else if (service in harness_image) {
      image = harness_image[service] ":" release
    } else if (image ~ /@sha256:/) {
      digest = image
      sub(/.*@sha256:/, "", digest)
      image = "pocketcoder-bundle-" substr(digest, 1, 16)
    }
    print "    image: " image
    next
  }
  { print }
' "$mapping_file" "$input" > "$output"

if grep -q '^    build:' "$output"; then
  echo "release Compose file still contains a build definition" >&2
  exit 1
fi
