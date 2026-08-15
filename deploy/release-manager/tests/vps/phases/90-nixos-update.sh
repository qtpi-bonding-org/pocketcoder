phase_name=nixos-update
phase_tier=disruptive

phase_precondition() {
  if [ "${VPS_INCLUDE_NIXOS_UPDATE:-0}" != 1 ]; then
    echo "not enabled; pass --include-nixos-update"
    return 1
  fi
  return 0
}

phase_run() {
  local before after output

  # The image bakes its configuration, so /etc/nixos may be empty. That is a
  # known product defect; record it as skipped rather than failing the suite.
  if ! ssh_exec 30 'test -f /etc/nixos/configuration.nix'; then
    echo "/etc/nixos/configuration.nix is not persisted in this image"
    return 78
  fi

  before=$(ssh_exec 30 'readlink -f /nix/var/nix/profiles/system')
  output=$(ssh_exec 1800 "$(shipped_command updateNixOs)" 2>&1) || {
    printf '%s\n' "$output" >&2
    return 1
  }
  if printf '%s' "$output" | grep -Eqi '(^|[[:space:]])error:|returned non-zero exit status'; then
    echo "nixos-rebuild reported an error despite returning success" >&2
    return 1
  fi

  retry_until "${VPS_HEALTH_DEADLINE:-300}" 10 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "stack did not recover after the NixOS update" >&2
    return 1
  }

  after=$(ssh_exec 30 'readlink -f /nix/var/nix/profiles/system')
  # The old suite asserted only that both values were non-empty, which is
  # vacuous. The generation must actually change.
  if [ "$before" = "$after" ]; then
    echo "system generation did not change ($before)" >&2
    return 1
  fi
  [ "$(ssh_exec 30 'systemctl is-system-running 2>/dev/null || true')" = running ] || {
    echo "system is not fully running after the update" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n --arg before "$before" --arg after "$after" \
    '{generationBefore:$before,generationAfter:$after}')
  return 0
}