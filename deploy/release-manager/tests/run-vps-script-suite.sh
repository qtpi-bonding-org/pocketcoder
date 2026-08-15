#!/usr/bin/env bash
# Run the post-provision VPS-script checks described in
# docs/testing/vps-script-test-plan.md.  Provisioning and release promotion
# intentionally remain owned by the existing upgrade test.
set -euo pipefail

if [[ "${POCKETCODER_VPS_SCRIPT_TEST:-}" != 1 ]]; then
  echo "Refusing to run VPS script tests. Set POCKETCODER_VPS_SCRIPT_TEST=1 to opt in." >&2
  exit 64
fi

usage() {
  echo "usage: $0 <handoff.json> [--include-nixos|--include-nixos-update]" >&2
  exit 64
}

[[ $# -ge 1 && $# -le 2 ]] || usage
handoff=$1
include_nixos=false
include_nixos_update=false
case ${2:-} in
  --include-nixos) include_nixos=true ;;
  --include-nixos-update) include_nixos=true; include_nixos_update=true ;;
  '') ;;
  *) usage ;;
esac
[[ -f $handoff ]] || { echo "handoff file does not exist: $handoff" >&2; exit 1; }

for command in curl jq ssh; do
  command -v "$command" >/dev/null || { echo "required command is unavailable: $command" >&2; exit 1; }
done

result_file=${POCKETCODER_VPS_SCRIPT_RESULT_FILE:-${TMPDIR:-/tmp}/pocketcoder-vps-script-suite.json}
started_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
phase_file=$(mktemp "${TMPDIR:-/tmp}/pocketcoder-vps-phases.XXXXXX")
status=failed
failure_phase=

host=$(jq -er '.ipAddress | strings | select(test("^[0-9a-fA-F:.]+$"))' "$handoff")
hostname=$(jq -er '.hostname | strings | select(test("^[A-Za-z0-9.-]+$"))' "$handoff")
key_path=$(jq -er '.sshPrivateKeyPath | strings | select(startswith("/"))' "$handoff")
[[ -f $key_path ]] || { echo "retained test SSH key does not exist: $key_path" >&2; exit 1; }

ssh_base() {
  ssh -q -i "$key_path" -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 "root@$host" "$@"
}

record_phase() {
  local phase=$1 phase_status=$2 detail=${3:-}
  jq -n --arg phase "$phase" --arg status "$phase_status" --arg detail "$detail" \
    --arg startedAt "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    '{phase:$phase,status:$status,detail:$detail,startedAt:$startedAt}' >>"$phase_file"
}

run_phase() {
  local phase=$1; shift
  failure_phase=$phase
  echo "VPS SCRIPT: $phase"
  local output
  if output=$("$@" 2>&1); then
    record_phase "$phase" passed "$output"
  else
    local exit_code=$?
    record_phase "$phase" failed "${output:0:2000}"
    echo "$output" >&2
    return "$exit_code"
  fi
}

wait_for_https() {
  local last_error=
  for _ in $(seq 1 "${POCKETCODER_VPS_HEALTH_ATTEMPTS:-40}"); do
    if last_error=$(curl --fail --silent --show-error --connect-timeout 5 --max-time 10 \
      --resolve "$hostname:443:$host" "https://$hostname/api/health" 2>&1); then
      return 0
    fi
    sleep "${POCKETCODER_VPS_HEALTH_INTERVAL:-5}"
  done
  echo "HTTPS readiness timed out: ${last_error:-unknown error}" >&2
  return 1
}

read_only() {
  ssh_base 'set -eu
    test "$(uname -s)" = Linux
    test -x /opt/pocketcoder/current/bin/pocketcoder-release
    test -f /var/lib/pocketcoder/release/current.json
    jq -e . /var/lib/pocketcoder/release/current.json >/dev/null
    test "$(docker ps --format "{{.Names}}" | grep -c "^pocketcoder-" || true)" -gt 0'
  wait_for_https
  compatibility=$(curl --fail --silent --show-error --max-time 30 \
    --resolve "$hostname:443:$host" "https://$hostname/api/pocketcoder/v1/compatibility")
  jq -e '(.JsonSuccessJSONResponse // .) | .schemaVersion == 1 and .compatibility.server.apiVersion == 1' \
    <<<"$compatibility" >/dev/null
  release_status_code=$(curl --silent --show-error --max-time 30 \
    --output /dev/null --write-out '%{http_code}' \
    --resolve "$hostname:443:$host" \
    "https://$hostname/api/pocketcoder/v1/release/status")
  [[ "$release_status_code" == 401 ]] # status is authenticated; rejection is expected.
}

backup() {
  backup_output=$(ssh_base 'set -eu; docker exec pocketcoder-pocketbase /app/backup_db.sh')
  printf '%s\n' "$backup_output"
  archive=$(ssh_base 'set -eu
    find /var/lib/docker/volumes -path "*/_data/*" -type f \
      \( -name "*.zip" -o -name "*.tar.gz" -o -name "*.sqlite3" -o -name "*.db" \) \
      -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -1 | cut -d" " -f2-')
  [[ -n $archive ]]
  checksum=$(ssh_base "sha256sum -- $(printf '%q' "$archive")")
  integrity=$(ssh_base 'docker exec pocketcoder-pocketbase \
    sqlite3 /app/pb_backups/data.db "PRAGMA integrity_check;"')
  [[ $integrity == ok ]]
  restored_integrity=$(ssh_base 'set -eu
    tmp=$(mktemp -d /tmp/pocketcoder-backup-restore.XXXXXX)
    trap '\''rm -rf "$tmp"'\'' EXIT
    cp /var/lib/docker/volumes/pocketcoder_pb_backups/_data/data.db "$tmp/data.db"
    sqlite3 "$tmp/data.db" "PRAGMA integrity_check;"')
  [[ $restored_integrity == ok ]]
  printf 'backupArtifact=%s\nbackupChecksum=%s\nrestoredIntegrity=%s\n' "$archive" "$checksum" "$restored_integrity"
}

inspect_release() {
  release_status=$(ssh_base 'set -eu; /opt/pocketcoder/current/bin/pocketcoder-release status')
  jq -e '.schemaVersion == 1 and (.managerVersion | strings | length > 0) and (.current.releaseDigest | strings | test("^[0-9a-f]{64}$"))' \
    <<<"$release_status" >/dev/null
}

restart_pocketcoder() {
  ssh_base 'set -eu
    if [ -f /opt/pocketcoder/current/docker-compose.prebuilt.yml ]; then
      if docker compose version >/dev/null 2>&1; then
        docker compose --project-name pocketcoder --env-file /var/lib/pocketcoder/config/runtime.env \
          -f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart
      else
        docker-compose --project-name pocketcoder --env-file /var/lib/pocketcoder/config/runtime.env \
          -f /opt/pocketcoder/current/docker-compose.prebuilt.yml restart
      fi
    else exit 1; fi'
  wait_for_https
  ssh_base 'set -eu; test "$(docker ps --format "{{.Names}}" | grep -c "^pocketcoder-" || true)" -gt 0'
}

nixos_restart() {
  ssh_base 'systemctl reboot' || true
  for _ in $(seq 1 "${POCKETCODER_VPS_SSH_ATTEMPTS:-60}"); do
    if ssh_base 'true' >/dev/null 2>&1; then wait_for_https; return; fi
    sleep 10
  done
  return 1
}

nixos_update() {
  ssh_base 'set -eu; nixos-rebuild switch --upgrade'
  wait_for_https
  ssh_base 'set -eu; test "$(systemctl is-system-running 2>/dev/null || true)" = running'
}

write_result() {
  local exit_code=$? completed_at
  completed_at=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  mkdir -p "$(dirname "$result_file")"
  local phases
  phases=$(jq -s . "$phase_file")
  jq -n --arg status "$status" --arg failurePhase "$failure_phase" \
    --arg startedAt "$started_at" --arg completedAt "$completed_at" \
    --arg hostname "$hostname" --arg instanceId "$(jq -r '.instanceId // empty' "$handoff")" \
    --argjson phases "$phases" \
    '{schemaVersion:1,suite:"vps-script",status:$status,startedAt:$startedAt,
      completedAt:$completedAt,failurePhase:(if $failurePhase=="" then null else $failurePhase end),
      hostname:$hostname,instanceId:(if $instanceId=="" then null else $instanceId end),phases:$phases}' \
    >"${result_file}.tmp"
  mv "${result_file}.tmp" "$result_file"
  rm -f "$phase_file"
  return "$exit_code"
}
trap write_result EXIT

run_phase read-only read_only
run_phase inspect-release inspect_release
run_phase backup backup
run_phase restart-pocketcoder restart_pocketcoder
if $include_nixos; then
  run_phase restart-nixos nixos_restart
  if $include_nixos_update; then
    run_phase update-nixos nixos_update
  fi
fi

status=passed
failure_phase=
echo "VPS SCRIPT: passed (result: $result_file)"
