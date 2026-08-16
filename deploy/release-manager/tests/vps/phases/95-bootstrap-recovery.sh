phase_name=bootstrap-recovery
phase_tier=disruptive

phase_run() {
  # Force a re-run of bootstrap by clearing its "already initialized"
  # marker, then kill it mid-run once, and confirm systemd's
  # Restart=on-failure (Task 3) brings it back on its own.
  ssh_exec 15 "rm -f /var/lib/pocketcoder/release/.initialized" || {
    echo "could not clear the bootstrap marker" >&2
    return 1
  }
  ssh_exec 15 "systemctl reset-failed pocketcoder-bootstrap.service 2>/dev/null; \
    systemctl start pocketcoder-bootstrap.service &" || true

  # Give it a moment to actually start, then kill it once.
  sleep 5
  ssh_exec 15 "pkill -TERM -f 'pocketcoder-release install' || true"

  # It should come back on its own within a couple of Restart=on-failure
  # cycles (RestartSec=10s) plus install time -- allow a generous window.
  retry_until 300 10 \
    _bootstrap_recovery_active || {
    echo "pocketcoder-bootstrap.service did not recover on its own" >&2
    ssh_exec 15 "journalctl -u pocketcoder-bootstrap --no-pager -n 60" >&2 || true
    return 1
  }

  retry_until "${VPS_HEALTH_DEADLINE:-180}" 5 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become healthy after bootstrap recovery" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n '{selfHealed:true}')
  return 0
}

_bootstrap_recovery_active() {
  local active
  active=$(ssh_exec 15 "systemctl is-active pocketcoder-bootstrap.service" 2>/dev/null || true)
  [ "$active" = "active" ]
}
