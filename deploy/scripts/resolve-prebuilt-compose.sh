#!/bin/sh
set -eu

input=${1:?input Compose file is required}
output=${2:?output Compose file is required}

awk '
  /^    image:[[:space:]]+[^[:space:]]+@sha256:/ {
    image = $2
    digest = image
    sub(/.*@sha256:/, "", digest)
    printf "    image: pocketcoder-bundle-%s\n", substr(digest, 1, 16)
    next
  }
  { print }
' "$input" > "$output"
