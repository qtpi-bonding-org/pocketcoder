#!/usr/bin/env bash
set -euo pipefail

candidate_dir=${1:?downloaded CI candidate directory is required}
manifest=${2:-$candidate_dir/release-manifest.json}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}
key_id=${POCKETCODER_OPERATIONS_KEY_ID:?POCKETCODER_OPERATIONS_KEY_ID is required}

case "$key_id" in
  test-* | fixture-*) echo "test signing keys cannot publish production releases" >&2; exit 1 ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
release_dir="$repo_root/deploy/release"
artifact_dir="$candidate_dir/artifacts"
document_dir="$candidate_dir/documents"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

verify_file() {
  file=$1
  expected_sha=$2
  expected_bytes=$3
  test -f "$file" || { echo "missing candidate object: $file" >&2; exit 1; }
  test "$(sha256_file "$file")" = "$expected_sha" || {
    echo "candidate object digest mismatch: $file" >&2; exit 1;
  }
  test "$(wc -c < "$file" | tr -d ' ')" -eq "$expected_bytes" || {
    echo "candidate object size mismatch: $file" >&2; exit 1;
  }
}

publish_immutable() {
  file=$1
  key=$2
  existing="$tmp_dir/existing"
  if aws s3 cp "s3://$bucket/$key" "$existing" --endpoint-url "$endpoint" \
      >/dev/null 2>&1; then
    cmp -s "$file" "$existing" || {
      echo "refusing to overwrite immutable object: $key" >&2
      exit 1
    }
    return
  fi
  aws s3 cp "$file" "s3://$bucket/$key" --endpoint-url "$endpoint" \
    --cache-control 'public,max-age=31536000,immutable'
}

"$release_dir/validate-release-schemas.sh"
"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$release_dir/release-manifest.schema.json" "$manifest"
"$repo_root/deploy/scripts/validate-release-contract.sh" "$manifest" \
  "$release_dir/harnesses.json"

jq -c '
  [
    .serverFiles,
    (.osImages[].delivery | select(.kind == "artifact") | .artifact),
    .images.required[], .images.choices[].options[], .images.optional[]
  ][]
' "$manifest" | while IFS= read -r artifact; do
  sha=$(printf '%s' "$artifact" | jq -r '.sha256')
  url=$(printf '%s' "$artifact" | jq -r '.url')
  name=${url##*/}
  verify_file "$artifact_dir/$name" "$sha" \
    "$(printf '%s' "$artifact" | jq -r '.downloadBytes')"
done

jq -c '.documents[]' "$manifest" | while IFS= read -r document; do
  sha=$(printf '%s' "$document" | jq -r '.sha256')
  url=$(printf '%s' "$document" | jq -r '.url')
  name=${url##*/}
  verify_file "$document_dir/$name" "$sha" \
    "$(printf '%s' "$document" | jq -r '.downloadBytes')"
done

server_files_name=$(jq -r '.serverFiles.url | split("/")[-1]' "$manifest")
tar -xOzf "$artifact_dir/$server_files_name" ./release.json \
  > "$tmp_dir/release.json"
jq -e --slurpfile manifest "$manifest" '
  .schemaVersion == 1 and
  .serverVersion == $manifest[0].serverVersion and
  .sourceCommit == $manifest[0].sourceCommit and
  .serverApiVersion == $manifest[0].compatibility.server.apiVersion and
  .dataVersion == $manifest[0].dataVersion and
  .deploymentContractVersion ==
    $manifest[0].compatibility.deployment.contractVersion
' "$tmp_dir/release.json" >/dev/null || {
  echo "serverFiles release.json does not match the manifest" >&2
  exit 1
}

manifest_sha=$(sha256_file "$manifest")
manifest_bytes=$(wc -c < "$manifest" | tr -d ' ')
test "$manifest_bytes" -le 1048576
signature="$tmp_dir/$manifest_sha.json.sig"
"$release_dir/sign-payload.sh" "$manifest" release "$key_id" "$signature"

jq -r '
  [
    .serverFiles,
    (.osImages[].delivery | select(.kind == "artifact") | .artifact),
    .images.required[], .images.choices[].options[], .images.optional[]
  ][].url | split("/")[-1]
' "$manifest" | while IFS= read -r name; do
  publish_immutable "$artifact_dir/$name" "artifacts/$name"
done
jq -r '.documents[].url | split("/")[-1]' "$manifest" |
  while IFS= read -r name; do
    publish_immutable "$document_dir/$name" "documents/$name"
  done
publish_immutable "$manifest" "releases/$manifest_sha.json"
publish_immutable "$signature" "releases/$manifest_sha.json.sig"

jq -n --arg sha256 "$manifest_sha" --argjson downloadBytes "$manifest_bytes" \
  '{schemaVersion:1,manifestSha256:$sha256,downloadBytes:$downloadBytes}'
