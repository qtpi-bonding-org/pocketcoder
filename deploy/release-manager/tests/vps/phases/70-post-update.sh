phase_name=post-update
phase_tier=disruptive

# Reads ON-BOX state, not in-run phase selection, so a standalone
# `--only post-update` invocation against a separate process is well-defined.
phase_precondition() {
  local digest
  digest=$(ssh_exec 30 'cat /var/lib/pocketcoder/release/current.json' |
    jq -r '.releaseDigest')
  if [ "$digest" != "${VPS_RELEASE_B_DIGEST:-}" ]; then
    echo "box reports $digest, not release B ${VPS_RELEASE_B_DIGEST:-unset}"
    return 1
  fi
  return 0
}

_container_is_healthy() { [ "$(container_health "$1")" = healthy ]; }

phase_run() {
  local rollback_allowed manager_sha name

  https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "health probe failed after update" >&2
    return 1
  }

  # A container's own HEALTHCHECK needs a few cycles after restart before
  # settling from "starting" to "healthy" -- see 50-restart-stack.sh for the
  # identical race confirmed live on a plain restart.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    retry_until "${VPS_HEALTH_DEADLINE:-180}" 5 _container_is_healthy "$name" || {
      echo "container $name is not healthy after update" >&2
      return 1
    }
  done <<EOF
$(expected_containers)
EOF

  # The Phase 3 backup artifact must survive the update.
  ssh_exec 60 'docker exec pocketcoder-pocketbase test -s /app/pb_backups/data.db' || {
    echo "the backup artifact did not survive the update" >&2
    return 1
  }

  manager_sha=$(ssh_exec 60 'sha256sum /opt/pocketcoder/current/bin/pocketcoder-release | cut -d" " -f1')
  [ -n "$manager_sha" ] || { echo "could not read the release-manager checksum" >&2; return 1; }

  # Record whether normal rollback is allowed across the data-version
  # boundary. Both answers are valid; silence is not.
  rollback_allowed=$(ssh_exec 30 'cat /var/lib/pocketcoder/release/metadata-status.json 2>/dev/null' |
    jq -r '.normalRollbackAvailableAfterSuccess // "unknown"')
  case $rollback_allowed in
    true | false) ;;
    *) echo "metadata-status.json did not report normalRollbackAvailableAfterSuccess" >&2
       return 1 ;;
  esac

  VPS_PHASE_EVIDENCE=$(jq -n --arg sha "$manager_sha" --arg rollback "$rollback_allowed" \
    '{releaseManagerSha256:$sha,normalRollbackAvailableAfterSuccess:$rollback}')
  return 0
}
