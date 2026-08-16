# Shared status-document writer. Source from a bootstrap service.
# The document deliberately has no `ready` phase; readiness is granted only
# by the application's /api/health endpoint.

PC_STATUS_DIR="${PC_STATUS_DIR:-/var/lib/pocketcoder/public}"
PC_STATUS_FILE="$PC_STATUS_DIR/status.json"
PC_STATUS_LOCK="$PC_STATUS_DIR/.status.lock"
PC_RUN_ID=""
PC_CURRENT_PHASE="configuring_operating_system"
PC_HEARTBEAT_PID=""

_pc_status_write() {
  local phase="$1" detail="${2:-}" error="${3:-}" tmp existing
  local ssh_host_key_type="${POCKETCODER_SSH_HOST_KEY_TYPE:-}"
  local ssh_host_key_fingerprint="${POCKETCODER_SSH_HOST_KEY_FINGERPRINT:-}"
  mkdir -p "$PC_STATUS_DIR"
  exec 9>>"$PC_STATUS_LOCK"
  flock 9
  existing='{}'
  if [ -s "$PC_STATUS_FILE" ] && jq -e . "$PC_STATUS_FILE" >/dev/null 2>&1; then
    existing="$PC_STATUS_FILE"
  fi
  tmp=$(mktemp -p "$PC_STATUS_DIR" .status.XXXXXX)
  jq \
    --argjson schema 2 \
    --arg runId "$PC_RUN_ID" \
    --arg phase "$phase" \
    --arg detail "$detail" \
    --arg sourceCommit "${PC_SOURCE_COMMIT:-unknown}" \
    --arg sshHostKeyType "$ssh_host_key_type" \
    --arg sshHostKeyFingerprint "$ssh_host_key_fingerprint" \
    --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg error "$error" \
    '(. + {schema:$schema,runId:$runId,phase:$phase,
      detail:(if $detail == "" then null else $detail end),
      sourceCommit:$sourceCommit,updatedAt:$updatedAt,
      sshHostKey:(if $sshHostKeyType == "" or $sshHostKeyFingerprint == ""
        then null
        else {type:$sshHostKeyType,fingerprint:$sshHostKeyFingerprint}
        end),
      error:(if $error == "" then null else $error end)})' "$existing" > "$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$PC_STATUS_FILE"
  flock -u 9
  exec 9>&-
}

pc_status_capture_ssh_host_key() {
  local public_key=/etc/ssh/ssh_host_ed25519_key.pub fingerprint
  if [ ! -r "$public_key" ] || ! command -v ssh-keygen >/dev/null 2>&1; then
    return
  fi
  fingerprint=$(ssh-keygen -E md5 -lf "$public_key" 2>/dev/null | awk '{print $2}')
  case "$fingerprint" in MD5:*:*:*:*:*:*:*:*:*:*:*:*:*:*:*:*) ;;
    *) return ;;
  esac
  export POCKETCODER_SSH_HOST_KEY_TYPE=ssh-ed25519
  export POCKETCODER_SSH_HOST_KEY_FINGERPRINT="$fingerprint"
}

pc_status_init() {
  pc_status_capture_ssh_host_key
  PC_RUN_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s%N)
  PC_CURRENT_PHASE="configuring_operating_system"
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
