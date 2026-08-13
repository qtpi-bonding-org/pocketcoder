#!/usr/bin/env bash
set -euo pipefail

# Publishes a candidate assembled and attested by the NixOS GitHub workflow.
# This intentionally has no signing-key input: GitHub's attestation is the
# release identity, while R2 is only the distribution store.
candidate_dir=${1:?candidate directory is required}
bundle=${2:?Sigstore bundle is required}
endpoint=${R2_ENDPOINT:?R2_ENDPOINT is required}
bucket=${POCKETCODER_RELEASE_BUCKET:-pocketcoder-images}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$script_dir/../.." && pwd)
release_dir="$repo_root/deploy/release"
manifest="$candidate_dir/release-manifest.json"
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
  file=$1 expected_sha=$2 expected_bytes=$3
  test -f "$file" || { echo "missing candidate object: $file" >&2; exit 1; }
  test "$(sha256_file "$file")" = "$expected_sha" || {
    echo "candidate object digest mismatch: $file" >&2; exit 1;
  }
  test "$(wc -c < "$file" | tr -d ' ')" -eq "$expected_bytes" || {
    echo "candidate object size mismatch: $file" >&2; exit 1;
  }
}

publish_immutable() {
  file=$1 key=$2 existing="$tmp_dir/existing"
  if aws s3 cp "s3://$bucket/$key" "$existing" --endpoint-url "$endpoint" >/dev/null 2>&1; then
    cmp -s "$file" "$existing" || {
      echo "refusing to overwrite immutable object: $key" >&2; exit 1;
    }
    return
  fi
  aws s3 cp "$file" "s3://$bucket/$key" --endpoint-url "$endpoint" \
    --cache-control 'public,max-age=31536000,immutable'
}

test -s "$bundle"
test "$(wc -c < "$bundle" | tr -d ' ')" -le $((16 * 1024 * 1024))
"$release_dir/validate-release-schemas.sh"
"${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}" \
  --schemafile "$release_dir/release-manifest.schema.json" "$manifest"
"$repo_root/deploy/scripts/validate-release-contract.sh" "$manifest" \
  "$release_dir/harnesses.json"

jq -c '[.serverFiles, (.osImages[].delivery | select(.kind == "artifact") | .artifact), .images.required[], .images.choices[].options[]][]' "$manifest" |
  while IFS= read -r artifact; do
    sha=$(printf '%s' "$artifact" | jq -r '.sha256')
    name=$(printf '%s' "$artifact" | jq -r '.url | split("/")[-1]')
    verify_file "$artifact_dir/$name" "$sha" "$(printf '%s' "$artifact" | jq -r '.downloadBytes')"
  done

jq -c '.documents[]' "$manifest" | while IFS= read -r document; do
  sha=$(printf '%s' "$document" | jq -r '.sha256')
  name=$(printf '%s' "$document" | jq -r '.url | split("/")[-1]')
  verify_file "$document_dir/$name" "$sha" "$(printf '%s' "$document" | jq -r '.downloadBytes')"
done

manifest_sha=$(sha256_file "$manifest")
jq -r '[.serverFiles, (.osImages[].delivery | select(.kind == "artifact") | .artifact), .images.required[], .images.choices[].options[]][].url | split("/")[-1]' "$manifest" |
  while IFS= read -r name; do publish_immutable "$artifact_dir/$name" "artifacts/$name"; done
jq -r '.documents[].url | split("/")[-1]' "$manifest" |
  while IFS= read -r name; do publish_immutable "$document_dir/$name" "documents/$name"; done
publish_immutable "$manifest" "releases/$manifest_sha.json"
publish_immutable "$bundle" "attestations/releases/$manifest_sha.sigstore.json"

echo "published GitHub-attested NixOS candidate $manifest_sha"
