#!/usr/bin/env bash
set -euo pipefail

for name in API_TEST_EMAIL API_TEST_PASSWORD; do
  if [ -z "${!name:-}" ]; then
    echo "missing required environment variable: $name" >&2
    exit 64
  fi
done

docker compose -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile api-test run --build --rm api-flow-test
