#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$repo_root"

project="pocketcoder-memory-test-${USER:-user}-$$"
compose=(docker compose -p "$project" -f docker-compose.yml -f docker-compose.memory-test.yml)

cleanup() {
  "${compose[@]}" --profile memory-test down --volumes --remove-orphans >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

"${compose[@]}" --profile memory-test up -d --build pocket-memory
"${compose[@]}" --profile memory-test run --rm memory-integration-test
