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
  local rollback_allowed manager_sha name status metadata

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
  #
  # metadata-status.json is produced by pocketcoder-release-metadata.service,
  # which runs on a 15min-after-boot / 6h timer with a randomized delay --
  # deliberately staggered so every deployment doesn't hit GitHub at once.
  # `update` itself never writes this file, so on a freshly provisioned or
  # freshly updated box it may not exist yet -- confirmed live: a box updated
  # seconds earlier had no metadata-status.json at all. Trigger the oneshot
  # service directly instead of waiting out its timer.
  ssh_exec 60 'systemctl start pocketcoder-release-metadata.service' >/dev/null || {
    echo "could not trigger pocketcoder-release-metadata.service" >&2
    return 1
  }
  metadata=$(ssh_exec 30 'cat /var/lib/pocketcoder/release/metadata-status.json 2>/dev/null')
  status=$(jq -r '.status // "unknown"' <<<"$metadata")
  rollback_allowed=$(jq -r '.normalRollbackAvailableAfterSuccess // "unknown"' <<<"$metadata")
  case $status in
    # normalRollbackAvailableAfterSuccess only means anything when the
    # channel has a newer release than what's active -- BuildMetadataStatus
    # (internal/release/metadata.go) never sets it for "current", since
    # there's no candidate update to compare data versions against. This
    # box was just promoted to the newest release, so "current" is the
    # expected outcome here, not a missing-data failure.
    current) rollback_allowed=not-applicable ;;
    update-available)
      case $rollback_allowed in
        true | false) ;;
        *) echo "status is update-available but normalRollbackAvailableAfterSuccess was not reported" >&2
           return 1 ;;
      esac
      ;;
    *) echo "metadata-status.json reported unexpected status: $status" >&2
       return 1 ;;
  esac

  VPS_PHASE_EVIDENCE=$(jq -n --arg sha "$manager_sha" --arg rollback "$rollback_allowed" \
    '{releaseManagerSha256:$sha,normalRollbackAvailableAfterSuccess:$rollback}')
  return 0
}
