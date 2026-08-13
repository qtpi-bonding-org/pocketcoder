#!/usr/bin/env bash
set -euo pipefail

payload=${1:?root delegation JSON path is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
release_dir=$(CDPATH= cd -- "$script_dir/../release" && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$release_dir/root-delegation.schema.json" "$payload"
sequence=$(jq -r '.sequence' "$payload")
key_id=$(jq -r '.rootKeyId' "$payload")
case "$key_id" in
  test-* | fixture-*)
    echo "test root keys cannot publish production delegation" >&2
    exit 1
    ;;
esac

current="$tmp_dir/current.json"
if aws s3 cp "s3://$bucket/delegations/root.json" "$current" \
    --endpoint-url "$endpoint" >/dev/null 2>&1; then
  current_sequence=$(jq -r '.sequence' "$current")
  test "$sequence" -gt "$current_sequence" || {
    echo "root delegation sequence must increase beyond $current_sequence" >&2
    exit 1
  }
fi

signature="$tmp_dir/root.json.sig"
"$release_dir/sign-payload.sh" "$payload" root "$key_id" "$signature"

# The signature is written first. A consumer racing a key rotation may fail
# closed briefly, then succeeds once the matching delegation replaces it.
aws s3 cp "$signature" "s3://$bucket/delegations/root.json.sig" \
  --endpoint-url "$endpoint" \
  --cache-control 'public,max-age=300,must-revalidate'
aws s3 cp "$payload" "s3://$bucket/delegations/root.json" \
  --endpoint-url "$endpoint" \
  --cache-control 'public,max-age=300,must-revalidate'

echo "published root delegation sequence $sequence"
