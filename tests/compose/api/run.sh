#!/usr/bin/env bash
set -euo pipefail

for name in API_TEST_EMAIL API_TEST_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "missing required environment variable: $name" >&2
    exit 64
  fi
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

# Live-confirmed 2026-08-27: getReleaseCompatibility/getReleaseStatus only
# ever exercised the hardcoded developmentCompatibility fallback in every
# test (Go unit tests and this bats suite alike) -- current.json is never
# present in a fresh dev checkout, so the real-file json.RawMessage decode
# path (what a real deployed box actually goes through) had zero coverage
# anywhere, and a real production bug shipped silently through it. Seed a
# realistic current.json here, mounted read-only into pocketbase at
# /var/lib/pocketcoder/release (docker-compose.yml), so every run of this
# suite exercises that real path instead of just the fallback.
release_state_dir="${POCKETCODER_RELEASE_STATE_DIR:-./.runtime/release}"
mkdir -p "$release_state_dir"
cat >"$release_state_dir/current.json" <<'EOF'
{
  "schemaVersion": 1,
  "releaseDigest": "api-flow-test-digest",
  "sourceCommit": "0000000000000000000000000000000000000000",
  "serverVersion": "1.0.0",
  "dataVersion": 1,
  "deploymentContractVersion": 1,
  "compatibility": {
    "app": {"contractVersion": 1, "officialMinimumVersions": {"pocketcoder-pro": "1.0.0", "pocketcoder-foss": "1.0.0"}},
    "server": {"apiVersion": 1},
    "workers": {"image-relay": 1, "oauth-relay": 1, "push-relay": 1},
    "provisioning": {"contractVersion": 1},
    "deployment": {"contractVersion": 1, "supportedSourceContractVersions": {"minimum": 1, "maximum": 1}},
    "os": {"nixosVersion": "26.05"}
  },
  "selectedHarnesses": ["goose"]
}
EOF

docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile api-test run --build --rm api-flow-test

# The bats suite above deliberately never exercises real harness
# provisioning (curl+jq black-box coverage only). This second pass drives
# the SAME live stack through the actual generated pocketcoder_api Dart
# client -- the real request/response encoding the app uses, not curl+jq --
# covering harness auth (oauth start/poll/submit and the API-key "none"
# mode), chat creation, and the first prompt actually reaching a real
# harness container. This is the layer four real bugs lived at 2026-08-28
# (BaseDao's write race, sessionprofile's missing default provider, the
# renderEnv "none"-mode gap, and provider_api_keys.hidden blocking every
# real user's own write) -- none of the Go unit tests or the bats suite
# above could have caught the last three, since neither one round-trips a
# real record through PocketBase's own hidden-field access-control layer.
#
# docker-socket-proxy-write + mcp-gateway aren't pocketbase's own
# dependencies (the bats run above never starts them) but ARE required for
# real harness container provisioning to get past "network ... not found" /
# "no such host" -- bring them up explicitly rather than silently testing a
# harness-provisioning path that can never actually reach a container.
docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  up -d --build --wait docker-socket-proxy-write mcp-gateway pocketbase

pushd client/packages/pocketcoder_flutter >/dev/null
PB_URL="${PB_URL:-http://127.0.0.1:8090}" \
  flutter test test/integration/local_golden_path_test.dart
popd >/dev/null
