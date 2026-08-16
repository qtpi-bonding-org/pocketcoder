phase_name=restart-stack
phase_tier=disruptive

_container_is_healthy() { [ "$(container_health "$1")" = healthy ]; }

phase_run() {
  local name before after unchanged= safe_name

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    safe_name=$(printf '%s' "$name" | tr -c 'a-zA-Z0-9' '_')
    eval "before_$safe_name=\$(container_started_at \"\$name\")"
  done <<EOF
$(expected_containers)
EOF

  dispatch_ssh_command restartPocketCoder >/dev/null || {
    echo "restartPocketCoder failed" >&2
    return 1
  }

  retry_until "${VPS_HEALTH_DEADLINE:-180}" 5 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "stack did not become reachable after restart" >&2
    return 1
  }

  # A no-op restart used to pass because the old suite only counted
  # containers. Every container's StartedAt must actually advance.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    safe_name=$(printf '%s' "$name" | tr -c 'a-zA-Z0-9' '_')
    eval "before=\$before_$safe_name"
    after=$(container_started_at "$name")
    if [ "$before" = "$after" ]; then
      unchanged="$unchanged $name"
    fi
    # A container's own HEALTHCHECK needs a few cycles after restart before
    # settling from "starting" to "healthy" -- confirmed live: pocketbase
    # reported unhealthy on a single immediate check, then healthy a few
    # seconds later with a clean startup log the whole time. Retry with the
    # same deadline as the stack-wide probe above.
    retry_until "${VPS_HEALTH_DEADLINE:-180}" 5 _container_is_healthy "$name" || {
      echo "container $name is not healthy after restart" >&2
      return 1
    }
  done <<EOF
$(expected_containers)
EOF

  if [ -n "$unchanged" ]; then
    echo "containers did not restart:$unchanged" >&2
    return 1
  fi

  VPS_PHASE_EVIDENCE=$(jq -n '{allContainersRestarted:true}')
  return 0
}