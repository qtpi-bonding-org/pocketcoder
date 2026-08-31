#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLIENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STAGED="$(git -C "$CLIENT_DIR/.." diff --cached --name-only --diff-filter=ACMR)"
if ! echo "$STAGED" | grep -qE '^client/(packages/pocketcoder_flutter|packages/pocketcoder_api|apps/pocketcoder_foss)/|^client/pubspec\.(yaml|lock)$'; then
  exit 0
fi

echo "pre-commit: checking FOSS dependency purity (packages/pocketcoder_flutter, apps/pocketcoder_foss)..." >&2

FAILED=0
for TARGET in packages/pocketcoder_flutter apps/pocketcoder_foss; do
  if ! (cd "$CLIENT_DIR" && ./scripts/purity_check.sh "$TARGET"); then
    FAILED=1
  fi
done

if [ "$FAILED" -ne 0 ]; then
  echo "" >&2
  echo "pre-commit: FOSS purity check failed -- a proprietary dependency" >&2
  echo "(e.g. flutter_aeroform) leaked into a FOSS target's resolved" >&2
  echo "dependency graph. Fix before committing; see docs/ops-runbook.md." >&2
  exit 1
fi

exit 0
