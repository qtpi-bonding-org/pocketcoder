#!/usr/bin/env bash
set -euo pipefail

payload=${1:?revocation JSON is required}
bundle=${2:?Sigstore bundle is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}
release_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../release" && pwd)

test -s "$bundle"
test "$(wc -c < "$bundle" | tr -d ' ')" -le $((16 * 1024 * 1024))
"$release_dir/validate-release-schemas.sh"
"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$release_dir/release-revocation.schema.json" "$payload"

sequence=$(jq -r '.sequence' "$payload")
current=$(mktemp)
trap 'rm -f "$current"' EXIT
if aws s3 cp "s3://$bucket/revocations/releases.json" "$current" --endpoint-url "$endpoint" >/dev/null 2>&1; then
  current_sequence=$(jq -r '.sequence' "$current")
  test "$sequence" -gt "$current_sequence" || { echo "revocation sequence must increase" >&2; exit 1; }
fi

aws s3 cp "$bundle" "s3://$bucket/attestations/revocations/releases/$sequence.sigstore.json" \
  --endpoint-url "$endpoint" --cache-control 'public,max-age=31536000,immutable'
aws s3 cp "$payload" "s3://$bucket/revocations/releases.json" \
  --endpoint-url "$endpoint" --cache-control 'public,max-age=300,must-revalidate'
