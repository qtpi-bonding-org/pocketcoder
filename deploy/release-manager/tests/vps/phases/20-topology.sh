phase_name=topology
phase_tier=readonly

phase_run() {
  local name health tls_days

  # Every deployed container must report its OWN healthcheck as healthy.
  # Counting running containers, as the old suite did, passes on a broken box.
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    health=$(container_health "$name")
    if [ "$health" != healthy ]; then
      echo "container $name is $health, expected healthy" >&2
      return 1
    fi
  done <<EOF
$(expected_containers)
EOF

  # The real edge: ordinary DNS, real certificate, no --insecure.
  https_probe_public "$VPS_HOSTNAME" /api/health >/dev/null || {
    echo "public HTTPS health probe failed" >&2
    return 1
  }
  https_probe_public "$VPS_HOSTNAME" /api/pocketcoder/v1/compatibility |
    jq -e '(.JsonSuccessJSONResponse // .) |
      .schemaVersion == 1 and .compatibility.server.apiVersion == 1' >/dev/null || {
    echo "compatibility payload did not match the expected versions" >&2
    return 1
  }

  tls_days=$(tls_expiry_days "$VPS_HOSTNAME" "$VPS_HOST") || {
    echo "could not read the TLS certificate expiry" >&2
    return 1
  }
  if [ "$tls_days" -lt 7 ]; then
    echo "TLS certificate expires in $tls_days days" >&2
    return 1
  fi

  # The release-metadata timer must be enabled with its randomized delay.
  [ "$(ssh_exec 30 'systemctl is-enabled pocketcoder-release-metadata.timer')" = enabled ] || {
    echo "pocketcoder-release-metadata.timer is not enabled" >&2
    return 1
  }
  ssh_exec 30 'systemctl cat pocketcoder-release-metadata.timer' |
    grep -q 'RandomizedDelaySec' || {
    echo "release-metadata timer has no randomized delay" >&2
    return 1
  }

  # Security property: containers must not reach cloud metadata.
  if ssh_exec 60 "docker run --rm --network container:pocketcoder-pocketbase \
      curlimages/curl:8.10.1 --max-time 5 -s http://169.254.169.254/ >/dev/null 2>&1"; then
    echo "cloud metadata endpoint is reachable from inside a container" >&2
    return 1
  fi

  VPS_PHASE_EVIDENCE=$(jq -n --argjson tlsDays "$tls_days" \
    '{tlsExpiryDays:$tlsDays,metadataReachable:false}')
  return 0
}
