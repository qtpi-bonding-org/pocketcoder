#!/usr/bin/env bash
# Exercises the VPS suite harness with stub ssh/curl. No VPS, no credentials.
set -uo pipefail

vps_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export VPS_DIR=$vps_dir

TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/pocketcoder-vps-selftest.XXXXXX")
export TEST_TMP
trap 'rm -rf "$TEST_TMP"' EXIT

. "$vps_dir/tests/helpers.sh"

for test_file in "$vps_dir"/tests/test-*.sh; do
  [ -f "$test_file" ] || continue
  printf '\n# %s\n' "$(basename "$test_file")"
  . "$test_file"
done

printf '\n%d passed, %d failed\n' "$test_pass" "$test_fail"
[ "$test_fail" -eq 0 ]
