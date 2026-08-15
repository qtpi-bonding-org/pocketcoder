#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
results_dir="${TEST_RESULTS_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/pocketcoder-integration.XXXXXX")}"
mkdir -p "$results_dir"

run_step() {
  local name="$1"
  shift
  local output="$results_dir/$name.log"
  echo "==> $name"
  if "$@" 2>&1 | tee "$output"; then
    echo "PASS $name"
  else
    local status=${PIPESTATUS[0]}
    echo "FAIL $name (result: $output)" >&2
    return "$status"
  fi
}

cd "$repo_root"

run_step generated-contracts bash -c \
  'tooling/scripts/generate_flutter.sh && git diff --exit-code -- api/openapi client/packages/pocketcoder_api client/packages/pocketcoder_flutter/assets client/packages/pocketcoder_flutter/lib'
run_step generated-pocketbase-contracts tooling/scripts/check_pocketbase_contracts.sh
run_step api-compose tests/compose/api/run.sh
run_step agent-compose tests/compose/agent/run.sh
run_step memory-compose tests/compose/memory/run.sh
run_step release-manager-docker deploy/release-manager/tests/run-docker-integration.sh

# There is currently no separate Pro package in this checkout. Keep the
# package-local Flutter checks here so the entrypoint remains useful while a
# Pro deployment package is introduced.
run_step api-dart-tests bash -c 'cd client && dart test packages/pocketcoder_api'
run_step flutter-core-tests bash -c 'cd client && flutter test packages/pocketcoder_flutter'
run_step foss-app-tests bash -c 'cd client && flutter test apps/pocketcoder_foss'
run_step widgetbook-story-analysis bash -c 'cd client && flutter analyze packages/pocketcoder_flutter'

echo "Integration results: $results_dir"
