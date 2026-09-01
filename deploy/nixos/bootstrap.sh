#!/usr/bin/env bash
set -euo pipefail

RELEASES_DIR=/opt/pocketcoder/releases
RELEASE_STATE=/var/lib/pocketcoder/release
ARTIFACT_DIR=/var/lib/pocketcoder/artifacts
RUNTIME_ENV=/var/lib/pocketcoder/config/runtime.env
MARKER="$RELEASE_STATE/.initialized"
INSTALLER_LOG=/var/lib/pocketcoder-installer-debug.log
INSTALLER_LOG_IMPORTED_MARKER=/var/lib/pocketcoder-installer-log-imported

# systemd may retry this unit before initialization completes. Import once
# per boot attempt and fail open so diagnostics cannot block provisioning.
if [ -f "$INSTALLER_LOG" ] && [ ! -f "$INSTALLER_LOG_IMPORTED_MARKER" ]; then
  if systemd-cat -t pocketcoder-installer < "$INSTALLER_LOG" && \
      touch "$INSTALLER_LOG_IMPORTED_MARKER"; then
    :
  else
    echo "WARNING: failed to import installer log into journald -- continuing boot" >&2
  fi
fi

if [ -f "$MARKER" ]; then
  echo "PocketCoder already initialized, skipping bootstrap"
  exit 0
fi

source /etc/pocketcoder/status.sh
source /etc/pocketcoder/pc_retry.sh
trap 'pc_status_error "$PC_CURRENT_PHASE" "step failed at line ${BASH_LINENO[0]}"' ERR
pc_status_init
umask 077

pc_debug_dump() {
  echo "===== pc_debug_dump: $1 ====="
  df -h /var/lib/pocketcoder 2>&1 || true
  free -h 2>&1 || true
  docker ps -a 2>&1 || true
  docker compose -f /opt/pocketcoder/releases/current/docker-compose.yml \
    --project-name pocketcoder ps 2>&1 || true
  echo "===== end pc_debug_dump: $1 ====="
}
install -d -m 0755 "$RELEASES_DIR" "$RELEASE_STATE/manifests"
install -d -m 0700 "$ARTIFACT_DIR" /var/lib/pocketcoder/config

# POCO:BEGIN bootstrap-owner-config
# NixOS accepts owner configuration from the one-shot file written by the
# image installer. A compatibility fallback can still read Linode metadata,
# and an interrupted boot resumes from the protected environment file.
#
# BOOT-ENV SCHEMA (the single authoritative schema; the image installer must
# write exactly these fields): SCHEMA=1, root_ssh_key, host_ssh_private_key
# (base64-encoded OpenSSH private key), host_ssh_public_key, BOX_PRIVATE_KEY_PKCS8,
# BOX_CREDENTIAL, public_ip,
# POCKETCODER_RELEASE_CHANNEL, POCKETCODER_RELEASE_DIGEST,
# POCKETCODER_RELEASE_SEQUENCE, and POCKETCODER_SELECTED_HARNESSES. Fields
# are single-line KEY=value records. Adding or changing fields requires a
# schema version bump and an explicit validator here.
BOOTSTRAP_ENV_FILE=/var/lib/pocketcoder-bootstrap-env
if [ -f "$BOOTSTRAP_ENV_FILE" ]; then
  install -m 600 /dev/null "$RUNTIME_ENV"
  cp "$BOOTSTRAP_ENV_FILE" "$RUNTIME_ENV"
  chmod 600 "$RUNTIME_ENV"
  shred -u "$BOOTSTRAP_ENV_FILE" 2>/dev/null || rm -f "$BOOTSTRAP_ENV_FILE"
elif [ -f "$RUNTIME_ENV" ]; then
  chmod 600 "$RUNTIME_ENV"
else
  USER_DATA=""
  _pc_fetch_metadata() {
    local metadata_token
    metadata_token=$(curl -sf --max-time 5 -X PUT \
      -H 'Metadata-Token-Expiry-Seconds: 300' \
      http://169.254.169.254/v1/token || true)

    [ -n "$metadata_token" ] || return 1
    USER_DATA=$(curl -sf --max-time 10 \
      -H "Metadata-Token: $metadata_token" \
      http://169.254.169.254/v1/user-data || true)

    [ -n "$USER_DATA" ]
  }
  pc_retry 5 5 -- _pc_fetch_metadata || true
  if [ -z "$USER_DATA" ]; then
    echo "No owner configuration was delivered; refusing an unreachable deployment" >&2
    pc_status_error configuring_operating_system owner_config_undelivered
    exit 1
  fi
  install -m 600 /dev/null "$RUNTIME_ENV"
  printf '%s' "$USER_DATA" | base64 -d > "$RUNTIME_ENV"
fi

BOOT_ENV_SCHEMA=$(sed -n 's/^SCHEMA=//p' "$RUNTIME_ENV")
if [ "$BOOT_ENV_SCHEMA" != "1" ]; then
  echo "Invalid or missing boot-env SCHEMA (expected 1); refusing bootstrap" >&2
  pc_status_error configuring_operating_system boot_env_schema_invalid
  exit 1
fi
# root_ssh_key is deliberately NOT in this list: it's scrubbed from
# RUNTIME_ENV below once consumed (line ~96), so an unconditional
# requirement here would reject every retry after the first with a
# misleading boot_env_field_missing -- masking whatever the retry's real
# failure is. Its own idempotency-safe check (below) already requires it
# unless /root/.ssh/authorized_keys is already populated -- confirmed
# live: a bootstrap.service restart (systemd's Restart=on-failure, e.g.
# after a transient release-fetch failure) hit exactly this before the
# fix, on every attempt after the first.
for required_field in host_ssh_private_key host_ssh_public_key BOX_PRIVATE_KEY_PKCS8 \
  BOX_CREDENTIAL public_ip \
  POCKETCODER_RELEASE_CHANNEL POCKETCODER_RELEASE_DIGEST POCKETCODER_RELEASE_SEQUENCE \
  POCKETCODER_SELECTED_HARNESSES; do
  if ! grep -q "^${required_field}=\S" "$RUNTIME_ENV"; then
    echo "Required boot-env field is missing or empty: ${required_field}" >&2
    pc_status_error configuring_operating_system boot_env_field_missing
    exit 1
  fi
done

# A field can pass the presence check above yet still be corrupt (truncated
# in transit, wrong encoding, a mismatched key pair) -- and because
# hostKeys=[] means sshd has no fallback of its own, a bad host key written
# to disk here permanently bricks SSH on this box with no self-heal. So
# every SSH-relevant field is validated for well-formedness -- and the host
# keypair is cross-checked against itself -- before anything is written, and
# each failure gets its own errorCode so it's diagnosable from status.json
# even when SSH itself is what's unreachable.
ROOT_SSH_KEY=$(sed -n 's/^root_ssh_key=//p' "$RUNTIME_ENV")
if [ -z "$ROOT_SSH_KEY" ] && [ ! -s /root/.ssh/authorized_keys ]; then
  echo "No root SSH key was delivered; refusing an unreachable deployment" >&2
  pc_status_error configuring_operating_system ssh_key_undelivered
  exit 1
fi
if [ -n "$ROOT_SSH_KEY" ]; then
  case "$ROOT_SSH_KEY" in
    ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*\ *) ;;
    *)
      echo "root_ssh_key is not a recognized SSH public key" >&2
      pc_status_error configuring_operating_system boot_env_root_key_invalid
      exit 1
      ;;
  esac
fi

HOST_SSH_PRIVATE_KEY=$(sed -n 's/^host_ssh_private_key=//p' "$RUNTIME_ENV")
HOST_SSH_PUBLIC_KEY=$(sed -n 's/^host_ssh_public_key=//p' "$RUNTIME_ENV")
case "$HOST_SSH_PUBLIC_KEY" in
  ssh-ed25519\ *) ;;
  *)
    echo "host_ssh_public_key is not a recognized ssh-ed25519 public key" >&2
    pc_status_error configuring_operating_system boot_env_host_key_invalid
    exit 1
    ;;
esac
VALIDATE_DIR=$(mktemp -d /run/pc-hostkey-validate.XXXXXX)
trap 'rm -rf "$VALIDATE_DIR"' EXIT
chmod 700 "$VALIDATE_DIR"
if ! printf '%s' "$HOST_SSH_PRIVATE_KEY" | base64 -d > "$VALIDATE_DIR/key" 2>/dev/null \
  || ! grep -q '^-----BEGIN OPENSSH PRIVATE KEY-----$' "$VALIDATE_DIR/key"; then
  echo "host_ssh_private_key does not decode to an OpenSSH private key" >&2
  pc_status_error configuring_operating_system boot_env_host_key_invalid
  exit 1
fi
chmod 600 "$VALIDATE_DIR/key"
DERIVED_PUBLIC_KEY=$(ssh-keygen -y -f "$VALIDATE_DIR/key" 2>/dev/null || true)
if [ -z "$DERIVED_PUBLIC_KEY" ] \
  || [ "$(awk '{print $1, $2}' <<<"$DERIVED_PUBLIC_KEY")" != "$(awk '{print $1, $2}' <<<"$HOST_SSH_PUBLIC_KEY")" ]; then
  echo "host_ssh_private_key does not match host_ssh_public_key" >&2
  pc_status_error configuring_operating_system boot_env_host_key_mismatch
  exit 1
fi
rm -rf "$VALIDATE_DIR"
trap - EXIT

PUBLIC_IP=$(sed -n 's/^public_ip=//p' "$RUNTIME_ENV")
case "$PUBLIC_IP" in
  *[!0-9.]*)
    echo "public_ip is not a valid IPv4 address: $PUBLIC_IP" >&2
    pc_status_error configuring_operating_system boot_env_field_invalid
    exit 1
    ;;
esac

install -d -m 700 /root/.ssh
if [ -n "$ROOT_SSH_KEY" ]; then
  printf '%s\n' "$ROOT_SSH_KEY" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  sed -i '/^root_ssh_key=/d' "$RUNTIME_ENV"
fi

# The phone supplies the SSH host key as part of the root-of-trust blob.
# hostKeys=[] in configuration.nix prevents sshd-keygen from racing this.
install -d -m 0755 /etc/ssh
printf '%s' "$HOST_SSH_PRIVATE_KEY" | base64 -d > /etc/ssh/ssh_host_ed25519_key
printf '%s\n' "$HOST_SSH_PUBLIC_KEY" > /etc/ssh/ssh_host_ed25519_key.pub
chmod 600 /etc/ssh/ssh_host_ed25519_key
chmod 644 /etc/ssh/ssh_host_ed25519_key.pub
install -d -m 0755 /run/pocketcoder
printf '%s\n' "$(sed -n 's/^public_ip=//p' "$RUNTIME_ENV")" > /run/pocketcoder/public-ip
chmod 644 /run/pocketcoder/public-ip
# POCO:END bootstrap-owner-config

# POCO:BEGIN bootstrap-release-source
# The NixOS image is only the OS layer. First boot independently resolves the
# GitHub-attested release selected by the app, verifies the exact digest and sequence,
# and hands all platform-neutral work to the release snapshot.
pc_status_phase fetching_release
pc_status_heartbeat_start
RELEASE_BASE="${RELEASE_BASE:-https://images.relay.pocketcoder.org}"
RELEASE_CHANNEL=$(sed -n 's/^POCKETCODER_RELEASE_CHANNEL=//p' "$RUNTIME_ENV")
RELEASE_CHANNEL=${RELEASE_CHANNEL:-stable}
EXPECTED_DIGEST=$(sed -n 's/^POCKETCODER_RELEASE_DIGEST=//p' "$RUNTIME_ENV")
EXPECTED_SEQUENCE=$(sed -n 's/^POCKETCODER_RELEASE_SEQUENCE=//p' "$RUNTIME_ENV")
case "$RELEASE_CHANNEL" in stable | beta | nightly) ;; *)
  pc_status_error fetching_release release_channel_invalid
  exit 1
esac
case "$EXPECTED_DIGEST" in *[!0-9a-f]* | '')
  pc_status_error fetching_release release_digest_invalid
  exit 1
esac
if [ "${#EXPECTED_DIGEST}" -ne 64 ]; then
  pc_status_error fetching_release release_digest_invalid
  exit 1
fi
case "$EXPECTED_SEQUENCE" in *[!0-9]* | '' | 0)
  pc_status_error fetching_release release_sequence_invalid
  exit 1
esac

export RELEASE_BASE POCKETCODER_RELEASE_CHANNEL="$RELEASE_CHANNEL" \
  POCKETCODER_RELEASE_DIGEST="$EXPECTED_DIGEST" \
  POCKETCODER_RELEASE_SEQUENCE="$EXPECTED_SEQUENCE"
SELECTED_HARNESSES=$(sed -n 's/^POCKETCODER_SELECTED_HARNESSES=//p' "$RUNTIME_ENV")
SELECTED_HARNESSES="${SELECTED_HARNESSES:-goose}"
trap - ERR
export POCKETCODER_INITIALIZED_MARKER="$MARKER"
# A first-ever install has no previous release to fall back to, so an
# interruption mid-install (a live-migration reboot, an OOM kill -- routine
# cloud events, confirmed live: a Linode instance got SIGTERM'd mid-`docker
# compose up` here) permanently strands the box: the release manager's own
# recovery correctly cleans up the interrupted transaction, but still
# reports it as an error, and this service has no Restart= directive, so a
# single failed attempt would otherwise never be retried. Retry a few times
# before giving up for real.
install_ok=0
_pc_install_release() {
  RELEASE_BASE="$RELEASE_BASE" \
  POCKETCODER_RELEASE_CHANNEL="$RELEASE_CHANNEL" \
  POCKETCODER_RELEASE_DIGEST="$EXPECTED_DIGEST" \
  POCKETCODER_RELEASE_SEQUENCE="$EXPECTED_SEQUENCE" \
  POCKETCODER_SELECTED_HARNESSES="$SELECTED_HARNESSES" \
  POCKETCODER_RUNTIME_ENV="$RUNTIME_ENV" \
  POCKETCODER_STATUS_FILE="$PC_STATUS_FILE" \
  POCKETCODER_STATUS_RUN_ID="$PC_RUN_ID" \
    pocketcoder-release install
}
pc_status_heartbeat_stop
pc_retry 3 5 -- _pc_install_release && install_ok=1
if [ "$install_ok" != 1 ]; then
  last_operation=$(pc_status_last_operation)
  pc_debug_dump "release install failed after retries"
  pc_status_error "${last_operation:-fetching_release}" release_install_failed
  exit 1
fi
# POCO:END bootstrap-release-source

date -u +%Y-%m-%dT%H:%M:%SZ > "$MARKER"
# The release-manager's own status writes (loading_images, etc.) already
# report the real resolved commit via its in-process Reporter. This
# script's own status writes go through status.sh's _pc_status_write
# instead, which has no way to see that in-process value -- so read back
# the same current.json the release-manager just wrote (it always
# succeeds before this line is ever reached, since a failed install exits
# above) rather than leaving this final, most-likely-to-be-checked status
# permanently reporting "unknown".
PC_SOURCE_COMMIT=$(jq -r '.sourceCommit // empty' "$RELEASE_STATE/current.json" 2>/dev/null || true)
export PC_SOURCE_COMMIT
pc_status_phase bootstrap_complete

trap - EXIT
echo "PocketCoder bootstrap complete"
