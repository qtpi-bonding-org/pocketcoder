phase_name=nixos-version
phase_tier=safe-mutating

# Runs check-metadata and asserts no mismatch fields are reported, i.e. the
# box's host version and its channel's current release agree. Wrapped in
# retry_until: this phase is the first readonly/safe-mutating-tier phase to
# perform a live network Resolve() against the channel (the others work off
# already-installed local state) -- found live: it can race 55-promote's own
# concurrent promotion and briefly observe a stale, not-yet-revalidated
# channel pointer still referencing the release *before* this feature
# shipped (which correctly has no os field at all, DecodeForward leaves
# NixosVersion as "", and ValidateManifest correctly rejects that empty
# value). Confirmed live via `curl -sI .../channels/nightly-testing.json`:
# `cache-control: public, max-age=300, must-revalidate` -- a given
# Cloudflare edge PoP can keep serving a pointer it cached just before a
# promotion for up to a full 5 minutes before revalidating against origin,
# regardless of how quickly R2 itself became consistent (a first attempt at
# this used a 90s window, confirmed too short live: the exact same
# real-conditions check that failed for 90s straight passed cleanly when
# re-run by hand several minutes later on the same box). The default here
# is deliberately set past that 300s ceiling, not just past R2's own
# eventual-consistency window described in workers/image-relay/README.md's
# debugging checklist point 4.
_nixos_version_check_real_conditions() {
  local binary=$1 metadata
  ssh_exec 30 "$binary check-metadata" || {
    echo "check-metadata attempt failed" >&2
    return 1
  }
  metadata=$(ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json") || return 1
  jq -e '(.hostNixosVersion // "") == "" and (.availableNixosVersion // "") == ""' \
    <<<"$metadata" >/dev/null
}

phase_run() {
  local binary=/opt/pocketcoder/current/bin/pocketcoder-release
  local host_version metadata host available

  # /etc/nixos/nixos-version (deploy/nixos/configuration.nix) is the box's
  # own record of which NixOS release line it's pinned to. It only exists on
  # a box provisioned from an image built after this feature shipped --
  # release A is whatever was already promoted on the channel *before* this
  # suite run started (promoting a new candidate happens later in the
  # pipeline, to test the update path, not to reprovision release A), so an
  # older, pre-feature release A is expected here, not a bug. Verify the
  # documented degrade-gracefully behavior (readHostNixosVersion's doc
  # comment in cmd/pocketcoder-release/main.go) instead of assuming the file
  # exists.
  if ! ssh_exec 15 "test -f /etc/nixos/nixos-version"; then
    retry_until "${VPS_NIXOS_VERSION_RETRY_DEADLINE:-330}" \
    "${VPS_NIXOS_VERSION_RETRY_INTERVAL:-15}" \
    _nixos_version_check_real_conditions "$binary" || {
      echo "expected no mismatch fields with an unknown host version" >&2
      ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json" >&2 || true
      return 1
    }
    VPS_PHASE_EVIDENCE=$(jq -n \
      '{hostVersionFilePresent:false,degradedGracefully:true}')
    return 0
  fi

  host_version=$(ssh_exec 15 "cat /etc/nixos/nixos-version") || {
    echo "could not read the box's own pinned NixOS version" >&2
    return 1
  }
  case $host_version in
    [0-9][0-9].[0-9][0-9]) ;;
    *) echo "/etc/nixos/nixos-version has an unexpected value: $host_version" >&2; return 1 ;;
  esac

  # Real conditions: this box was just provisioned from the exact candidate
  # assemble-release-manifest.sh published, and that script cross-checks
  # configuration.nix's nixosVersion against flake.nix's pin at publish time
  # (see its "must be kept in sync" comments) -- so the box's own version and
  # its current channel manifest's declared compatibility.os.nixosVersion
  # must agree right now. No mismatch fields should be reported.
  retry_until "${VPS_NIXOS_VERSION_RETRY_DEADLINE:-330}" \
    "${VPS_NIXOS_VERSION_RETRY_INTERVAL:-15}" \
    _nixos_version_check_real_conditions "$binary" || {
    echo "unexpected NixOS version mismatch under real conditions" >&2
    ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json" >&2 || true
    return 1
  }

  # Simulate a mismatch without touching the box's real, NixOS-managed (and
  # read-only, symlinked into the Nix store) /etc/nixos/nixos-version --
  # point POCKETCODER_NIXOS_VERSION_FILE at a throwaway file for one
  # invocation instead. Exercises the exact same code path
  # (readHostNixosVersion -> BuildMetadataStatus) a real mismatch would, with
  # no mutation of anything the box itself considers authoritative.
  ssh_exec 15 "echo 00.01 > /tmp/pocketcoder-fake-nixos-version" || {
    echo "could not stage a fake NixOS version file" >&2
    return 1
  }
  if ! ssh_exec 30 "POCKETCODER_NIXOS_VERSION_FILE=/tmp/pocketcoder-fake-nixos-version $binary check-metadata"; then
    echo "check-metadata failed under a simulated mismatch" >&2
    ssh_exec 15 "rm -f /tmp/pocketcoder-fake-nixos-version" || true
    ssh_exec 30 "$binary check-metadata" || true
    return 1
  fi
  metadata=$(ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json")
  ssh_exec 15 "rm -f /tmp/pocketcoder-fake-nixos-version" || true

  host=$(jq -r '.hostNixosVersion // ""' <<<"$metadata")
  available=$(jq -r '.availableNixosVersion // ""' <<<"$metadata")
  if [ "$host" != "00.01" ] || [ -z "$available" ] || [ "$available" = "00.01" ]; then
    echo "simulated NixOS version mismatch was not reported: $metadata" >&2
    ssh_exec 30 "$binary check-metadata" || true
    return 1
  fi

  # Restore: metadata-status.json is real state that
  # pocketcoder-release-metadata.timer also reads and refreshes -- leave it
  # reflecting genuine conditions again before this phase ends, the same
  # restore-before-returning discipline 95-bootstrap-recovery.sh uses.
  retry_until "${VPS_NIXOS_VERSION_RETRY_DEADLINE:-330}" \
    "${VPS_NIXOS_VERSION_RETRY_INTERVAL:-15}" \
    _nixos_version_check_real_conditions "$binary" || {
    echo "metadata-status.json did not return to real conditions after restore" >&2
    ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json" >&2 || true
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n --arg hostVersion "$host_version" \
    --arg simulatedAvailable "$available" \
    '{hostVersionFilePresent:true,hostNixosVersion:$hostVersion,
      mismatchDetectionVerified:true,
      simulatedAvailableNixosVersion:$simulatedAvailable}')
  return 0
}
