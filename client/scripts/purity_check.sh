#!/usr/bin/env bash
# purity_check.sh <path-relative-to-client>
#
# Verifies that the package/app at <path> (e.g. "packages/pocketcoder_flutter"
# or "apps/pocketcoder_foss") has a FULLY RESOLVED runtime dependency closure
# built entirely from packages carrying a recognized free/open-source
# license -- not just a grep of the target's own pubspec.yaml/imports for
# hardcoded proprietary package names. `dart pub deps --json` returns the
# WHOLE workspace's graph regardless of cwd (verified -- there is no
# per-member scoping flag), so it's fetched once here from the workspace
# root and check_license_purity.py computes the target-scoped closure
# itself from that graph's dependency edges. See that script for the
# classification logic and why this replaced the older, shallower check.
set -euo pipefail

TARGET="${1:-}"
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <path-relative-to-client, e.g. packages/pocketcoder_flutter>"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$CLIENT_DIR/$TARGET"
WORKSPACE_LOCK="$CLIENT_DIR/pubspec.lock"

if [ ! -d "$TARGET_DIR" ]; then
  echo "ERROR: $TARGET_DIR does not exist."
  exit 1
fi
if [ ! -f "$WORKSPACE_LOCK" ]; then
  echo "ERROR: $WORKSPACE_LOCK not found -- run 'flutter pub get' from $CLIENT_DIR first."
  exit 1
fi

echo "Checking purity for $TARGET (full resolved dependency closure)..."

DEPS_JSON_FILE="$(mktemp)"
trap 'rm -f "$DEPS_JSON_FILE"' EXIT
(cd "$CLIENT_DIR" && dart pub deps --json) > "$DEPS_JSON_FILE"

if [ ! -s "$DEPS_JSON_FILE" ]; then
  echo "ERROR: 'dart pub deps --json' produced no output."
  exit 1
fi

python3 "$SCRIPT_DIR/check_license_purity.py" "$TARGET_DIR" "$DEPS_JSON_FILE" "$WORKSPACE_LOCK"
