#!/usr/bin/env bash
set -euo pipefail

# Checks the public release contract through the same image-relay URLs used by
# clients. This is intentionally OAuth-free: it checks PocketCoder-owned
# infrastructure, not a user's deployment.

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
release_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_root=$(CDPATH= cd -- "$release_dir/../.." && pwd)
base_url=${POCKETCODER_RELEASE_BASE:-https://images.relay.pocketcoder.org}
schema_validator=${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}
max_manifest_bytes=${POCKETCODER_MAX_MANIFEST_BYTES:-1048576}

if [[ ${1:-} == --help ]]; then
  cat <<'USAGE'
usage: public-release-check.sh [channel ...]

Checks the public PocketCoder release contract. With no arguments, stable is
checked. Set POCKETCODER_RELEASE_BASE to test another relay deployment.
USAGE
  exit 0
fi

if (( $# )); then
  channels=("$@")
else
  read -r -a channels <<< "${POCKETCODER_PUBLIC_RELEASE_CHANNELS:-stable}"
fi

for channel in "${channels[@]}"; do
  case "$channel" in
    stable|beta|nightly) ;;
    *) echo "invalid public release channel: $channel" >&2; exit 2 ;;
  esac
done

for command in curl jq "$schema_validator"; do
  command -v "$command" >/dev/null || {
    echo "required command is unavailable: $command" >&2
    exit 2
  }
done

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fail() {
  echo "public release check: $*" >&2
  exit 1
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

header() {
  local name=$1 file=$2
  awk -F': *' -v wanted="${name,,}" \
    'tolower($1) == wanted { value=$2 } END { sub(/[\r\n]+$/, "", value); print value }' \
    "$file"
}

normalise_header() {
  tr -d '[:space:]'
}

head_object() {
  local url=$1 expected_type=$2 expected_cache=$3 expected_bytes=${4:-}
  local headers="$tmp_dir/headers-$object_counter"
  object_counter=$((object_counter + 1))

  curl -fsS --max-time 30 -D "$headers" -o /dev/null "$url" ||
    fail "object is not reachable: $url"
  grep -Eq '^HTTP/[0-9.]+ 200([[:space:]]|$)' "$headers" ||
    fail "object did not return HTTP 200: $url"

  local actual_type actual_cache actual_bytes
  actual_type=$(header content-type "$headers" | normalise_header)
  actual_cache=$(header cache-control "$headers" | normalise_header)
  actual_bytes=$(header content-length "$headers" | tr -d '[:space:]')
  [[ "$actual_type" == "${expected_type//[[:space:]]/}" ]] ||
    fail "wrong Content-Type for $url: got ${actual_type:-<missing>}, expected $expected_type"
  [[ "$actual_cache" == "${expected_cache//[[:space:]]/}" ]] ||
    fail "wrong Cache-Control for $url: got ${actual_cache:-<missing>}, expected $expected_cache"
  if [[ -n "$expected_bytes" ]]; then
    [[ "$actual_bytes" == "$expected_bytes" ]] ||
      fail "wrong Content-Length for $url: got ${actual_bytes:-<missing>}, expected $expected_bytes"
  fi
}

check_content_addressed_object() {
  local url=$1 expected_sha=$2 expected_bytes=$3 expected_type=$4
  head_object "$url" "$expected_type" 'public,max-age=31536000,immutable' "$expected_bytes"
  local body="$tmp_dir/object-$object_counter"
  object_counter=$((object_counter + 1))
  curl -fsSL --max-time 300 -o "$body" "$url" || fail "could not download: $url"
  [[ "$(wc -c < "$body" | tr -d '[:space:]')" == "$expected_bytes" ]] ||
    fail "downloaded byte count does not match for $url"
  [[ "$(sha256_file "$body")" == "$expected_sha" ]] ||
    fail "downloaded SHA-256 does not match for $url"
}

check_health() {
  local url=$1 body="$tmp_dir/health.json"
  curl -fsSL --max-time 30 -o "$body" "$url" || fail "health route is unavailable: $url"
  jq -e '.status == "ok"' "$body" >/dev/null || fail "health route returned an invalid response: $url"
}

object_counter=0
check_health "$base_url/v1/health"
check_health "$base_url/health"
echo "reachable: relay health routes"

revocations="$tmp_dir/revocations.json"
head_object "$base_url/v1/revocations/releases.json" application/json \
  'public,max-age=300,must-revalidate'
curl -fsSL --max-time 30 -o "$revocations" "$base_url/v1/revocations/releases.json" ||
  fail 'revocation document could not be downloaded'
"$schema_validator" --schemafile "$release_dir/release-revocation.schema.json" "$revocations" >/dev/null ||
  fail 'revocation document does not match its schema'
revocation_sequence=$(jq -er '.sequence | select(type == "number" and . >= 1)' "$revocations") ||
  fail 'revocation baseline has no positive sequence'
revocation_signature="$base_url/v1/attestations/revocations/releases/$revocation_sequence.sigstore.json"
head_object "$revocation_signature" application/json \
  'public,max-age=31536000,immutable'
echo "verified: revocation baseline sequence $revocation_sequence and signature"

for channel in "${channels[@]}"; do
  pointer="$tmp_dir/$channel-pointer.json"
  pointer_url="$base_url/v1/channels/$channel.json"
  head_object "$pointer_url" application/json 'public,max-age=300,must-revalidate'
  curl -fsSL --max-time 30 -o "$pointer" "$pointer_url" || fail "could not download $pointer_url"
  "$schema_validator" --schemafile "$release_dir/release-channel-pointer.schema.json" "$pointer" >/dev/null ||
    fail "$channel pointer does not match its schema"

  pointer_channel=$(jq -er '.channel' "$pointer") || fail "$channel pointer has no channel"
  [[ "$pointer_channel" == "$channel" ]] || fail "$channel pointer identifies itself as $pointer_channel"
  sequence=$(jq -er '.sequence' "$pointer") || fail "$channel pointer has no sequence"
  pointer_signature=$(jq -er '.attestation.url' "$pointer") || fail "$channel pointer has no signature URL"
  expected_pointer_signature="$base_url/v1/attestations/channels/$channel/$sequence.sigstore.json"
  [[ "$pointer_signature" == "$expected_pointer_signature" ]] ||
    fail "$channel pointer signature URL is outside the public contract"
  head_object "$pointer_signature" application/json 'public,max-age=31536000,immutable'

  manifest_url=$(jq -er '.manifest.url' "$pointer")
  manifest_sha=$(jq -er '.manifest.sha256' "$pointer")
  manifest_bytes=$(jq -er '.manifest.downloadBytes' "$pointer")
  expected_manifest_url="$base_url/v1/releases/$manifest_sha.json"
  [[ "$manifest_url" == "$expected_manifest_url" ]] || fail "$channel pointer manifest URL is not content-addressed"
  manifest_signature=$(jq -er '.manifest.attestation.url' "$pointer")
  expected_manifest_signature="$base_url/v1/attestations/releases/$manifest_sha.sigstore.json"
  [[ "$manifest_signature" == "$expected_manifest_signature" ]] ||
    fail "$channel manifest signature URL is outside the public contract"
  head_object "$manifest_signature" application/json 'public,max-age=31536000,immutable'

  manifest="$tmp_dir/$channel-manifest.json"
  head_object "$manifest_url" application/json 'public,max-age=31536000,immutable' "$manifest_bytes"
  curl -fsSL --max-time 300 -o "$manifest" "$manifest_url" || fail "could not download $manifest_url"
  [[ "$(wc -c < "$manifest" | tr -d '[:space:]')" == "$manifest_bytes" ]] || fail "$channel manifest byte count does not match"
  [[ "$(sha256_file "$manifest")" == "$manifest_sha" ]] || fail "$channel manifest hash does not match"
  [[ "$manifest_bytes" -le "$max_manifest_bytes" ]] || fail "$channel manifest exceeds the size limit"
  "$schema_validator" --schemafile "$release_dir/release-manifest.schema.json" "$manifest" >/dev/null ||
    fail "$channel manifest does not match its schema"
  "$repo_root/deploy/scripts/validate-release-contract.sh" "$manifest" \
    "$release_dir/harnesses.json" "$manifest_bytes" || fail "$channel manifest failed semantic validation"
  jq -e --arg sha "$manifest_sha" '.revokedReleases[$sha] == null' "$revocations" >/dev/null ||
    fail "$channel release $manifest_sha is revoked"

  while IFS=$'\t' read -r url sha bytes media_type; do
    [[ -n "$url" ]] || continue
    case "$media_type" in
      application/json) content_type=application/json ;;
      text/plain) content_type='text/plain; charset=utf-8' ;;
      text/x-shellscript) content_type='text/x-shellscript; charset=utf-8' ;;
      text/x-go) content_type='text/x-go; charset=utf-8' ;;
      *) fail "unsupported document media type: $media_type" ;;
    esac
    check_content_addressed_object "$url" "$sha" "$bytes" "$content_type"
  done < <(jq -r '.documents | to_entries[] | [.value.url, .value.sha256, (.value.downloadBytes|tostring), .value.mediaType] | @tsv' "$manifest")

  while IFS=$'\t' read -r url sha bytes; do
    [[ -n "$url" ]] || continue
    check_content_addressed_object "$url" "$sha" "$bytes" application/gzip
  done < <(jq -r '[.serverFiles, (.osImages[].delivery | select(.kind == "artifact") | .artifact), .images.required[], .images.choices[].options[]] | .[] | [.url, .sha256, (.downloadBytes|tostring)] | @tsv' "$manifest")

  echo "verified: $channel pointer, manifest $manifest_sha, signatures, referenced objects, headers, hashes, and revocation status"
done

echo 'public release checks passed'
