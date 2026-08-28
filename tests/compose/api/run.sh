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
