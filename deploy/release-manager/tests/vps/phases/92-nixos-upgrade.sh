phase_name=nixos-upgrade
phase_tier=disruptive

# KNOWN LIMITATION: upgrade-os has no explicit target-version flag -- it
# always upgrades to whatever compatibility.os.nixosVersion the currently
# promoted channel release declares. A real round-trip test therefore needs
# a second, distinct candidate release B whose deploy/nixos/nixos-version.nix
# pin differs from the box's current one.
#
# That release B is built and promoted from a dedicated vps-test/* branch
# (see .github/workflows/nixos-image.yml's candidate job and
# promote-latest-candidate.sh), always on the beta channel -- never nightly,
# which 55-promote.sh/60-update.sh already own for the everyday app-level
# release B, and never stable. This keeps the round-trip's candidate on its
# own beta-testing.json pointer, unreachable by any main-trust (real user)
# box and never colliding with the ordinary VPS suite's own test candidate.
# Promoting it is a manual, out-of-band step before running this phase --
# not automated here -- so this phase self-skips via phase_precondition
# when no such candidate has been promoted yet, rather than hardcoding
# "25.11"/"26.05" literals it cannot actually control.

phase_precondition() {
  local current
  if [ -z "${VPS_RELEASE_B_DIGEST:-}" ] || [ -z "${VPS_RELEASE_B_NIXOS_VERSION:-}" ]; then
    echo "no candidate release B with a distinct NixOS version pin was promoted; set VPS_RELEASE_B_DIGEST and VPS_RELEASE_B_NIXOS_VERSION"
    return 1
  fi
  current=$(ssh_exec 15 'cat /etc/nixos/nixos-version') || {
    echo "could not read the box's current NixOS version" >&2
    return 1
  }
  if [ "$current" = "$VPS_RELEASE_B_NIXOS_VERSION" ]; then
    echo "candidate release B has the box's current NixOS version pin; nothing to upgrade to"
    return 1
  fi
  return 0
}

phase_run() {
  local binary=/opt/pocketcoder/current/bin/pocketcoder-release
  local branch_env="export POCKETCODER_GITHUB_WORKFLOW_BRANCH=${VPS_RELEASE_BRANCH:-main}; "
  local before after rolled_back unchanged

  before=$(ssh_exec 15 'cat /etc/nixos/nixos-version') || {
    echo "could not read the box's current NixOS version" >&2
    return 1
  }
  [ "$before" != "$VPS_RELEASE_B_NIXOS_VERSION" ] || {
    echo "box is already on the candidate NixOS version; nothing to upgrade to" >&2
    return 1
  }

  # 1. Real upgrade to candidate release B's NixOS version pin. --channel
  # beta is explicit, not the box's default channel: release B only ever
  # lives on beta-testing.json (see the header comment above).
  ssh_exec 1800 "${branch_env}${binary} upgrade-os --channel beta" || {
    echo "upgrade-os failed" >&2
    return 1
  }
  after=$(ssh_exec 15 'cat /etc/nixos/nixos-version') || {
    echo "could not read the box's NixOS version after upgrade-os" >&2
    return 1
  }
  [ "$after" = "$VPS_RELEASE_B_NIXOS_VERSION" ] || {
    echo "expected NixOS version $VPS_RELEASE_B_NIXOS_VERSION after upgrade-os, got $after" >&2
    return 1
  }
  retry_until "${VPS_HEALTH_DEADLINE:-300}" 10 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become healthy after upgrade-os" >&2
    return 1
  }

  # 2. Explicit rollback back to the original version.
  ssh_exec 1800 "${binary} rollback-os" || {
    echo "rollback-os failed" >&2
    return 1
  }
  rolled_back=$(ssh_exec 15 'cat /etc/nixos/nixos-version') || {
    echo "could not read the box's NixOS version after rollback-os" >&2
    return 1
  }
  [ "$rolled_back" = "$before" ] || {
    echo "expected NixOS version $before after rollback-os, got $rolled_back" >&2
    return 1
  }
  retry_until "${VPS_HEALTH_DEADLINE:-300}" 10 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become healthy after rollback-os" >&2
    return 1
  }

  # 3. Forced-failure: an unresolvable channel must fail closed before
  # Activate ever runs, and must not touch the box's version. Cannot
  # manufacture a genuine mid-switch nixos-rebuild failure against a real,
  # already-published, presumably-working release -- see
  # 95-bootstrap-recovery.sh for the same kind of simulated-failure
  # limitation. Point --channel at a channel name no real manifest ever
  # uses, forcing Resolver.Resolve() to fail before Activate.
  if ssh_exec 60 "${binary} upgrade-os --channel pocketcoder-test-nonexistent-channel-00-01"; then
    echo "expected upgrade-os to fail closed against a nonexistent channel" >&2
    return 1
  fi
  unchanged=$(ssh_exec 15 'cat /etc/nixos/nixos-version') || {
    echo "could not read the box's NixOS version after the forced-failure attempt" >&2
    return 1
  }
  [ "$unchanged" = "$before" ] || {
    echo "box's NixOS version changed despite upgrade-os failing closed: $unchanged" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n --arg before "$before" --arg after "$after" \
    '{nixosVersionBefore:$before,nixosVersionAfterUpgrade:$after,rolledBack:true,forcedFailureRejectedCleanly:true}')
  return 0
}
