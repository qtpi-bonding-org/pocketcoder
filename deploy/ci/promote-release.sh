#!/usr/bin/env bash
set -euo pipefail

channel=${1:?channel is required}
manifest_sha=${2:?manifest sha256 is required}
sequence=${3:?new channel sequence is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}
key_id=${POCKETCODER_OPERATIONS_KEY_ID:?POCKETCODER_OPERATIONS_KEY_ID is required}
base_url=${POCKETCODER_RELEASE_BASE:-https://images.pocketcoder.org}

case "$channel" in stable | beta | nightly) ;; *) echo "invalid channel" >&2; exit 1 ;; esac
case "$manifest_sha" in *[!0-9a-f]* | '') echo "invalid manifest digest" >&2; exit 1 ;; esac
test "${#manifest_sha}" -eq 64
case "$sequence" in '' | *[!0-9]*) echo "invalid sequence" >&2; exit 1 ;; esac
test "$sequence" -ge 1
case "$key_id" in test-* | fixture-*) echo "test keys cannot promote production" >&2; exit 1 ;; esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
release_dir=$(CDPATH= cd -- "$script_dir/../release" && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
manifest="$tmp_dir/manifest.json"
manifest_signature="$tmp_dir/manifest.json.sig"
pointer="$tmp_dir/$channel.json"
pointer_signature="$tmp_dir/$channel-$sequence.sig"

aws s3 cp "s3://$bucket/releases/$manifest_sha.json" "$manifest" \
  --endpoint-url "$endpoint" >/dev/null
aws s3 cp "s3://$bucket/releases/$manifest_sha.json.sig" "$manifest_signature" \
  --endpoint-url "$endpoint" >/dev/null
if command -v sha256sum >/dev/null 2>&1; then
  actual_sha=$(sha256sum "$manifest" | cut -d' ' -f1)
else
  actual_sha=$(shasum -a 256 "$manifest" | cut -d' ' -f1)
fi
test "$actual_sha" = "$manifest_sha"
manifest_bytes=$(wc -c < "$manifest" | tr -d ' ')
test "$manifest_bytes" -le 1048576

current="$tmp_dir/current.json"
if aws s3 cp "s3://$bucket/channels/$channel.json" "$current" \
    --endpoint-url "$endpoint" >/dev/null 2>&1; then
  current_sequence=$(jq -r '.sequence' "$current")
  test "$sequence" -gt "$current_sequence" || {
    echo "channel sequence must increase beyond $current_sequence" >&2
    exit 1
  }
fi

jq -S -n --arg channel "$channel" --argjson sequence "$sequence" \
  --arg promotedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg manifestUrl "$base_url/v1/releases/$manifest_sha.json" \
  --arg manifestSha "$manifest_sha" --argjson manifestBytes "$manifest_bytes" \
  --arg manifestSignatureUrl "$base_url/v1/releases/$manifest_sha.json.sig" \
  --arg pointerSignatureUrl "$base_url/v1/channels/$channel/$sequence.sig" \
  --arg keyId "$key_id" '
  {schemaVersion:1,channel:$channel,sequence:$sequence,promotedAt:$promotedAt,
    manifest:{url:$manifestUrl,sha256:$manifestSha,downloadBytes:$manifestBytes,
      signature:{algorithm:"ed25519",keyId:$keyId,url:$manifestSignatureUrl}},
    signature:{algorithm:"ed25519",keyId:$keyId,url:$pointerSignatureUrl}}
' > "$pointer"
"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$release_dir/release-channel-pointer.schema.json" "$pointer"
"$release_dir/sign-payload.sh" "$pointer" channel "$key_id" "$pointer_signature"

aws s3 cp "$pointer_signature" \
  "s3://$bucket/channels/$channel/$sequence.sig" --endpoint-url "$endpoint" \
  --cache-control 'public,max-age=31536000,immutable'
aws s3 cp "$pointer" "s3://$bucket/channels/$channel.json" \
  --endpoint-url "$endpoint" --cache-control 'public,max-age=300,must-revalidate'

echo "promoted $manifest_sha to $channel sequence $sequence"
