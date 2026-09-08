#!/usr/bin/env bash
set -euo pipefail

# Runs the full Flutter integration suite (test/integration/) against a
# freshly reseeded local stack. Tears down the WHOLE project (containers,
# networks, volumes across both compose files), not just PocketBase --
# harness containers bake credentials into their env at creation time and
# never live-update, so a leftover one silently serves a stale credential
# even after PocketBase's own state resets; they also join sibling
# services' networks (pocket-memory, mcp-gateway) that must already exist.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

for name in POCKETBASE_SUPERUSER_EMAIL POCKETBASE_SUPERUSER_PASSWORD \
  MCP_GATEWAY_AUTH_TOKEN AGENT_TEST_EMAIL AGENT_TEST_PASSWORD \
  API_TEST_EMAIL API_TEST_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "missing required environment variable: $name (set it in .env)" >&2
    exit 64
  fi
done

compose=(docker compose -f docker-compose.yml -f docker-compose.agent-test.yml)

teardown() {
  local harness_containers
  harness_containers="$(docker ps -aq --filter 'name=pocketcoder-harness-')"
  if [ -n "$harness_containers" ]; then
    docker rm -f $harness_containers >/dev/null
  fi
  "${compose[@]}" down -v --remove-orphans
}

echo "==> Tearing down the whole local stack (containers, networks, volumes)"
teardown
trap teardown EXIT

echo "==> Rebuilding and starting a fresh stack"
"${compose[@]}" up -d --build --wait \
  docker-socket-proxy-write mcp-gateway pocket-memory pocketbase

echo "==> Running the full Flutter integration suite"
pushd client/packages/pocketcoder_flutter >/dev/null
# Several of these files share fixture accounts and mutate the same
# provider_api_keys rows for them (API_TEST_EMAIL) or provision harness
# containers against the same shared docker resources -- Dart's default
# concurrent-by-file test execution races them. Force serial.
PB_URL="${PB_URL:-http://127.0.0.1:8090}" flutter test test/integration/ --concurrency=1
popd >/dev/null
