#!/usr/bin/env bash
# Minimal identifiers and artifact labels for the current Bats tests.

declare -a TEST_ARTIFACTS=()

generate_test_id() {
    printf 'test_%s_%04d\n' "$(date +%s)" "$RANDOM"
}

track_artifact() {
    local artifact="$1"
    TEST_ARTIFACTS+=("$artifact")
}

export -f generate_test_id track_artifact
