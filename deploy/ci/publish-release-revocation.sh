#!/usr/bin/env bash
set -euo pipefail

payload=${1:?revocation JSON path is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}
key_id=${POCKETCODER_OPERATIONS_KEY_ID:?POCKETCODER_OPERATIONS_KEY_ID is required}
case "$key_id" in test-* | fixture-*) echo "test keys cannot revoke production" >&2; exit 1 ;; esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
release_dir=$(CDPATH= cd -- "$script_dir/../release" && pwd)
sequence=$(jq -r '.sequence' "$payload")
case "$sequence" in '' | *[!0-9]*) echo "invalid revocation sequence" >&2; exit 1 ;; esac
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
signature="$tmp_dir/$sequence.sig"

"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$release_dir/release-revocation.schema.json" "$payload"

current="$tmp_dir/current.json"
if aws s3 cp "s3://$bucket/revocations/releases.json" "$current" \
    --endpoint-url "$endpoint" >/dev/null 2>&1; then
  current_sequence=$(jq -r '.sequence' "$current")
  test "$sequence" -gt "$current_sequence" || {
    echo "revocation sequence must increase beyond $current_sequence" >&2
    exit 1
  }
fi

"$release_dir/sign-payload.sh" "$payload" revocation "$key_id" "$signature"
aws s3 cp "$signature" "s3://$bucket/revocations/releases/$sequence.sig" \
  --endpoint-url "$endpoint" --cache-control 'public,max-age=31536000,immutable'
aws s3 cp "$payload" "s3://$bucket/revocations/releases.json" \
  --endpoint-url "$endpoint" --cache-control 'public,max-age=300,must-revalidate'

echo "published revocation sequence $sequence"
