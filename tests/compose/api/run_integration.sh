#!/usr/bin/env bash
set -euo pipefail

# Runs the full Flutter integration suite (test/integration/) against a
# freshly reseeded local PocketBase -- one reset at the start, not per test.
# These tests are written to be self-cleaning (unique timestamped names,
# tearDown deletes), so resetting once is enough to guarantee a known-good
# seed; a test that leaves dirty state behind has a teardown bug that
# resetting per-test would only paper over.
#
# A fresh reset needs BOTH the pb_data and pb_backups volumes wiped:
# entrypoint.sh's restore_from_backup.sh auto-restores pb_backups onto a
# missing pb_data at boot, so wiping pb_data alone silently resurrects
# whatever was in the last backup instead of reseeding.
#
# Most tests here gate on their own optional env vars (POCKETBASE_SUPERUSER_
# EMAIL/PASSWORD, API_TEST_EMAIL/PASSWORD, REAL_PROVIDER_API_KEY, ...) and
# call markTestSkipped when one is missing -- this script does not require
# any of them; unset ones just mean fewer tests actually run this pass.
#
# Run:
#   tests/compose/api/run_integration.sh
# (exports POCKETBASE_SUPERUSER_EMAIL/PASSWORD from .env automatically if
# they're not already set in your shell -- docker-compose already reads
# .env for the container's own env, this just extends that to the flutter
# test process's environment too.)

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

if [ -f .env ] && [ -z "${POCKETBASE_SUPERUSER_EMAIL:-}" ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

project="$(docker compose config --format json | python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])')"

echo "==> Resetting local PocketBase state (project: $project)"
docker compose stop pocketbase >/dev/null 2>&1 || true
docker compose rm -f pocketbase >/dev/null 2>&1 || true
docker volume rm "${project}_pb_data" "${project}_pb_backups" >/dev/null 2>&1 || true

echo "==> Rebuilding and starting a fresh PocketBase"
# Deliberately just pocketbase, not the docker-compose.agent-test.yml
# overlay tests/compose/api/run.sh also brings up (docker-socket-proxy-write
# + mcp-gateway, for real harness-container provisioning): that overlay
# hard-requires MCP_GATEWAY_AUTH_TOKEN at compose-config time, which fails
# validation outright rather than letting an unset var gracefully skip --
# unlike this script's own env vars, which the Dart tests themselves check
# and skip on. Most tests here only need plain PocketBase; the handful that
# also need real container provisioning (git_ssh_real_docker_test.dart,
# skill_materialization_real_agent_test.dart) need that overlay brought up
# separately first if you want them to do more than fail on missing infra.
docker compose up -d --build --wait pocketbase

echo "==> Running the full Flutter integration suite"
pushd client/packages/pocketcoder_flutter >/dev/null
PB_URL="${PB_URL:-http://127.0.0.1:8090}" flutter test test/integration/
popd >/dev/null
