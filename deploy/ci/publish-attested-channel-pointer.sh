#!/usr/bin/env bash
set -euo pipefail

pointer=${1:?pointer JSON is required}
bundle=${2:?pointer Sigstore bundle is required}
# See prepare-attested-channel-pointer.sh: the (possibly branch-qualified)
# object-path segment this pointer is actually published under, distinct
# from the bare "channel" field embedded in the pointer JSON.
channel_path=${3:?channel_path is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}

test -s "$bundle"
test "$(wc -c < "$bundle" | tr -d ' ')" -le $((16 * 1024 * 1024))
channel=$(jq -r '.channel' "$pointer")
sequence=$(jq -r '.sequence' "$pointer")
case "$channel_path" in "$channel" | "$channel"-*) ;; *) echo "invalid channel_path" >&2; exit 1 ;; esac
"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$(dirname "$0")/../release/release-channel-pointer.schema.json" "$pointer"
aws s3 cp "$bundle" "s3://$bucket/attestations/channels/$channel_path/$sequence.sigstore.json" \
  --endpoint-url "$endpoint" --cache-control 'public,max-age=31536000,immutable'
aws s3 cp "$pointer" "s3://$bucket/channels/$channel_path.json" \
  --endpoint-url "$endpoint" --cache-control 'public,max-age=300,must-revalidate'
