#!/usr/bin/env bash
set -euo pipefail

for name in GOOSE_SERVER__SECRET_KEY MCP_GATEWAY_AUTH_TOKEN AGENT_TEST_EMAIL AGENT_TEST_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "missing required environment variable: $name" >&2
    exit 64
  fi
done

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile agent-test up -d --build docker-socket-proxy-write goose pocketbase mcp-gateway
docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile agent-test run --rm agent-c1-test \
  --tap /tests/compose/agent/config_pipeline.bats \
  /tests/compose/agent/acceptance.bats \
  /tests/compose/agent/mcp_gateway.bats
