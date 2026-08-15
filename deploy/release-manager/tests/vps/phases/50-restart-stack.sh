phase_name=restart-stack
phase_tier=disruptive

phase_run() {
  local name before after unchanged= safe_name

  while IFS= read -r name; do
    [ -n "$name" ] || continue
    safe_name=$(printf '%s' "$name" | tr -c 'a-zA-Z0-9' '_')
    eval "before_$safe_name=\$(container_started_at \"\$name\")"
  done <<EOF
$(expected_containers)
EOF

  ssh_exec 300 "$(shipped_command restartPocketCoder)" >/dev/null || {
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
    [ "$(container_health "$name")" = healthy ] || {
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