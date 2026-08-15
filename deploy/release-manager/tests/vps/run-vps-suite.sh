#!/usr/bin/env bash
# The single entrypoint for the VPS script test suite.
# See docs/superpowers/specs/2026-08-15-vps-script-test-suite-hardening-design.md
set -uo pipefail

vps_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$vps_dir/lib/common.sh"
. "$vps_dir/lib/result.sh"
. "$vps_dir/lib/commands.sh"

usage() {
  cat >&2 <<'EOF'
usage: run-vps-suite.sh [options]
  --handoff <path>     use an existing Aeroform handoff instead of provisioning
  --run-dir <path>     where evidence is written (default: timestamped tmp dir)
  --only <a,b>         run only these phases
  --skip <a,b>         run everything except these phases
  --keep               preserve the VPS after the run (default during bring-up)
  --reap-orphans       delete pre-existing VPS-script instances and continue
EOF
  exit 64
}

if [ "${POCKETCODER_VPS_SCRIPT_TEST:-}" != 1 ]; then
  echo "Refusing to run VPS script tests. Set POCKETCODER_VPS_SCRIPT_TEST=1 to opt in." >&2
  exit 64
fi

handoff=
run_dir=
only=
skip=
keep=1          # Task 14 flips this default to 0.
reap_orphans=0

while [ $# -gt 0 ]; do
  case $1 in
    --handoff) handoff=${2:-}; shift 2 || usage ;;
    --run-dir) run_dir=${2:-}; shift 2 || usage ;;
    --only) only=${2:-}; shift 2 || usage ;;
    --skip) skip=${2:-}; shift 2 || usage ;;
    --keep) keep=1; shift ;;
    --reap-orphans) reap_orphans=1; shift ;;
    *) usage ;;
  esac
done

phase_dir=${VPS_PHASE_DIR:-$vps_dir/phases}
run_dir=${run_dir:-${TMPDIR:-/tmp}/pocketcoder-vps-$(date -u '+%Y%m%dT%H%M%SZ')-$$}
result_init "$run_dir"
echo "VPS SUITE: evidence in $run_dir"

run_status=failed
failure_phase=

finish() {
  local rc=$?
  result_write "$run_status" "$failure_phase"
  echo "VPS SUITE: $run_status (result: $run_dir/result.json)"
  exit "$rc"
}
trap finish EXIT
trap 'exit 1' INT TERM HUP

in_list() {
  local needle=$1 list=$2 item
  local IFS=,
  for item in $list; do
    [ "$item" = "$needle" ] && return 0
  done
  return 1
}

selected() {
  local name=$1
  [ -n "$only" ] && { in_list "$name" "$only" || return 1; }
  [ -n "$skip" ] && { in_list "$name" "$skip" && return 1; }
  return 0
}

run_one_phase() {
  local file=$1 started ended output rc evidence skip_reason
  # Each phase runs in a subshell so its variables cannot leak into the next.
  phase_name=; phase_tier=; unset -f phase_run phase_precondition 2>/dev/null
  . "$file"
  selected "$phase_name" || return 0

  if declare -f phase_precondition >/dev/null 2>&1; then
    if ! skip_reason=$(phase_precondition 2>&1); then
      started=$(date +%s)
      phase_record "$phase_name" "$phase_tier" skipped "$started" "$started" \
        '' '{}' "${skip_reason:-precondition not met}"
      echo "VPS SUITE: $phase_name skipped (${skip_reason:-precondition not met})"
      return 0
    fi
  fi

  echo "VPS SUITE: $phase_name ($phase_tier)"
  started=$(date +%s)
  VPS_PHASE_EVIDENCE='{}'
  output=$(phase_run 2>&1)
  rc=$?
  ended=$(date +%s)
  evidence=${VPS_PHASE_EVIDENCE:-\{\}}

  if [ "$rc" -eq 0 ]; then
    phase_record "$phase_name" "$phase_tier" passed "$started" "$ended" "$output" "$evidence"
    return 0
  fi
  if [ "$rc" -eq 78 ]; then
    phase_record "$phase_name" "$phase_tier" skipped "$started" "$ended" \
      "$output" "$evidence" "$(printf '%s' "$output" | tail -1)"
    echo "VPS SUITE: $phase_name skipped"
    return 0
  fi
  phase_record "$phase_name" "$phase_tier" failed "$started" "$ended" "$output" "$evidence"
  printf '%s\n' "$output" >&2
  failure_phase=$phase_name
  return 1
}

tier_failed=0
for tier in readonly safe-mutating disruptive; do
  for file in "$phase_dir"/*.sh; do
    [ -f "$file" ] || continue
    # Cheap tier read without executing the phase body.
    file_tier=$(sed -n 's/^phase_tier=//p' "$file" | head -1)
    [ "$file_tier" = "$tier" ] || continue
    run_one_phase "$file" || tier_failed=1
  done
  if [ "$tier_failed" -eq 1 ]; then
    echo "VPS SUITE: aborting before the next tier after a $tier failure" >&2
    exit 1
  fi
done

run_status=passed
failure_phase=
exit 0
