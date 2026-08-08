# Shared status-document writer. Source from a bootstrap service.
# The document deliberately has no `ready` phase; readiness is granted only
# by the application's /api/health endpoint.

PC_STATUS_DIR="${PC_STATUS_DIR:-/var/lib/pocketcoder/public}"
PC_STATUS_FILE="$PC_STATUS_DIR/status.json"
PC_RUN_ID=""
PC_CURRENT_PHASE="installing_host"
PC_HEARTBEAT_PID=""

_pc_status_write() {
  local phase="$1" detail="${2:-}" error="${3:-}" tmp
  mkdir -p "$PC_STATUS_DIR"
  tmp=$(mktemp -p "$PC_STATUS_DIR" .status.XXXXXX)
  jq -n \
    --argjson schema 1 \
    --arg runId "$PC_RUN_ID" \
    --arg phase "$phase" \
    --arg detail "$detail" \
    --arg sourceCommit "${PC_SOURCE_COMMIT:-unknown}" \
    --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg error "$error" \
    '{schema:$schema,runId:$runId,phase:$phase,
      detail:(if $detail == "" then null else $detail end),
      sourceCommit:$sourceCommit,updatedAt:$updatedAt,
      error:(if $error == "" then null else $error end)}' > "$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$PC_STATUS_FILE"
  if [ "${PC_TRACE:-0}" = 1 ]; then
    printf '%s %s\n' "$phase" "${detail:-}" >> /var/log/pocketcoder-status-trace.log
  fi
}

pc_status_init() {
  PC_RUN_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)
  PC_CURRENT_PHASE="installing_host"
  _pc_status_write "$PC_CURRENT_PHASE" "" ""
}

pc_status_phase() {
  PC_CURRENT_PHASE="$1"
  _pc_status_write "$PC_CURRENT_PHASE" "${2:-}" ""
}

pc_status_error() {
  _pc_status_write "$1" "" "$2"
}

pc_status_heartbeat_start() {
  (while true; do sleep 60; _pc_status_write "$PC_CURRENT_PHASE" working ""; done) &
  PC_HEARTBEAT_PID=$!
}

pc_status_heartbeat_stop() {
  if [ -n "$PC_HEARTBEAT_PID" ]; then
    kill "$PC_HEARTBEAT_PID" 2>/dev/null || true
    wait "$PC_HEARTBEAT_PID" 2>/dev/null || true
  fi
  PC_HEARTBEAT_PID=""
}
