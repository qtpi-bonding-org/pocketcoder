#!/bin/sh
# Verifies that Linode's metadata service actually DELIVERS
# metadata.user_data at boot (not just accepts it at instance-create
# time) -- the single highest-value unverified assumption in the
# boot-time-pull design (see docs/superpowers/specs/
# 2026-07-29-linode-boot-time-image-provisioning-design.md,
# "Pre-implementation verification"). LinodeBootTimeInstaller's whole
# approach depends on this: the installer StackScript reads its
# IMAGE_URL/IMAGE_SHA256/IMAGE_UNCOMPRESSED_BYTES from UDFs (StackScript
# data), not from metadata.user_data -- but the *final* NixOS boot
# (bootstrap.nix) reads the real admin config from metadata.user_data,
# so if the metadata service doesn't actually deliver it at boot, every
# real deployment fails closed with no admin config, silently.
#
# Creates a real (but tiny, immediately deleted) Linode instance with a
# throwaway, runtime-generated SSH keypair (never vault-stored -- it's
# disposable, scoped to this one test instance), a known test payload in
# metadata.user_data, SSHes in once to query the metadata service
# directly, and reports exactly what came back. Reads LINODE_TOKEN from
# the environment (injected by the secrets-daemon via `sops exec-env` --
# never read from a file here, never echoed).
set -eu

AUTH="Authorization: Bearer $LINODE_TOKEN"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

TEST_PAYLOAD="PROBE_$(date +%s)"
TEST_PAYLOAD_B64=$(printf '%s' "$TEST_PAYLOAD" | base64)

echo "Generating a throwaway SSH keypair (test-instance-scoped only)..."
ssh-keygen -t ed25519 -N '' -f "$WORKDIR/id_ed25519" -q
PUBKEY=$(cat "$WORKDIR/id_ed25519.pub")

echo "Creating test instance (linode/debian12, authorized_keys + metadata.user_data)..."
RESPONSE=$(curl -sf -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "https://api.linode.com/v4/linode/instances" \
  -d "{
    \"type\": \"g6-nanode-1\",
    \"region\": \"us-east\",
    \"image\": \"linode/debian12\",
    \"label\": \"pocketcoder-metadata-verify\",
    \"booted\": true,
    \"authorized_keys\": [\"$PUBKEY\"],
    \"metadata\": {\"user_data\": \"$TEST_PAYLOAD_B64\"}
  }")

# Install the cleanup trap immediately after the create call succeeds --
# BEFORE attempting to parse its response. If the strict json parse below
# fails for any reason (unexpected response shape), set -e would exit the
# script; without the trap already installed and an id already captured
# at that point, the just-created instance would leak as an orphaned,
# billable resource with no id recorded anywhere. Extract the id with a
# best-effort grep first (unlikely to fail even on odd response shapes)
# so cleanup has something to work with regardless of what the strict
# parse below does.
INSTANCE_ID=$(printf '%s' "$RESPONSE" | grep -o '"id":[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$' || true)

cleanup_instance() {
  if [ -n "$INSTANCE_ID" ]; then
    echo "Deleting test instance $INSTANCE_ID..."
    curl -sf -X DELETE -H "$AUTH" "https://api.linode.com/v4/linode/instances/$INSTANCE_ID" || true
  else
    echo "WARNING: no instance id was ever captured -- cannot auto-cleanup." >&2
    echo "Raw instance-create response, for manual cleanup: $RESPONSE" >&2
  fi
}
trap 'cleanup_instance; rm -rf "$WORKDIR"' EXIT

# Strict parse for the id we actually use for the rest of the script (IP
# lookup, polling, etc). By this point cleanup is already guaranteed even
# if this fails.
INSTANCE_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "Instance created: $INSTANCE_ID"

echo "Waiting for instance to reach 'running' status..."
attempt=0
until [ "$attempt" -ge 40 ]; do
  attempt=$((attempt + 1))
  STATUS=$(curl -sf -H "$AUTH" "https://api.linode.com/v4/linode/instances/$INSTANCE_ID" \
    | python3 -c "import json,sys; print(json.load(sys.stdin)['status'])")
  [ "$STATUS" = "running" ] && break
  sleep 5
done
[ "$STATUS" = "running" ] || { echo "FATAL: instance never reached running (last status: $STATUS)"; exit 1; }

IP=$(curl -sf -H "$AUTH" "https://api.linode.com/v4/linode/instances/$INSTANCE_ID" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['ipv4'][0])")
echo "Instance IP: $IP -- waiting for SSH..."

attempt=0
until [ "$attempt" -ge 30 ]; do
  attempt=$((attempt + 1))
  ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
    -i "$WORKDIR/id_ed25519" "root@$IP" true 2>/dev/null && break
  sleep 5
done

echo "Querying the metadata service from inside the instance..."
RESULT=$(ssh -o StrictHostKeyChecking=no -i "$WORKDIR/id_ed25519" "root@$IP" '
  TOKEN=$(curl -s -X PUT -H "Metadata-Token-Expiry-Seconds: 60" http://169.254.169.254/v1/token)
  curl -s -H "Metadata-Token: $TOKEN" http://169.254.169.254/v1/user-data
')

echo "Raw response from /v1/user-data: $RESULT"

# Compare $RESULT directly against both known forms of the payload --
# no decode-and-compare step. `base64 -d` is NOT reliable here as a
# "was this already decoded" probe: on this machine's (BSD/macOS)
# base64, `-d` SUCCEEDS (exit 0) on non-base64 plaintext input too,
# emitting garbage instead of failing, which would silently invert the
# verdict below (a real, working "already decoded" delivery would
# wrongly report as NOT confirmed). We already have both the raw and
# base64-encoded forms of the known payload computed above, so just
# compare against each directly.
if [ "$RESULT" = "$TEST_PAYLOAD_B64" ]; then
  echo "MATCH (still base64-encoded): metadata service delivers user_data as base64, undecoded."
elif [ "$RESULT" = "$TEST_PAYLOAD" ]; then
  echo "MATCH (already decoded): metadata service delivers user_data already base64-decoded."
else
  echo "FATAL: response does not match expected payload ('$TEST_PAYLOAD' / '$TEST_PAYLOAD_B64')."
  echo "Metadata delivery is NOT confirmed -- do not rely on metadata.user_data without further investigation."
  exit 1
fi
