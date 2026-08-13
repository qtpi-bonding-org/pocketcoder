#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
manifest="$repo_root/deploy/release/release-manifest.example.json"
catalog="$repo_root/deploy/release/harnesses.json"
validator="$repo_root/deploy/scripts/validate-release-contract.sh"
resolver="$repo_root/deploy/scripts/resolve-release-artifacts.sh"
builder="$repo_root/deploy/scripts/build-deployment-artifact.sh"
metadata_writer="$repo_root/deploy/scripts/write-artifact-metadata.sh"
assembler="$repo_root/deploy/ci/assemble-release-manifest.sh"
release=0123456789abcdef0123456789abcdef01234567
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_failure() {
  if "$@" >/dev/null 2>&1; then
    fail "command unexpectedly succeeded: $*"
  fi
}

"$validator" "$manifest" "$catalog"

resolved="$tmp_dir/resolved.json"
"$resolver" "$manifest" "$catalog" codex goose > "$resolved"
test "$(jq -r 'map(.id) | join(",")' "$resolved")" = \
  "server-files,server,goose,codex" ||
  fail "resolver did not preserve catalog order"
expect_failure "$resolver" "$manifest" "$catalog"
expect_failure "$resolver" "$manifest" "$catalog" goose goose
expect_failure "$resolver" "$manifest" "$catalog" unknown

"$builder" "$release" "$tmp_dir/server-files.tar.gz"
tar -tzf "$tmp_dir/server-files.tar.gz" > "$tmp_dir/files.txt"
for path in \
  ./release.json \
  ./docker-compose.prebuilt.yml \
  ./bin/pocketcoder-release \
  ./deploy/scripts/install-release-metadata-timer.sh \
  ./deploy/scripts/prepare-runtime-env.sh
do
  grep -Fqx "$path" "$tmp_dir/files.txt" || fail "missing $path"
done
for retired in \
  ./deploy/scripts/activate-release.sh \
  ./deploy/scripts/manage-update-snapshot.sh \
  ./deploy/scripts/update-release.sh
do
  ! grep -Fqx "$retired" "$tmp_dir/files.txt" ||
    fail "retired OS mutation script was packaged: $retired"
done
! grep -q '/mcp.env$' "$tmp_dir/files.txt" ||
  fail "generated MCP environment leaked into server files"
! grep -q 'Dockerfile' "$tmp_dir/files.txt" ||
  fail "source build contexts leaked into server files"

tar -xOzf "$tmp_dir/server-files.tar.gz" ./release.json |
  jq -e --arg release "$release" '
    .schemaVersion == 1 and .sourceCommit == $release and
    .serverApiVersion == 1 and .dataVersion == 1 and
    .deploymentContractVersion == 1
  ' >/dev/null || fail "internal release identity is invalid"

expanded=$(gzip -dc "$tmp_dir/server-files.tar.gz" | wc -c | tr -d ' ')
"$metadata_writer" "$tmp_dir/server-files.json" auto \
  "$tmp_dir/server-files.tar.gz" "$expanded"
jq -e '
  (.url | test("/v1/artifacts/[0-9a-f]{64}[.]tar[.]gz$")) and
  (.sha256 | test("^[0-9a-f]{64}$")) and
  .downloadBytes > 0 and .unpackedBytes >= .downloadBytes and
  (has("images") | not)
' "$tmp_dir/server-files.json" >/dev/null ||
  fail "v1 server-files metadata is invalid"

# The canonical producer must package every inspectable document type. This
# catches producer/relay/client drift when a new source media type is added.
jq '.osImages.nixos.delivery.artifact' "$manifest" > "$tmp_dir/nixos.json"
jq '{schemaVersion:1,sourceCommit:.sourceCommit,serverFiles:.serverFiles,
  images:{required:.images.required,
    choices:{"coding-harnesses":.images.choices["coding-harnesses"].options},
    registry:.images.registry}}' "$manifest" > "$tmp_dir/artifacts.json"
mkdir -p "$tmp_dir/documents"
POCKETCODER_BUILT_AT=2026-08-12T19:00:00Z \
  "$assembler" "$release" "$tmp_dir/nixos.json" \
    "$tmp_dir/artifacts.json" "$tmp_dir/assembled.json" \
    "$tmp_dir/documents"
jq -e '
  .documents["release-activation"] as $document |
  $document.mediaType == "text/x-go" and
  ($document.url | test("/v1/documents/[0-9a-f]{64}[.]go$"))
' "$tmp_dir/assembled.json" >/dev/null ||
  fail "Go walkthrough source is not a content-addressed release document"
test -f "$tmp_dir/documents/$(jq -r \
  '.documents["release-activation"].sha256' "$tmp_dir/assembled.json").go" ||
  fail "Go walkthrough document was not emitted"
grep -Fq "(?:json|txt|sh|go)" \
  "$repo_root/workers/image-relay/src/index.ts" ||
  fail "image-relay does not serve Go walkthrough documents"
grep -Fq "text/x-go; charset=utf-8" \
  "$repo_root/workers/image-relay/src/index.ts" ||
  fail "image-relay does not label Go walkthrough documents"

# The periodic checker is metadata-only. Activation and update commands must
# never be reachable from the timer installer or NixOS timer definition.
! grep -Eq 'update-release[.]sh|activate-release[.]sh' \
  "$repo_root/deploy/scripts/install-release-metadata-timer.sh" ||
  fail "Standard Linux metadata timer can activate a release"
! grep -Eq 'update-release[.]sh|activate-release[.]sh' \
  "$repo_root/deploy/nixos/bootstrap.nix" ||
  fail "NixOS metadata timer can activate a release"
grep -q 'RandomizedDelaySec = "1h"' "$repo_root/deploy/nixos/bootstrap.nix" ||
  fail "NixOS metadata timer has no randomized delay"
grep -q 'RandomizedDelaySec=1h' \
  "$repo_root/deploy/scripts/install-release-metadata-timer.sh" ||
  fail "Standard Linux metadata timer has no randomized delay"

echo "release contract tests passed"
