phase_name=rollback
phase_tier=disruptive

phase_precondition() {
  if [ -z "${VPS_RELEASE_B_DIGEST:-}" ]; then
    echo "no release B candidate available"
    return 1
  fi
  return 0
}

phase_run() {
  local current_digest

  # Success case: same data version as baseline (the promoted candidate
  # this run built is always same-data-version as A unless the promotion
  # pipeline itself bumped dataVersion, which 55-promote.sh doesn't do) --
  # rollback must succeed and revert current.json's digest to A.
  dispatch_ssh_command rollback >/dev/null || {
    echo "rollback command failed" >&2
    return 1
  }

  retry_until "${VPS_HEALTH_DEADLINE:-180}" 5 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become reachable after rollback" >&2
    return 1
  }

  current_digest=$(ssh_exec 30 \
    "jq -r '.releaseDigest' /var/lib/pocketcoder/release/current.json")
  if [ "$current_digest" != "$VPS_RELEASE_A_DIGEST" ]; then
    echo "rollback did not revert to release A (got $current_digest, want $VPS_RELEASE_A_DIGEST)" >&2
    return 1
  fi

  # Re-update back to B so later phases (nixos-update) run against the
  # release this run actually promoted, not a stale rollback state.
  dispatch_ssh_command updatePocketCoder \
    "export POCKETCODER_GITHUB_WORKFLOW_BRANCH=${VPS_RELEASE_BRANCH:-main}; " >/dev/null || {
    echo "re-update to release B after rollback failed" >&2
    return 1
  }
  retry_until "${VPS_HEALTH_DEADLINE:-180}" 5 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become reachable after re-update" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n --arg a "$VPS_RELEASE_A_DIGEST" --arg b "$VPS_RELEASE_B_DIGEST" \
    '{rolledBackTo:$a,reupdatedTo:$b}')
  return 0
}
