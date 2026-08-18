phase_name=bootstrap-recovery
phase_tier=disruptive

phase_run() {
  # bootstrap.nix's ConditionPathExists=!/opt/pocketcoder/current/bin/pocketcoder-release
  # (added to stop pocketcoder-bootstrap.service from re-running first-boot
  # provisioning on every ordinary `nixos-rebuild switch`) checks that path,
  # not the .initialized marker below -- clearing .initialized alone no
  # longer lets the unit start at all on an already-installed box, since
  # the Condition correctly refuses to re-run against a real install. To
  # faithfully simulate a crash mid-install (not "reset a marker on an
  # already-finished install"), move the installed symlink itself aside for
  # the duration of this phase, so the Condition sees "not installed" the
  # same way a genuine first boot would. /opt/pocketcoder/current is just a
  # symlink to /opt/pocketcoder/releases/<digest> -- moving it touches
  # nothing about the actual release contents underneath.
  ssh_exec 15 "mv /opt/pocketcoder/current /opt/pocketcoder/.current-bootstrap-recovery-test" || {
    echo "could not stage the bootstrap-recovery simulation" >&2
    return 1
  }

  # runtime.env's POCKETCODER_RELEASE_DIGEST is a static value baked once
  # at first boot -- it never gets updated as the box legitimately moves to
  # a different release via the update/rollback phases earlier in this same
  # run. Re-running install against that stale digest fails for a second,
  # unrelated reason ("already installed at a different release; use
  # update") even once the Condition above is satisfied. Sync it to
  # whatever the box's real current release actually is before simulating
  # the crash, so the reinstall's expected-digest check matches reality
  # instead of a first-boot-only value.
  local actual_digest
  actual_digest=$(ssh_exec 15 "jq -r .releaseDigest /var/lib/pocketcoder/release/current.json") || {
    echo "could not read the box's actual current release digest" >&2
    _bootstrap_recovery_restore_current
    return 1
  }
  ssh_exec 15 "sed -i 's/^POCKETCODER_RELEASE_DIGEST=.*/POCKETCODER_RELEASE_DIGEST=$actual_digest/' /var/lib/pocketcoder/config/runtime.env" || {
    echo "could not sync runtime.env's expected digest" >&2
    _bootstrap_recovery_restore_current
    return 1
  }

  ssh_exec 15 "rm -f /var/lib/pocketcoder/release/.initialized" || true
  ssh_exec 15 "systemctl reset-failed pocketcoder-bootstrap.service 2>/dev/null; \
    systemctl start pocketcoder-bootstrap.service &" || true

  # Give it a moment to actually start, then kill it once.
  sleep 5
  ssh_exec 15 "pkill -TERM -f 'pocketcoder-release install' || true"

  # It should come back on its own within a couple of Restart=on-failure
  # cycles (RestartSec=10s) plus install time -- allow a generous window.
  if ! retry_until 300 10 _bootstrap_recovery_active; then
    echo "pocketcoder-bootstrap.service did not recover on its own" >&2
    ssh_exec 15 "journalctl -u pocketcoder-bootstrap --no-pager -n 60" >&2 || true
    _bootstrap_recovery_restore_current
    return 1
  fi

  # A successful re-run recreates /opt/pocketcoder/current pointing at the
  # same release -- this is belt-and-suspenders in case that didn't happen
  # for some reason, so a later phase never finds the box mid-simulation.
  _bootstrap_recovery_restore_current

  retry_until "${VPS_HEALTH_DEADLINE:-180}" 5 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become healthy after bootstrap recovery" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n '{selfHealed:true}')
  return 0
}

_bootstrap_recovery_restore_current() {
  ssh_exec 15 "[ -e /opt/pocketcoder/current ] || \
    mv /opt/pocketcoder/.current-bootstrap-recovery-test /opt/pocketcoder/current 2>/dev/null; \
    rm -rf /opt/pocketcoder/.current-bootstrap-recovery-test" || true
}

_bootstrap_recovery_active() {
  local active
  active=$(ssh_exec 15 "systemctl is-active pocketcoder-bootstrap.service" 2>/dev/null || true)
  [ "$active" = "active" ]
}
