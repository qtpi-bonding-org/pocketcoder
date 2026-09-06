#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Advisory, never blocks the push -- pushing a real nixos/backend change is
# exactly the case this is supposed to flag, not prevent.
status=0
"$REPO_ROOT/deploy/scripts/check-release-scope.sh" >&2 || status=$?
if [ "$status" -eq 2 ]; then
  echo "" >&2
  echo "pre-push: nixos and/or backend has drifted from what's promoted to stable." >&2
  echo "See docs/ops-runbook.md section 6 before shipping an app-only build." >&2
fi
exit 0
