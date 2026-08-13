#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
definitions="$script_dir/schema-definitions.json"

for schema in \
  release-manifest.schema.json \
  release-channel-pointer.schema.json \
  release-revocation.schema.json \
  signature-envelope.schema.json \
  root-delegation.schema.json \
  harnesses.schema.json \
  deployment-sizing.schema.json
do
  target="$script_dir/$schema"
  tmp="$target.tmp"
  jq --slurpfile common "$definitions" \
    '."$defs" = ((."$defs" // {}) + $common[0]."$defs")' \
    "$target" > "$tmp"
  mv "$tmp" "$target"
done
