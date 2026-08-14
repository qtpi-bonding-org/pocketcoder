#!/usr/bin/env bash
# Small failure diagnostics used by the current Bats tests.

export DIAGNOSTICS_ENABLED="${DIAGNOSTICS_ENABLED:-true}"

run_diagnostic() {
    local service="$1"
    local test_name="$2"
    local error_msg="$3"

    [ "$DIAGNOSTICS_ENABLED" = "true" ] || return 0
    echo ""
    echo "❌ $test_name"
    echo "   Service: $service"
    echo "   Error: $error_msg"
}

run_diagnostic_on_failure() {
    local service="$1"
    local error_msg="$2"
    run_diagnostic "$service" "${BATS_TEST_NAME:-unknown}" "$error_msg"
    return 1
}

export -f run_diagnostic run_diagnostic_on_failure
