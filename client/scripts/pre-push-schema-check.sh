#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

UPSTREAM="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo '')"
STAGED="$(git -C "$REPO_ROOT" diff --name-only "${UPSTREAM:-HEAD~1}...HEAD" 2>/dev/null || true)"
if [ -n "$STAGED" ] && ! echo "$STAGED" | grep -qE '^server/pocketbase/pb_migrations/schema\.json$|^client/packages/pocketcoder_flutter/assets/pb_schema\.json$|^client/packages/pocketcoder_flutter/lib/domain/models/|^tooling/scripts/(generate_flutter|check_pocketbase_contracts)\.sh$'; then
  exit 0
fi

echo "pre-push: checking PocketBase schema/model contracts..." >&2
"$REPO_ROOT/tooling/scripts/check_pocketbase_contracts.sh" || {
  echo "" >&2
  echo "pre-push: schema/model contract check failed. Run" >&2
  echo "  ./tooling/scripts/generate_flutter.sh" >&2
  echo "and commit the result before pushing." >&2
  exit 1
}
