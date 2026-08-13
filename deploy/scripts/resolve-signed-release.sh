#!/bin/sh
set -eu

channel=${1:-stable}
release_state=${2:-/var/lib/pocketcoder/release}
output_dir=${3:-/var/lib/pocketcoder/artifacts/release-metadata}
release_base=${RELEASE_BASE:-https://images.pocketcoder.org}
root_public_key=${POCKETCODER_ROOT_PUBLIC_KEY:-/etc/pocketcoder/release-root.pem}
stable_floor=${POCKETCODER_STABLE_SEQUENCE_FLOOR:-1}
max_manifest_bytes=1048576

case "$channel" in stable | beta | nightly) ;; *) echo "invalid release channel" >&2; exit 1 ;; esac
test -s "$root_public_key" || { echo "release root public key is unavailable" >&2; exit 1; }

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
verify=${POCKETCODER_VERIFY_SCRIPT:-$script_dir/../release/verify-signed-payload.sh}
test -x "$verify"
install -d -m 0755 "$release_state" "$output_dir"
tmp_dir=$(mktemp -d "$output_dir/.resolve.XXXXXX")
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fetch_bounded() {
  url=$1
  output=$2
  maximum=$3
  curl -fsSL --retry 3 --retry-delay 2 --max-time 60 \
    --max-filesize "$maximum" -o "$output" "$url"
  bytes=$(wc -c < "$output" | tr -d ' ')
  test "$bytes" -le "$maximum"
}

highest_sequence() {
  field=$1
  fallback=$2
  if test -f "$release_state/sequences.json"; then
    jq -r --arg field "$field" --argjson fallback "$fallback" \
      '.[$field] // $fallback' "$release_state/sequences.json"
  else
    printf '%s\n' "$fallback"
  fi
}

fetch_bounded "$release_base/v1/delegations/root.json" \
  "$tmp_dir/delegation.json" 262144
fetch_bounded "$release_base/v1/delegations/root.json.sig" \
  "$tmp_dir/delegation.sig" 16384
fetch_bounded "$release_base/v1/channels/$channel.json" \
  "$tmp_dir/channel.json" 262144

"$verify" "$tmp_dir/delegation.json" "$tmp_dir/delegation.sig" \
  "$tmp_dir/delegation.json" "$tmp_dir/delegation.sig" \
  "$root_public_key" root
test "$(jq -r '.schemaVersion' "$tmp_dir/delegation.json")" -eq 1
delegation_sequence=$(jq -er '.sequence' "$tmp_dir/delegation.json")
persisted_delegation=$(highest_sequence delegation 0)
test "$delegation_sequence" -ge "$persisted_delegation" || {
  echo "release root delegation replay rejected" >&2
  exit 1
}

pointer_signature_url=$(jq -er '.signature.url' "$tmp_dir/channel.json")
case "$pointer_signature_url" in
  "$release_base/v1/channels/$channel/"*.sig) ;;
  *) echo "channel signature URL is outside its allowlisted path" >&2; exit 1 ;;
esac
fetch_bounded "$pointer_signature_url" "$tmp_dir/channel.sig" 16384
"$verify" "$tmp_dir/channel.json" "$tmp_dir/channel.sig" \
  "$tmp_dir/delegation.json" "$tmp_dir/delegation.sig" \
  "$root_public_key" channel

test "$(jq -r '.channel' "$tmp_dir/channel.json")" = "$channel"
channel_sequence=$(jq -r '.sequence' "$tmp_dir/channel.json")
persisted_channel=$(highest_sequence "channel-$channel" 0)
required_floor=$persisted_channel
if test "$channel" = stable && test "$stable_floor" -gt "$required_floor"; then
  required_floor=$stable_floor
fi
test "$channel_sequence" -ge "$required_floor" || {
  echo "release channel replay rejected" >&2
  exit 1
}

manifest_url=$(jq -er '.manifest.url' "$tmp_dir/channel.json")
manifest_sha=$(jq -er '.manifest.sha256' "$tmp_dir/channel.json")
manifest_bytes=$(jq -er '.manifest.downloadBytes' "$tmp_dir/channel.json")
manifest_signature_url=$(jq -er '.manifest.signature.url' "$tmp_dir/channel.json")
test "$manifest_bytes" -le "$max_manifest_bytes"
test "$manifest_url" = "$release_base/v1/releases/$manifest_sha.json"
test "$manifest_signature_url" = "$release_base/v1/releases/$manifest_sha.json.sig"
fetch_bounded "$manifest_url" "$tmp_dir/manifest.json" "$max_manifest_bytes"
test "$(wc -c < "$tmp_dir/manifest.json" | tr -d ' ')" -eq "$manifest_bytes"
if command -v sha256sum >/dev/null 2>&1; then
  actual_sha=$(sha256sum "$tmp_dir/manifest.json" | cut -d' ' -f1)
else
  actual_sha=$(shasum -a 256 "$tmp_dir/manifest.json" | cut -d' ' -f1)
fi
test "$actual_sha" = "$manifest_sha"
fetch_bounded "$manifest_signature_url" "$tmp_dir/manifest.sig" 16384
"$verify" "$tmp_dir/manifest.json" "$tmp_dir/manifest.sig" \
  "$tmp_dir/delegation.json" "$tmp_dir/delegation.sig" \
  "$root_public_key" release

fetch_bounded "$release_base/v1/revocations/releases.json" \
  "$tmp_dir/revocations.json" 262144
revocation_sequence=$(jq -er '.sequence' "$tmp_dir/revocations.json")
fetch_bounded "$release_base/v1/revocations/releases/$revocation_sequence.sig" \
  "$tmp_dir/revocations.sig" 16384
"$verify" "$tmp_dir/revocations.json" "$tmp_dir/revocations.sig" \
  "$tmp_dir/delegation.json" "$tmp_dir/delegation.sig" \
  "$root_public_key" revocation
persisted_revocation=$(highest_sequence revocation 0)
test "$revocation_sequence" -ge "$persisted_revocation" || {
  echo "release revocation replay rejected" >&2
  exit 1
}

revoked=$(jq -c --arg digest "$manifest_sha" \
  '.revokedReleases[$digest] // null' "$tmp_dir/revocations.json")
if test "$revoked" != null && test "${POCKETCODER_ALLOW_REVOKED_STATUS:-0}" != 1; then
  echo "release $manifest_sha is revoked: $(printf '%s' "$revoked" | jq -r '.reasonCode')" >&2
  exit 1
fi

manifest_output="$output_dir/$manifest_sha.json"
cp "$tmp_dir/manifest.json" "$manifest_output"
chmod 0644 "$manifest_output"
cp "$tmp_dir/revocations.json" "$output_dir/revocations.json"
chmod 0644 "$output_dir/revocations.json"
sequence_tmp="$release_state/sequences.json.tmp.$$"
if test -f "$release_state/sequences.json"; then
  jq --arg channelField "channel-$channel" \
    --argjson channelSequence "$channel_sequence" \
    --argjson revocationSequence "$revocation_sequence" \
    --argjson delegationSequence "$delegation_sequence" '
    . + {($channelField):$channelSequence,revocation:$revocationSequence,
      delegation:$delegationSequence}
  ' "$release_state/sequences.json" > "$sequence_tmp"
else
  jq -n --arg channelField "channel-$channel" \
    --argjson channelSequence "$channel_sequence" \
    --argjson revocationSequence "$revocation_sequence" \
    --argjson delegationSequence "$delegation_sequence" '
    {($channelField):$channelSequence,revocation:$revocationSequence,
      delegation:$delegationSequence}
  ' > "$sequence_tmp"
fi
chmod 0644 "$sequence_tmp"
mv -f "$sequence_tmp" "$release_state/sequences.json"

jq -n --arg channel "$channel" --argjson channelSequence "$channel_sequence" \
  --argjson revocationSequence "$revocation_sequence" \
  --arg manifestSha256 "$manifest_sha" --arg manifestPath "$manifest_output" \
  --arg manifestUrl "$manifest_url" --argjson revoked "$revoked" '
  {schemaVersion:1,channel:$channel,channelSequence:$channelSequence,
    revocationSequence:$revocationSequence,manifestSha256:$manifestSha256,
    manifestPath:$manifestPath,manifestUrl:$manifestUrl,revoked:$revoked}
'
