#!/usr/bin/env bash
set -euo pipefail

for name in GOOSE_SERVER__SECRET_KEY ANTHROPIC_API_KEY AGENT_TEST_EMAIL AGENT_TEST_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "missing required environment variable: $name" >&2
    exit 64
  fi
done

docker compose --profile agent up -d --build goose pocketbase
docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile agent --profile agent-test run --rm agent-c1-test \
  --tap /tests/agent-c1/acceptance.bats
