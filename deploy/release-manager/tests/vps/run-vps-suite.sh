#!/usr/bin/env bash
# The single entrypoint for the VPS script test suite.
# See docs/superpowers/specs/2026-08-15-vps-script-test-suite-hardening-design.md
set -uo pipefail

vps_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$vps_dir/lib/common.sh"
. "$vps_dir/lib/result.sh"
. "$vps_dir/lib/teardown.sh"

usage() {
  cat >&2 <<'EOF'
usage: run-vps-suite.sh [options]
  --handoff <path>     use an existing handoff instead of provisioning
  --provisioner <path> executable that provisions a box and prints handoff JSON
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

. "$vps_dir/lib/guards.sh"
repo_root=$(CDPATH= cd -- "$vps_dir/../../../.." && pwd)

guard_required_commands curl jq ssh ssh-keyscan git openssl || exit 64

handoff=
run_dir=
only=
skip=
keep=1          # Task 14 flips this default to 0.
reap_orphans=0

while [ $# -gt 0 ]; do
  case $1 in
    --handoff) handoff=${2:-}; shift 2 || usage ;;
    --provisioner) VPS_PROVISIONER=${2:-}; shift 2 || usage ;;
    --run-dir) run_dir=${2:-}; shift 2 || usage ;;
    --only) only=${2:-}; shift 2 || usage ;;
    --skip) skip=${2:-}; shift 2 || usage ;;
    --keep) keep=1; shift ;;
    --reap-orphans) reap_orphans=1; shift ;;
    *) usage ;;
  esac
done

if [ -n "$handoff" ]; then
  [ -f "$handoff" ] || { echo "--handoff path not found: $handoff" >&2; exit 64; }
  handoff=$(cat "$handoff")
fi

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

if [ -z "$handoff" ] && [ "${VPS_SKIP_PROVISION:-0}" != 1 ]; then
  guard_clean_checkout "$repo_root" || exit 64
  release_branch=$(guard_release_branch "$repo_root") || exit 64
fi

phase_dir=${VPS_PHASE_DIR:-$vps_dir/phases}
run_dir=${run_dir:-${TMPDIR:-/tmp}/pocketcoder-vps-$(date -u '+%Y%m%dT%H%M%SZ')-$$}
result_init "$run_dir"
echo "VPS SUITE: evidence in $run_dir"

. "$vps_dir/phases/10-provision.sh"
. "$vps_dir/phases/55-promote.sh"

run_label="vps-script-$(date -u '+%Y%m%d%H%M%S')-$$"
result_set instanceLabel "$run_label"

if [ -z "$handoff" ] && [ "${VPS_SKIP_PROVISION:-0}" != 1 ]; then
  handoff=$(vps_provision "$repo_root" "$run_dir" "$run_label") || exit 1
fi

if [ -n "$handoff" ]; then
  VPS_HOSTNAME=$(jq -er '.hostname' <<<"$handoff")
  VPS_RELEASE_A_DIGEST=$(jq -er '.releaseDigest' <<<"$handoff")
  teardown_set_instance "$(jq -r '.instanceId' <<<"$handoff")"
  result_set instanceId "$(jq -r '.instanceId' <<<"$handoff")"
  result_set hostname "$VPS_HOSTNAME"
  result_set_json releaseA "$(jq '{digest:.releaseDigest,sourceCommit:.sourceCommit,
    channel:.channel,sequence:.sequence}' <<<"$handoff")"
  vps_connect "$(jq -er '.ipAddress' <<<"$handoff")" "$(jq -er '.sshPrivateKeyPath' <<<"$handoff")" \
    "$run_dir/known_hosts"
  pin_host_key || { echo "could not pin the host key" >&2; exit 1; }
  load_redaction_dictionary || echo "WARNING: redaction dictionary unavailable; output suppressed" >&2
fi

if [ -z "${VPS_RELEASE_B_DIGEST:-}" ] && [ "${VPS_SKIP_PROVISION:-0}" != 1 ] &&
   { selected update || selected post-update; }; then
  release_branch=${release_branch:-$(git -C "$repo_root" symbolic-ref --short HEAD 2>/dev/null || echo main)}
  # A promotion failure (e.g. the only buildable candidate is byte-identical
  # to the box we just provisioned -- expected right after a fresh channel
  # repair) must not abort the whole run: it only means update/post-update
  # have nothing to test this time. Their own phase_precondition already
  # turns an unset VPS_RELEASE_B_DIGEST into a clean "skipped", so every
  # other phase still runs.
  if promotion=$(vps_promote_candidate "$repo_root" "${VPS_RELEASE_A_DIGEST:-}" "$release_branch"); then
    VPS_RELEASE_B_DIGEST=$(jq -er '.digest' <<<"$promotion")
    VPS_RELEASE_B_SOURCE_COMMIT=$(jq -er '.sourceCommit' <<<"$promotion")
    VPS_RELEASE_B_SEQUENCE=$(jq -er '.sequence' <<<"$promotion")
    VPS_RELEASE_BRANCH=$release_branch
    result_set_json releaseB "$promotion"
  else
    echo "VPS SUITE: no release B candidate available; update/post-update will skip" >&2
  fi
fi

run_status=failed
failure_phase=

finish() {
  local rc=$?
  if ! teardown_run "$keep"; then
    run_status=failed
    [ -n "$failure_phase" ] || failure_phase=teardown
    rc=1
  fi
  result_write "$run_status" "$failure_phase"
  echo "VPS SUITE: $run_status (result: $run_dir/result.json)"
  exit "$rc"
}
trap finish EXIT
trap 'exit 1' INT TERM HUP

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
