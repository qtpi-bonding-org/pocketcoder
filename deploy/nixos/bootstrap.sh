#!/usr/bin/env bash
set -euo pipefail

: "${POCKETCODER_REF:?NixOS image release reference is required}"
RELEASES_DIR=/opt/pocketcoder/releases
RELEASE_STATE=/var/lib/pocketcoder/release
ARTIFACT_DIR=/var/lib/pocketcoder/artifacts
RUNTIME_ENV=/var/lib/pocketcoder/config/runtime.env
PHASE_LOG=/var/log/pocketcoder-bootstrap-phases.log
MARKER="$RELEASE_STATE/.initialized"
export PC_SOURCE_COMMIT="$POCKETCODER_REF"

if [ -f "$MARKER" ]; then
  echo "PocketCoder already initialized, skipping bootstrap"
  exit 0
fi

source /etc/pocketcoder/status.sh
trap 'pc_status_error "$PC_CURRENT_PHASE" "step failed at line ${BASH_LINENO[0]}"' ERR
pc_status_init
umask 077
install -d -m 0755 "$RELEASES_DIR" "$RELEASE_STATE/manifests"
install -d -m 0700 "$ARTIFACT_DIR" /var/lib/pocketcoder/config
touch "$PHASE_LOG"
chmod 0644 "$PHASE_LOG"

# POCO:BEGIN bootstrap-owner-config
# NixOS accepts owner configuration from the one-shot file written by the
# image installer. A compatibility fallback can still read Linode metadata,
# and an interrupted boot resumes from the protected environment file.
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
  for attempt in 1 2 3 4 5; do
    TOKEN=$(curl -sf --max-time 5 -X PUT \
      -H 'Metadata-Token-Expiry-Seconds: 300' \
      http://169.254.169.254/v1/token || true)
    if [ -n "$TOKEN" ]; then
      USER_DATA=$(curl -sf --max-time 10 \
        -H "Metadata-Token: $TOKEN" \
        http://169.254.169.254/v1/user-data || true)
    fi
    [ -n "$USER_DATA" ] && break
    echo "Attempt $attempt: metadata unavailable; retrying in 5s"
    sleep 5
  done
  if [ -z "$USER_DATA" ]; then
    echo "No owner configuration was delivered; refusing an unreachable deployment" >&2
    exit 1
  fi
  install -m 600 /dev/null "$RUNTIME_ENV"
  printf '%s' "$USER_DATA" | base64 -d > "$RUNTIME_ENV"
fi

ROOT_SSH_KEY=$(sed -n 's/^root_ssh_key=//p' "$RUNTIME_ENV")
if [ -z "$ROOT_SSH_KEY" ] && [ ! -s /root/.ssh/authorized_keys ]; then
  echo "No root SSH key was delivered; refusing an unreachable deployment" >&2
  exit 1
fi
install -d -m 700 /root/.ssh
if [ -n "$ROOT_SSH_KEY" ]; then
  printf '%s\n' "$ROOT_SSH_KEY" > /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
  sed -i '/^root_ssh_key=/d' "$RUNTIME_ENV"
fi
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
RELEASE_BASE="$RELEASE_BASE" \
POCKETCODER_RELEASE_CHANNEL="$RELEASE_CHANNEL" \
POCKETCODER_RELEASE_DIGEST="$EXPECTED_DIGEST" \
POCKETCODER_RELEASE_SEQUENCE="$EXPECTED_SEQUENCE" \
POCKETCODER_SELECTED_HARNESSES="$SELECTED_HARNESSES" \
POCKETCODER_RUNTIME_ENV="$RUNTIME_ENV" \
POCKETCODER_STATUS_FILE="$PC_STATUS_FILE" \
POCKETCODER_STATUS_RUN_ID="$PC_RUN_ID" \
  pocketcoder-release install
pc_status_heartbeat_stop
# POCO:END bootstrap-release-source

date -u +%Y-%m-%dT%H:%M:%SZ > "$MARKER"
pc_status_phase bootstrap_complete

trap - EXIT
echo "PocketCoder bootstrap complete"
