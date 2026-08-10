#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
catalog="$repo_root/deploy/release/harnesses.json"
manifest="$repo_root/deploy/release/fixtures/release-manifest-v2.json"
validator="$repo_root/deploy/scripts/validate-release-contract.sh"
resolver="$repo_root/deploy/scripts/resolve-release-artifacts.sh"
generator="$repo_root/deploy/scripts/generate-harness-catalog-dart.sh"
generated_catalog="$repo_root/client/packages/pocketcoder_pro/lib/domain/deployment/harness_catalog_data.dart"
compose_resolver="$repo_root/deploy/scripts/resolve-release-compose.sh"
deployment_builder="$repo_root/deploy/scripts/build-deployment-artifact.sh"
metadata_writer="$repo_root/deploy/scripts/write-artifact-metadata.sh"
image_installer="$repo_root/deploy/scripts/install-release-images.sh"
release_activator="$repo_root/deploy/scripts/activate-release.sh"
release_updater="$repo_root/deploy/scripts/update-release.sh"
release=0123456789abcdef0123456789abcdef01234567
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

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
"$generator" "$catalog" "$tmp_dir/harness_catalog_data.dart"
cmp "$tmp_dir/harness_catalog_data.dart" "$generated_catalog" >/dev/null ||
  fail "generated Dart catalog is stale"

resolved="$tmp_dir/resolved.json"
"$resolver" "$manifest" "$catalog" codex goose > "$resolved"
test "$(jq -r 'map(.id) | join(",")' "$resolved")" = \
  "deployment,core,goose,codex" || fail "resolver did not use catalog order"
test "$(jq 'length' "$resolved")" -eq 4 || fail "resolver returned extra artifacts"
test "$(jq '[.[] | select(.id == "claude-code" or .id == "opencode")] | length' "$resolved")" -eq 0 || \
  fail "resolver included an unselected harness"

expect_failure "$resolver" "$manifest" "$catalog"
expect_failure "$resolver" "$manifest" "$catalog" goose goose
expect_failure "$resolver" "$manifest" "$catalog" unknown

jq '.unexpected = true' "$manifest" > "$tmp_dir/unknown-top-level.json"
expect_failure "$validator" "$tmp_dir/unknown-top-level.json" "$catalog"

jq '.sourceUrl = "https://example.test/tree/wrong"' "$manifest" > "$tmp_dir/mixed-release.json"
expect_failure "$validator" "$tmp_dir/mixed-release.json" "$catalog"

jq '.harnesses.unlisted = .harnesses.goose' "$manifest" > "$tmp_dir/unknown-harness.json"
expect_failure "$validator" "$tmp_dir/unknown-harness.json" "$catalog"

jq '.defaultHarness = "missing"' "$catalog" > "$tmp_dir/bad-catalog.json"
expect_failure "$validator" "$manifest" "$tmp_dir/bad-catalog.json"

"$compose_resolver" "$repo_root/docker-compose.yml" \
  "$tmp_dir/docker-compose.prebuilt.yml" "$release" "$catalog"
! grep -q '^    build:' "$tmp_dir/docker-compose.prebuilt.yml" ||
  fail "release Compose retained a build definition"
grep -q "image: pocketcoder-pocketbase:$release" \
  "$tmp_dir/docker-compose.prebuilt.yml" || fail "core image is not release-tagged"
grep -q "image: pocketcoder-harness-goose:$release" \
  "$tmp_dir/docker-compose.prebuilt.yml" || fail "Goose image is not release-tagged"
grep -q "image: pocketcoder-ollama:$release" \
  "$tmp_dir/docker-compose.prebuilt.yml" || fail "Ollama image is not release-tagged"
grep -q 'image: pocketcoder-bundle-9e4b9e7517a6b660' \
  "$tmp_dir/docker-compose.prebuilt.yml" || fail "digest image alias is missing"

"$deployment_builder" "$release" "$tmp_dir/deployment.tar.gz"
tar -tzf "$tmp_dir/deployment.tar.gz" > "$tmp_dir/deployment-files.txt"
grep -q '^\./docker-compose.prebuilt.yml$' "$tmp_dir/deployment-files.txt" ||
  fail "deployment Compose file is missing"
grep -q '^\./deploy/release/harnesses.json$' "$tmp_dir/deployment-files.txt" ||
  fail "deployment harness catalog is missing"
grep -q '^\./deploy/scripts/activate-release.sh$' "$tmp_dir/deployment-files.txt" ||
  fail "shared release activator is missing"
grep -q '^\./deploy/scripts/prepare-runtime-env.sh$' "$tmp_dir/deployment-files.txt" ||
  fail "shared runtime preparation is missing"
grep -q '^\./deploy/scripts/update-release.sh$' "$tmp_dir/deployment-files.txt" ||
  fail "verified release updater is missing"
! grep -q '^\./deploy/scripts/build-' "$tmp_dir/deployment-files.txt" ||
  fail "CI build scripts leaked into the runtime artifact"
grep -q '^\./server/sqlpage/dashboard/index.sql$' "$tmp_dir/deployment-files.txt" ||
  fail "deployment bind mount is missing"
! grep -q '/mcp.env$' "$tmp_dir/deployment-files.txt" ||
  fail "generated MCP environment leaked into deployment artifact"
! grep -q 'Dockerfile' "$tmp_dir/deployment-files.txt" ||
  fail "source build contexts leaked into deployment artifact"
tar -xOzf "$tmp_dir/deployment.tar.gz" ./release.json \
  | jq -e --arg release "$release" \
      '.schemaVersion == 1 and .manifestSchemaVersion == 2 and .release == $release' \
      >/dev/null || fail "deployment release marker is invalid"
expanded_bytes=$(gzip -dc "$tmp_dir/deployment.tar.gz" | wc -c | tr -d ' ')
"$metadata_writer" "$tmp_dir/deployment.json" \
  "https://images.pocketcoder.org/pocketcoder-deployment-$release.tar.gz" \
  "$tmp_dir/deployment.tar.gz" "$expanded_bytes"
jq -e '.bytes > 0 and .expandedBytes >= .bytes and .images == []' \
  "$tmp_dir/deployment.json" >/dev/null || fail "artifact metadata is invalid"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  core_images=$(docker compose -f "$tmp_dir/docker-compose.prebuilt.yml" config --images)
  ! printf '%s\n' "$core_images" | grep -q 'pocketcoder-ollama' ||
    fail "Ollama is still part of the default Compose set"
  ! printf '%s\n' "$core_images" | grep -q 'pocketcoder-harness-' ||
    fail "a harness is still part of the default Compose set"
fi

fake_bin="$tmp_dir/fake-bin"
mkdir -p "$fake_bin" "$tmp_dir/artifacts" "$tmp_dir/status"
printf '%s' core-payload | gzip > "$tmp_dir/core.tar.gz"
printf '%s' goose-payload | gzip > "$tmp_dir/goose.tar.gz"
if command -v sha256sum >/dev/null 2>&1; then
  core_sha=$(sha256sum "$tmp_dir/core.tar.gz" | cut -d' ' -f1)
  goose_sha=$(sha256sum "$tmp_dir/goose.tar.gz" | cut -d' ' -f1)
else
  core_sha=$(shasum -a 256 "$tmp_dir/core.tar.gz" | cut -d' ' -f1)
  goose_sha=$(shasum -a 256 "$tmp_dir/goose.tar.gz" | cut -d' ' -f1)
fi
core_bytes=$(wc -c < "$tmp_dir/core.tar.gz" | tr -d ' ')
goose_bytes=$(wc -c < "$tmp_dir/goose.tar.gz" | tr -d ' ')
jq --arg coreSha "$core_sha" --argjson coreBytes "$core_bytes" \
  --arg gooseSha "$goose_sha" --argjson gooseBytes "$goose_bytes" '
    .core.url = "https://fixtures.test/core.tar.gz" |
    .core.sha256 = $coreSha | .core.bytes = $coreBytes |
    .core.expandedBytes = 1024 |
    .harnesses.goose.url = "https://fixtures.test/goose.tar.gz" |
    .harnesses.goose.sha256 = $gooseSha |
    .harnesses.goose.bytes = $gooseBytes |
    .harnesses.goose.expandedBytes = 1024
  ' "$manifest" > "$tmp_dir/install-manifest.json"

cat > "$fake_bin/curl" <<'EOF'
#!/bin/sh
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then output=$2; shift 2; continue; fi
  url=$1
  shift
done
case "$url" in
  */release-manifest.json|*/release-*.json) cp "$FAKE_UPDATE_MANIFEST" "$output" ;;
  */deployment.tar.gz) cp "$FAKE_DEPLOYMENT_ARCHIVE" "$output" ;;
  */core.tar.gz) cp "$FAKE_CORE_ARCHIVE" "$output" ;;
  */goose.tar.gz) cp "$FAKE_GOOSE_ARCHIVE" "$output" ;;
  *) exit 1 ;;
esac
EOF
cat > "$fake_bin/docker" <<'EOF'
#!/bin/sh
if [ "$1" = load ]; then
  gzip -c >/dev/null
  printf '%s\n' load >> "$FAKE_DOCKER_LOG"
  exit 0
fi
if [ "$1" = image ] && [ "$2" = inspect ]; then exit 0; fi
if [ "$1" = compose ]; then
  printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
  exit 0
fi
exit 1
EOF
cat > "$fake_bin/df" <<'EOF'
#!/bin/sh
printf '%s\n' 'Filesystem 1024-blocks Used Available Capacity Mounted on'
printf '%s\n' '/dev/fake 100000000 1 99999999 1% /'
EOF
chmod +x "$fake_bin/curl" "$fake_bin/docker" "$fake_bin/df"

: > "$tmp_dir/docker.log"
PATH="$fake_bin:$PATH" \
FAKE_CORE_ARCHIVE="$tmp_dir/core.tar.gz" \
FAKE_GOOSE_ARCHIVE="$tmp_dir/goose.tar.gz" \
FAKE_DOCKER_LOG="$tmp_dir/docker.log" \
  "$image_installer" "$tmp_dir/install-manifest.json" "$catalog" \
    "$tmp_dir/artifacts" test-run "$tmp_dir/status/status.json" goose
test "$(wc -l < "$tmp_dir/docker.log" | tr -d ' ')" -eq 2 ||
  fail "installer did not load exactly core plus Goose"

jq '.core.sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' \
  "$tmp_dir/install-manifest.json" > "$tmp_dir/bad-checksum.json"
: > "$tmp_dir/docker.log"
expect_failure env PATH="$fake_bin:$PATH" \
  FAKE_CORE_ARCHIVE="$tmp_dir/core.tar.gz" \
  FAKE_GOOSE_ARCHIVE="$tmp_dir/goose.tar.gz" \
  FAKE_DOCKER_LOG="$tmp_dir/docker.log" \
  "$image_installer" "$tmp_dir/bad-checksum.json" "$catalog" \
  "$tmp_dir/artifacts" test-run "$tmp_dir/status/status.json" goose
test ! -s "$tmp_dir/docker.log" ||
  fail "checksum mismatch reached Docker load"

# Exercise the complete shared activation path used by both Standard Linux and
# NixOS. The fake Docker binary records image loads and Compose invocation.
release_tree="$tmp_dir/release-tree"
mkdir -p "$release_tree"
tar -xzf "$tmp_dir/deployment.tar.gz" -C "$release_tree"
runtime_env="$tmp_dir/runtime.env"
cat > "$runtime_env" <<EOF
POCKETBASE_ADMIN_EMAIL=owner@example.test
POCKETBASE_ADMIN_PASSWORD=retain-this-password
POCKETCODER_SELECTED_HARNESSES=goose
EOF
cp "$tmp_dir/install-manifest.json" "$tmp_dir/activation-manifest.json"
: > "$tmp_dir/docker.log"
PATH="$fake_bin:$PATH" \
FAKE_CORE_ARCHIVE="$tmp_dir/core.tar.gz" \
FAKE_GOOSE_ARCHIVE="$tmp_dir/goose.tar.gz" \
FAKE_DOCKER_LOG="$tmp_dir/docker.log" \
POCKETCODER_CURRENT_LINK="$tmp_dir/current" \
  "$release_tree/deploy/scripts/activate-release.sh" \
    "$tmp_dir/activation-manifest.json" \
    "https://images.pocketcoder.org/release-$release.json" \
    "$runtime_env" "$tmp_dir/release-state" "$tmp_dir/artifacts" \
    activation-run "$tmp_dir/status/activation.json" goose
test "$(readlink "$tmp_dir/current")" = "$release_tree" ||
  fail "activation did not switch the current release link"
grep -q '^POCKETBASE_ADMIN_PASSWORD=retain-this-password$' "$runtime_env" ||
  fail "activation changed owner credentials"
grep -q "^POCKETCODER_RELEASE=$release$" "$runtime_env" ||
  fail "activation did not record release identity"
grep -q '^MCP_GATEWAY_AUTH_TOKEN=' "$runtime_env" ||
  fail "activation did not generate local service secrets"
jq -e --arg release "$release" \
  '.release == $release and .manifestSchemaVersion == 2' \
  "$tmp_dir/release-state/current.json" >/dev/null ||
  fail "activation pointer is invalid"
grep -q 'up -d --no-build --remove-orphans' "$tmp_dir/docker.log" ||
  fail "activation did not run prebuilt Compose"
jq -e '.phase == "bootstrap_complete" and .error == null' \
  "$tmp_dir/status/activation.json" >/dev/null ||
  fail "activation did not publish completion status"

# Exercise an update from discovery through immutable manifest verification,
# deployment extraction, image loading, and the atomic current-release switch.
if command -v sha256sum >/dev/null 2>&1; then
  deployment_sha=$(sha256sum "$tmp_dir/deployment.tar.gz" | cut -d' ' -f1)
else
  deployment_sha=$(shasum -a 256 "$tmp_dir/deployment.tar.gz" | cut -d' ' -f1)
fi
deployment_bytes=$(wc -c < "$tmp_dir/deployment.tar.gz" | tr -d ' ')
deployment_expanded=$(gzip -dc "$tmp_dir/deployment.tar.gz" | wc -c | tr -d ' ')
jq --arg deploymentSha "$deployment_sha" \
  --argjson deploymentBytes "$deployment_bytes" \
  --argjson deploymentExpanded "$deployment_expanded" '
    .deployment.url = "https://fixtures.test/deployment.tar.gz" |
    .deployment.sha256 = $deploymentSha |
    .deployment.bytes = $deploymentBytes |
    .deployment.expandedBytes = $deploymentExpanded
  ' "$tmp_dir/install-manifest.json" > "$tmp_dir/update-manifest.json"
update_env="$tmp_dir/update-runtime.env"
cat > "$update_env" <<EOF
POCKETBASE_ADMIN_EMAIL=owner@example.test
POCKETBASE_ADMIN_PASSWORD=retain-this-password
POCKETCODER_SELECTED_HARNESSES=goose
EOF
: > "$tmp_dir/docker.log"
PATH="$fake_bin:$PATH" \
FAKE_UPDATE_MANIFEST="$tmp_dir/update-manifest.json" \
FAKE_DEPLOYMENT_ARCHIVE="$tmp_dir/deployment.tar.gz" \
FAKE_CORE_ARCHIVE="$tmp_dir/core.tar.gz" \
FAKE_GOOSE_ARCHIVE="$tmp_dir/goose.tar.gz" \
FAKE_DOCKER_LOG="$tmp_dir/docker.log" \
RELEASE_BASE=https://fixtures.test \
POCKETCODER_RELEASES_DIR="$tmp_dir/update-releases" \
POCKETCODER_RELEASE_STATE_DIR="$tmp_dir/update-state" \
POCKETCODER_ARTIFACT_DIR="$tmp_dir/update-artifacts" \
POCKETCODER_STATUS_FILE="$tmp_dir/update-status/status.json" \
POCKETCODER_CURRENT_LINK="$tmp_dir/update-current" \
POCKETCODER_RUNTIME_ENV="$update_env" \
  "$release_updater"
test "$(readlink "$tmp_dir/update-current")" = \
  "$tmp_dir/update-releases/$release" || fail "updater did not switch releases"
grep -q '^POCKETBASE_ADMIN_PASSWORD=retain-this-password$' "$update_env" ||
  fail "updater changed owner credentials"
grep -q 'up -d --no-build --remove-orphans' "$tmp_dir/docker.log" ||
  fail "updater did not recreate prebuilt containers"

echo "release contract tests passed"
