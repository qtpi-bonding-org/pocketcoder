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
  # $existing must always be JSON *content*, never a file path -- jq's CLI
  # treats a trailing positional argument as a file to open, so passing the
  # literal string "{}" (the correct fallback on a fresh box, which is
  # every box's very first pc_status_init call) made jq try to open a file
  # literally named "{}" and fail immediately. Confirmed live: this broke
  # bootstrap.sh's first-ever status write on every single fresh boot.
  # Feeding content through a herestring instead of a positional filename
  # sidesteps the ambiguity entirely.
  existing='{}'
  if [ -s "$PC_STATUS_FILE" ] && jq -e . "$PC_STATUS_FILE" >/dev/null 2>&1; then
    existing=$(cat "$PC_STATUS_FILE")
  fi
  tmp=$(mktemp -p "$PC_STATUS_DIR" .status.XXXXXX)
  jq \
    --argjson schema 3 \
    --arg runId "$PC_RUN_ID" \
    --arg operation "$phase" \
    --arg detail "$detail" \
    --arg sourceCommit "${PC_SOURCE_COMMIT:-unknown}" \
    --arg sshHostKeyType "$ssh_host_key_type" \
    --arg sshHostKeyFingerprint "$ssh_host_key_fingerprint" \
    --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg errorCode "$error" \
    '(. + {schema:$schema,runId:$runId,operation:$operation,
      detail:(if $detail == "" then null else $detail end),
      sourceCommit:$sourceCommit,updatedAt:$updatedAt,
      sshHostKey:(if $sshHostKeyType == "" or $sshHostKeyFingerprint == ""
        then null
        else {type:$sshHostKeyType,fingerprint:$sshHostKeyFingerprint}
        end),
      errorCode:(if $errorCode == "" then null else $errorCode end),
      errorMessage:null})' <<<"$existing" > "$tmp"
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
  # dartssh2's onVerifyHostKey callback (the only consumer of this field,
  # via SshRootCommandRunner) is documented to pass "OpenSSH-style SHA256
  # fingerprint... UTF-8 encoded as SHA256:<base64>" -- confirmed live:
  # publishing an MD5 fingerprint here meant the comparison could never
  # succeed, so onVerifyHostKey always returned false and dartssh2 closed
  # every connection before ever attempting authentication (visible
  # server-side as sshd's srclimit_penalise "connections without
  # attempting authentication"). Every root SSH command -- restart,
  # update, backup, cert export/restore, rollback -- was silently unusable
  # since this was written.
  fingerprint=$(ssh-keygen -E sha256 -lf "$public_key" 2>/dev/null | awk '{print $2}')
  case "$fingerprint" in SHA256:?*) ;;
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
