#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Advisory, never blocks the push -- pushing a real nixos/backend change is
# exactly the case this is supposed to flag, not prevent.
status=0
"$REPO_ROOT/deploy/scripts/check-release-scope.sh" >&2 || status=$?
case "$status" in
  2)
    echo "" >&2
    echo "pre-push: FULL_PROVISION -- nixos/release-manager drifted from what's" >&2
    echo "promoted to stable. See docs/ops-runbook.md section 6." >&2
    ;;
  1)
    echo "" >&2
    echo "pre-push: UPGRADE_TEST_ONLY -- backend/migrations drifted from what's" >&2
    echo "promoted to stable. run_vps_script_nixos_upgrade_test covers this," >&2
    echo "not the full provisioning suite. See docs/ops-runbook.md section 6." >&2
    ;;
esac
exit 0
