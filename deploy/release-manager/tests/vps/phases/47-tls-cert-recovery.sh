phase_name=tls-cert-recovery
phase_tier=safe-mutating

phase_run() {
  local bundle_file fingerprint_bundle fingerprint_live fingerprint_after

  # exportCaddyCertificate/restoreCaddyCertificate (commit 90f12ffaf, fixed
  # up in efbc7c1ed) are dispatched through the real Dart RootSshCommand
  # runner (see dispatch_ssh_command in lib/common.sh) -- no VPS phase has
  # ever actually exercised the live round trip end-to-end before this one;
  # 20-topology.sh only checks that *a* valid cert exists and isn't close to
  # expiring, not that export/restore themselves work.
  bundle_file=$(mktemp)
  dispatch_ssh_command exportCaddyCertificate > "$bundle_file" || {
    echo "exportCaddyCertificate failed" >&2
    cat "$bundle_file" >&2 || true
    rm -f "$bundle_file"
    return 1
  }
  jq -e '.hostname and .certificatePemBase64 and .privateKeyPemBase64' \
    "$bundle_file" >/dev/null || {
    echo "exported certificate bundle is missing required fields" >&2
    cat "$bundle_file" >&2 || true
    rm -f "$bundle_file"
    return 1
  }

  # Confirm the exported bundle's cert is genuinely the one currently
  # live -- not a stale or mismatched file on disk -- by comparing two
  # independently-computed SHA-256 fingerprints: one decoded straight out
  # of the bundle's own embedded PEM, one read off a real TLS handshake
  # against the box (the same technique tls_expiry_days already uses).
  fingerprint_bundle=$(jq -r '.certificatePemBase64' "$bundle_file" | base64 -d |
    openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//')
  fingerprint_live=$(echo | openssl s_client -connect "$VPS_HOST:443" \
    -servername "$VPS_HOSTNAME" 2>/dev/null |
    openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//')
  if [ -z "$fingerprint_bundle" ] || [ -z "$fingerprint_live" ]; then
    echo "could not compute a certificate fingerprint" >&2
    rm -f "$bundle_file"
    return 1
  fi
  if [ "$fingerprint_bundle" != "$fingerprint_live" ]; then
    echo "exported bundle does not match the live certificate" >&2
    rm -f "$bundle_file"
    return 1
  fi

  # restoreCaddyCertificate is deliberately exercised against the box's OWN
  # already-live cert+key, not a synthetic replacement or a deleted/
  # corrupted one -- this proves round-trip fidelity (export -> restore ->
  # still byte-identical, Caddy picks up the restored file, HTTPS still
  # serves) without ever touching real ACME issuance. Actually deleting or
  # corrupting the live cert to force a genuine from-scratch recovery would
  # risk tripping Let's Encrypt's real rate limits (certificates issued per
  # registered domain per week, failed-validation limits) against this
  # box's real public hostname -- unacceptable to do routinely in a suite
  # that already runs many times a day.
  dispatch_ssh_command restoreCaddyCertificate < "$bundle_file" >/dev/null || {
    echo "restoreCaddyCertificate failed" >&2
    rm -f "$bundle_file"
    return 1
  }
  rm -f "$bundle_file"

  retry_until "${VPS_HEALTH_DEADLINE:-60}" 5 \
    https_probe_pinned "$VPS_HOSTNAME" "$VPS_HOST" /api/health >/dev/null || {
    echo "box did not become healthy after certificate restore" >&2
    return 1
  }

  fingerprint_after=$(echo | openssl s_client -connect "$VPS_HOST:443" \
    -servername "$VPS_HOSTNAME" 2>/dev/null |
    openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//')
  if [ "$fingerprint_after" != "$fingerprint_live" ]; then
    echo "certificate after restore does not match the original ($fingerprint_after != $fingerprint_live)" >&2
    return 1
  fi

  VPS_PHASE_EVIDENCE=$(jq -n --arg fingerprint "$fingerprint_live" \
    '{certificateFingerprintSha256:$fingerprint,roundTripVerified:true}')
  return 0
}
