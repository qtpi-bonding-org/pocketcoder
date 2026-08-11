#!/usr/bin/env bash
set -euo pipefail

: "${POCKETCODER_REF:?NixOS image release reference is required}"
RELEASES_DIR=/opt/pocketcoder/releases
RELEASE_STATE=/var/lib/pocketcoder/release
ARTIFACT_DIR=/var/lib/pocketcoder/artifacts
RUNTIME_ENV=/var/lib/pocketcoder/config/runtime.env
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

# POCO:BEGIN bootstrap-owner-config
# NixOS accepts owner configuration from the one-shot file written by the
# image installer. The legacy custom-image route still uses Linode metadata,
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

# POCO:IMPORTANT:BEGIN
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
# POCO:IMPORTANT:END
# POCO:END bootstrap-owner-config

# POCO:BEGIN bootstrap-release-source
# The NixOS image is only the host layer. First boot resolves the coupled
# application release, verifies its deployment snapshot, and hands all
# platform-neutral work to activate-release.sh from that snapshot.
pc_status_phase fetching_release
pc_status_heartbeat_start
RELEASE_BASE="${RELEASE_BASE:-https://images.pocketcoder.org}"
if [ "$POCKETCODER_REF" = main ]; then
  DISCOVERY_URL="$RELEASE_BASE/release-manifest.json"
else
  DISCOVERY_URL="$RELEASE_BASE/release-$POCKETCODER_REF.json"
fi
MANIFEST_CANDIDATE="$ARTIFACT_DIR/release-manifest.$$.json"
curl -sfL --max-time 30 -o "$MANIFEST_CANDIDATE" "$DISCOVERY_URL"
RESOLVED_COMMIT=$(jq -r '.release // empty' "$MANIFEST_CANDIDATE")
case "$RESOLVED_COMMIT" in
  *[!0-9a-f]* | '')
    pc_status_error fetching_release release_manifest_identity_invalid
    exit 1
    ;;
esac
if [ "${#RESOLVED_COMMIT}" -ne 40 ]; then
  pc_status_error fetching_release release_manifest_identity_invalid
  exit 1
fi
if [ "$POCKETCODER_REF" != main ] && [ "$POCKETCODER_REF" != "$RESOLVED_COMMIT" ]; then
  pc_status_error fetching_release release_manifest_identity_mismatch
  exit 1
fi
export PC_SOURCE_COMMIT="$RESOLVED_COMMIT"
IMMUTABLE_URL="$RELEASE_BASE/release-$RESOLVED_COMMIT.json"
if [ "$DISCOVERY_URL" != "$IMMUTABLE_URL" ]; then
  curl -sfL --max-time 30 -o "$MANIFEST_CANDIDATE" "$IMMUTABLE_URL"
  test "$(jq -r '.release // empty' "$MANIFEST_CANDIDATE")" = "$RESOLVED_COMMIT"
fi

DEPLOYMENT_URL=$(jq -r '.deployment.url // empty' "$MANIFEST_CANDIDATE")
DEPLOYMENT_SHA256=$(jq -r '.deployment.sha256 // empty' "$MANIFEST_CANDIDATE")
DEPLOYMENT_BYTES=$(jq -r '.deployment.bytes // empty' "$MANIFEST_CANDIDATE")
DEPLOYMENT_EXPANDED=$(jq -r '.deployment.expandedBytes // empty' "$MANIFEST_CANDIDATE")
DEPLOYMENT_FILE="$ARTIFACT_DIR/$RESOLVED_COMMIT-deployment.tar.gz.part.$$"
REQUIRED_BLOCKS=$(((DEPLOYMENT_BYTES + DEPLOYMENT_EXPANDED + 1073741824 + 1023) / 1024))
AVAILABLE_BLOCKS=$(df -Pk "$ARTIFACT_DIR" | awk 'NR == 2 {print $4}')
if [ -z "$AVAILABLE_BLOCKS" ] || [ "$AVAILABLE_BLOCKS" -lt "$REQUIRED_BLOCKS" ]; then
  pc_status_error fetching_release release_artifact_disk_headroom_insufficient
  exit 1
fi
# POCO:IMPORTANT:BEGIN
pc_status_phase fetching_release downloading:deployment
curl -fL --retry 3 --retry-delay 2 --max-time 1200 \
  -o "$DEPLOYMENT_FILE" "$DEPLOYMENT_URL"
test "$(wc -c < "$DEPLOYMENT_FILE" | tr -d ' ')" -eq "$DEPLOYMENT_BYTES"
test "$(sha256sum "$DEPLOYMENT_FILE" | cut -d' ' -f1)" = "$DEPLOYMENT_SHA256"
if tar -tzf "$DEPLOYMENT_FILE" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  pc_status_error fetching_release deployment_artifact_path_invalid
  exit 1
fi
# POCO:IMPORTANT:END

RELEASE_DIR="$RELEASES_DIR/$RESOLVED_COMMIT"
RELEASE_STAGE="$RELEASE_DIR.stage.$$"
cleanup_release_stage() {
  if [ -n "${RELEASE_STAGE:-}" ] && [ -d "$RELEASE_STAGE" ]; then
    rm -rf "$RELEASE_STAGE"
  fi
}
trap cleanup_release_stage EXIT
if [ ! -d "$RELEASE_DIR" ]; then
  install -d -m 0755 "$RELEASE_STAGE"
  tar -xzf "$DEPLOYMENT_FILE" -C "$RELEASE_STAGE"
  test "$(jq -r '.release // empty' "$RELEASE_STAGE/release.json")" = "$RESOLVED_COMMIT"
  mv "$RELEASE_STAGE" "$RELEASE_DIR"
  RELEASE_STAGE=
fi
rm -f "$DEPLOYMENT_FILE"
pc_status_heartbeat_stop
# POCO:END bootstrap-release-source

SELECTED_HARNESSES=$(sed -n 's/^POCKETCODER_SELECTED_HARNESSES=//p' "$RUNTIME_ENV")
SELECTED_HARNESSES="${SELECTED_HARNESSES:-goose}"
read -r -a SELECTED_HARNESS_ARGS <<< "${SELECTED_HARNESSES//,/ }"
trap - ERR
export POCKETCODER_INITIALIZED_MARKER="$MARKER"
"$RELEASE_DIR/deploy/scripts/activate-release.sh" \
  "$MANIFEST_CANDIDATE" "$IMMUTABLE_URL" "$RUNTIME_ENV" \
  "$RELEASE_STATE" "$ARTIFACT_DIR" "$PC_RUN_ID" "$PC_STATUS_FILE" \
  "${SELECTED_HARNESS_ARGS[@]}"

trap - EXIT
echo "PocketCoder bootstrap complete"
