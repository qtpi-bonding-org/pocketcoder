#!/usr/bin/env bash
set -euo pipefail

channel=${1:?channel is required}
# channel_path is the (possibly branch-qualified, e.g. "nightly-staging")
# object-path segment this pointer is actually published under -- see
# internal/release/resolver.go's ChannelPath for why this must differ from
# the bare channel field for any non-main branch. The caller (the workflow)
# derives it from the triggering ref so it's never a value a human types.
channel_path=${2:?channel_path is required}
manifest_sha=${3:?manifest sha256 is required}
sequence=${4:?sequence is required}
output=${5:?output path is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}
base_url=${POCKETCODER_RELEASE_BASE:-https://images.relay.pocketcoder.org}

case "$channel" in stable | beta | nightly) ;; *) echo "invalid channel" >&2; exit 1 ;; esac
case "$channel_path" in "$channel" | "$channel"-*) ;; *) echo "invalid channel_path" >&2; exit 1 ;; esac
case "$manifest_sha" in *[!0-9a-f]* | '') echo "invalid manifest digest" >&2; exit 1 ;; esac
test "${#manifest_sha}" -eq 64
case "$sequence" in
  next) ;;
  '' | *[!0-9]*) echo "invalid sequence" >&2; exit 1 ;;
  *) test "$sequence" -ge 1 ;;
esac

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
manifest="$tmp_dir/manifest.json"
aws s3 cp "s3://$bucket/releases/$manifest_sha.json" "$manifest" --endpoint-url "$endpoint" >/dev/null
test "$(sha256sum "$manifest" | cut -d' ' -f1)" = "$manifest_sha"
manifest_bytes=$(wc -c < "$manifest" | tr -d ' ')
test "$manifest_bytes" -le 1048576

current="$tmp_dir/current.json"
if aws s3 cp "s3://$bucket/channels/$channel_path.json" "$current" --endpoint-url "$endpoint" >/dev/null 2>&1; then
  current_sequence=$(jq -r '.sequence' "$current")
  if [ "$sequence" = next ]; then
    sequence=$((current_sequence + 1))
  else
    test "$sequence" -gt "$current_sequence" || { echo "channel sequence must increase" >&2; exit 1; }
  fi
elif [ "$sequence" = next ]; then
  sequence=1
fi

jq -S -n --arg channel "$channel" --argjson sequence "$sequence" \
  --arg promotedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg manifestUrl "$base_url/v1/releases/$manifest_sha.json" \
  --arg manifestSha "$manifest_sha" --argjson manifestBytes "$manifest_bytes" \
  --arg manifestBundle "$base_url/v1/attestations/releases/$manifest_sha.sigstore.json" \
  --arg pointerBundle "$base_url/v1/attestations/channels/$channel_path/$sequence.sigstore.json" \
  '{schemaVersion:1,channel:$channel,sequence:$sequence,promotedAt:$promotedAt,
    manifest:{url:$manifestUrl,sha256:$manifestSha,downloadBytes:$manifestBytes,
      attestation:{url:$manifestBundle}},attestation:{url:$pointerBundle}}' > "$output"

"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$(dirname "$0")/../release/release-channel-pointer.schema.json" "$output"
