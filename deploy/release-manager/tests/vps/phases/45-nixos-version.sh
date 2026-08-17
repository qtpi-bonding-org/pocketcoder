phase_name=nixos-version
phase_tier=safe-mutating

phase_run() {
  local binary=/opt/pocketcoder/current/bin/pocketcoder-release
  local host_version metadata host available

  # /etc/nixos/nixos-version (deploy/nixos/configuration.nix) is the box's
  # own record of which NixOS release line it's pinned to.
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
  ssh_exec 30 "$binary check-metadata" || {
    echo "check-metadata failed under real conditions" >&2
    return 1
  }
  metadata=$(ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json") || {
    echo "could not read metadata-status.json" >&2
    return 1
  }
  jq -e '(.hostNixosVersion // "") == "" and (.availableNixosVersion // "") == ""' \
    <<<"$metadata" >/dev/null || {
    echo "unexpected NixOS version mismatch under real conditions: $metadata" >&2
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
  ssh_exec 30 "$binary check-metadata" || {
    echo "could not restore metadata-status.json to real conditions" >&2
    return 1
  }
  metadata=$(ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json")
  jq -e '(.hostNixosVersion // "") == "" and (.availableNixosVersion // "") == ""' \
    <<<"$metadata" >/dev/null || {
    echo "metadata-status.json did not return to real conditions after restore" >&2
    return 1
  }

  VPS_PHASE_EVIDENCE=$(jq -n --arg hostVersion "$host_version" \
    --arg simulatedAvailable "$available" \
    '{hostNixosVersion:$hostVersion,mismatchDetectionVerified:true,
      simulatedAvailableNixosVersion:$simulatedAvailable}')
  return 0
}
