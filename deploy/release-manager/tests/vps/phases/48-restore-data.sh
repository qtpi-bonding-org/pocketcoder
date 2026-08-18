phase_name=restore-data
phase_tier=safe-mutating

phase_run() {
  local binary=/opt/pocketcoder/current/bin/pocketcoder-release
  local integrity

  # Create the source artifact through the normal dispatched backup path,
  # then exercise restore-data's direct release-manager entry point (there is
  # intentionally no RootSshCommand for this new capability).
  dispatch_ssh_command saveBackup >/dev/null || {
    echo "saveBackup failed before restore-data" >&2
    return 1
  }

  # Leave the container running while corrupting the live database. The
  # restore-data command must own its stop/copy/start lifecycle.
  ssh_exec 30 "docker exec pocketcoder-pocketbase sh -c 'echo garbage > /app/pb_data/data.db'" || {
    echo "could not corrupt the live database" >&2
    return 1
  }

  ssh_exec 120 "$binary restore-data" || {
    echo "restore-data failed" >&2
    return 1
  }

  retry_until "${VPS_HEALTH_DEADLINE:-60}" 5 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become healthy after data restore" >&2
    return 1
  }

  integrity=$(ssh_exec 120 \
    'docker exec pocketcoder-pocketbase sqlite3 /app/pb_data/data.db "PRAGMA integrity_check;"') || {
    echo "could not check the restored live database" >&2
    return 1
  }
  [ "$integrity" = ok ] || {
    echo "restored live database failed integrity check: $integrity" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n '{restored:true,integrity:"ok"}')
  return 0
}
