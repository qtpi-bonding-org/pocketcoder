phase_name=backup
phase_tier=safe-mutating

phase_run() {
  local started=${VPS_PHASE_STARTED:-$(date +%s)}
  local artifact=/app/pb_backups/data.db
  local checksum mtime integrity

  dispatch_ssh_command saveBackup >/dev/null || {
    echo "saveBackup failed" >&2
    return 1
  }

  # Freshness is the assertion the old suite lacked: a stale artifact left by
  # a previous run passed every check.
  mtime=$(ssh_exec 60 "docker exec pocketcoder-pocketbase stat -c %Y $artifact")
  case $mtime in
    '' | *[!0-9]*) echo "could not read the backup artifact mtime" >&2; return 1 ;;
  esac
  if [ "$mtime" -lt "$started" ]; then
    echo "backup artifact is stale: mtime $mtime predates phase start $started" >&2
    return 1
  fi

  checksum=$(ssh_exec 120 "docker exec pocketcoder-pocketbase sha256sum $artifact" |
    awk 'NF == 2 { print $1 }')
  case $checksum in
    [0-9a-f]*) [ "${#checksum}" -eq 64 ] || { echo "bad checksum: $checksum" >&2; return 1; } ;;
    *) echo "bad checksum: $checksum" >&2; return 1 ;;
  esac

  local integrity_script
  integrity_script=$(cat <<'EOF'
docker exec pocketcoder-pocketbase sh -ec '
    tmp=$(mktemp -d /tmp/pocketcoder-backup-restore.XXXXXX)
    trap "rm -rf \"$tmp\"" EXIT
    cp /app/pb_backups/data.db "$tmp/data.db"
    sqlite3 "$tmp/data.db" "PRAGMA integrity_check;"
  '
EOF
  )
  integrity=$(ssh_exec 120 "$integrity_script")
  [ "$integrity" = ok ] || { echo "restored copy failed integrity check: $integrity" >&2; return 1; }

  VPS_PHASE_EVIDENCE=$(jq -n --arg checksum "$checksum" --argjson mtime "$mtime" \
    '{backupChecksum:$checksum,backupMtime:$mtime,restoredIntegrity:"ok"}')
  return 0
}
