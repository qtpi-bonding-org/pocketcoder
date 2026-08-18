phase_name=nixos-version
phase_tier=safe-mutating

# Runs check-metadata and asserts no mismatch fields are reported, i.e. the
# box's host version and its channel's current release agree.
#
# The real, deterministic root cause of this phase's early failures (found
# live, by comparing a manual bare-SSH shell's environment against
# `systemctl show pocketcoder-release-metadata.service -p Environment`):
# ChannelPath() (internal/release/resolver.go) branch-qualifies purely off
# POCKETCODER_GITHUB_WORKFLOW_BRANCH -- unset/empty resolves the bare,
# main-trust "nightly.json", NOT the branch-qualified "nightly-testing.json"
# this suite actually promotes onto. A bare `ssh_exec "$binary
# check-metadata"` (no env) always hit that bare channel, which still
# pointed at a real pre-feature release with no `os` field at all --
# "invalid NixOS compatibility version" was correct, deterministic
# behavior, not a caching artifact. (An earlier version of this phase
# theorized a Cloudflare edge-cache TTL race and widened a retry window
# instead -- that diagnosis was built entirely on manual `curl` commands
# that hardcoded the "nightly-testing.json" path directly, bypassing
# ChannelPath() and this exact bug, so it never could have disproved it.)
# 60-update.sh and 85-rollback.sh already establish the fix for their own
# dispatch_ssh_command calls: export POCKETCODER_GITHUB_WORKFLOW_BRANCH=
# ${release_branch:-main} before invoking anything that resolves a
# channel. This phase calls the release-manager binary directly rather
# than through dispatch_ssh_command, so the same export is inlined into
# every ssh_exec command line below instead.
_nixos_version_check_real_conditions() {
  local binary=$1 metadata
  ssh_exec 30 "export POCKETCODER_GITHUB_WORKFLOW_BRANCH=${release_branch:-main}; $binary check-metadata" || {
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
    retry_until "${VPS_NIXOS_VERSION_RETRY_DEADLINE:-90}" \
      "${VPS_NIXOS_VERSION_RETRY_INTERVAL:-10}" \
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
  retry_until "${VPS_NIXOS_VERSION_RETRY_DEADLINE:-90}" \
    "${VPS_NIXOS_VERSION_RETRY_INTERVAL:-10}" \
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
  if ! ssh_exec 30 "export POCKETCODER_GITHUB_WORKFLOW_BRANCH=${release_branch:-main}; POCKETCODER_NIXOS_VERSION_FILE=/tmp/pocketcoder-fake-nixos-version $binary check-metadata"; then
    echo "check-metadata failed under a simulated mismatch" >&2
    ssh_exec 15 "rm -f /tmp/pocketcoder-fake-nixos-version" || true
    ssh_exec 30 "export POCKETCODER_GITHUB_WORKFLOW_BRANCH=${release_branch:-main}; $binary check-metadata" || true
    return 1
  fi
  metadata=$(ssh_exec 15 "cat /var/lib/pocketcoder/release/metadata-status.json")
  ssh_exec 15 "rm -f /tmp/pocketcoder-fake-nixos-version" || true

  host=$(jq -r '.hostNixosVersion // ""' <<<"$metadata")
  available=$(jq -r '.availableNixosVersion // ""' <<<"$metadata")
  if [ "$host" != "00.01" ] || [ -z "$available" ] || [ "$available" = "00.01" ]; then
    echo "simulated NixOS version mismatch was not reported: $metadata" >&2
    ssh_exec 30 "export POCKETCODER_GITHUB_WORKFLOW_BRANCH=${release_branch:-main}; $binary check-metadata" || true
    return 1
  fi

  # Restore: metadata-status.json is real state that
  # pocketcoder-release-metadata.timer also reads and refreshes -- leave it
  # reflecting genuine conditions again before this phase ends, the same
  # restore-before-returning discipline 95-bootstrap-recovery.sh uses.
  retry_until "${VPS_NIXOS_VERSION_RETRY_DEADLINE:-90}" \
    "${VPS_NIXOS_VERSION_RETRY_INTERVAL:-10}" \
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
