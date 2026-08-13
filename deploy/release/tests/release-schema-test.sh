#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
release_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_root=$(CDPATH= cd -- "$release_dir/../.." && pwd)
manifest="$release_dir/release-manifest.example.json"
catalog="$release_dir/harnesses.json"
semantic="$repo_root/deploy/scripts/validate-release-contract.sh"
schema_validator="$release_dir/validate-release-schemas.sh"
check_schema=${POCKETCODER_SCHEMA_VALIDATOR:-check-jsonschema}
mutations="$release_dir/fixtures/mutations"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  echo "release schema test: $1" >&2
  exit 1
}

expect_semantic_failure() {
  fixture=$1
  expected=$2
  candidate="$tmp_dir/$(basename "$fixture" .jq).json"
  jq -f "$fixture" "$manifest" > "$candidate"
  if "$semantic" "$candidate" "$catalog" >"$tmp_dir/out" 2>&1; then
    fail "$(basename "$fixture") unexpectedly passed"
  fi
  grep -Fq "$expected" "$tmp_dir/out" || {
    cat "$tmp_dir/out" >&2
    fail "$(basename "$fixture") failed for the wrong reason"
  }
}

expect_schema_failure() {
  fixture=$1
  candidate="$tmp_dir/$(basename "$fixture" .jq).json"
  jq -f "$fixture" "$manifest" > "$candidate"
  if "$check_schema" --schemafile "$release_dir/release-manifest.schema.json" \
      "$candidate" >"$tmp_dir/out" 2>&1; then
    fail "$(basename "$fixture") unexpectedly passed structural validation"
  fi
}

"$schema_validator"
"$semantic" "$manifest" "$catalog"

expect_semantic_failure "$mutations/data-version.jq" "minimumUpgradeFromDataVersion"
expect_semantic_failure "$mutations/source-contract-range.jq" "source contract range"
expect_semantic_failure "$mutations/missing-worker.jq" "Worker API versions"
expect_semantic_failure "$mutations/artifact-sizes.jq" "impossible byte sizes"
expect_semantic_failure "$mutations/artifact-address.jq" "artifact URL"
expect_semantic_failure "$mutations/document-address.jq" "document URL"
expect_semantic_failure "$mutations/json-schema-version.jq" "schemaVersion"
expect_semantic_failure "$mutations/missing-bootstrap-document.jq" "missing document"
expect_semantic_failure "$mutations/choice-bounds.jq" "selection bounds"
expect_semantic_failure "$mutations/choice-option-count.jq" "selection bounds"
expect_semantic_failure "$mutations/missing-catalog-document.jq" "catalog document"
expect_semantic_failure "$mutations/catalog-mismatch.jq" "harness choices"
expect_semantic_failure "$mutations/harness-image.jq" "catalog repository"
expect_semantic_failure "$mutations/duplicate-image.jq" "more than one archive"

expect_schema_failure "$mutations/bad-url-host.jq"
expect_schema_failure "$mutations/non-utc-time.jq"
expect_schema_failure "$mutations/invalid-semver.jq"

oversized="$tmp_dir/oversized.json"
padding="$tmp_dir/padding.txt"
dd if=/dev/zero bs=1048600 count=1 2>/dev/null | tr '\000' x > "$padding"
jq --rawfile padding "$padding" '.extensions = {padding:$padding}' \
  "$manifest" > "$oversized"
if "$semantic" "$oversized" "$catalog" >"$tmp_dir/out" 2>&1; then
  fail "oversized manifest unexpectedly passed"
fi
grep -Fq "pre-parse limit" "$tmp_dir/out" ||
  fail "oversized manifest failed for the wrong reason"

echo "release schema tests passed"
