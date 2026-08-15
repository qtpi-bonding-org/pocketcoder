phase_name=reboot
phase_tier=disruptive

phase_run() {
  local before after name

  before=${VPS_BOOT_ID_BEFORE_OVERRIDE:-$(boot_id_now)}
  [ -n "$before" ] || { echo "could not read boot_id before reboot" >&2; return 1; }

  # The SSH channel is expected to die mid-command; that is not a failure.
  ssh_exec_detached 30 "$(shipped_command restartNixOs)"

  # Do not start polling immediately: SSH answers for several seconds after
  # `reboot` is accepted, which is exactly how the old suite produced a false
  # pass. Wait out the shutdown window first.
  sleep "${VPS_REBOOT_SETTLE:-20}"

  retry_until "${VPS_REBOOT_DEADLINE:-600}" 10 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "host did not return after reboot" >&2
    return 1
  }

  after=$(boot_id_now)
  if [ "$before" = "$after" ]; then
    echo "boot_id did not change ($before): the host never rebooted" >&2
    return 1
  fi

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ "$(container_health "$name")" = healthy ] || {
      echo "container $name is not healthy after reboot" >&2
      return 1
    }
  done <<EOF
$(expected_containers)
EOF

  VPS_PHASE_EVIDENCE=$(jq -n --arg before "$before" --arg after "$after" \
    '{bootIdBefore:$before,bootIdAfter:$after}')
  return 0
}