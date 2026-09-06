#!/bin/sh
set -eu

: "${REAL_PROVIDER_API_KEY:?REAL_PROVIDER_API_KEY must be set (injected by the secrets daemon)}"
export REAL_PROVIDER_API_KEY
export REAL_PROVIDER_ID="${REAL_PROVIDER_ID:-openrouter}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

set -a
. ./.env
set +a

TEST_FILTER="${SKILL_TEST_FILTER:-}"

cd client
FLUTTER_BIN="${FLUTTER_BIN:-/Users/aicoder/develop/flutter/bin/flutter}"
if [ -n "$TEST_FILTER" ]; then
  "$FLUTTER_BIN" test packages/pocketcoder_flutter/test/integration/skill_materialization_real_agent_test.dart --plain-name "$TEST_FILTER"
else
  "$FLUTTER_BIN" test packages/pocketcoder_flutter/test/integration/skill_materialization_real_agent_test.dart
fi
