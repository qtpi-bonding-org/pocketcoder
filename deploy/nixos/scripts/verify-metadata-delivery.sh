#!/bin/sh
# Verifies that Linode's metadata service actually DELIVERS
# metadata.user_data at boot (not just accepts it at instance-create
# time) -- the single highest-value unverified assumption in the
# boot-time-pull design. LinodeBootTimeInstaller's whole
# approach depends on this: the installer StackScript reads its
# IMAGE_URL/IMAGE_SHA256/IMAGE_UNCOMPRESSED_BYTES from UDFs (StackScript
# data), not from metadata.user_data -- but the *final* NixOS boot
# (bootstrap.nix) reads the real admin config from metadata.user_data,
# so if the metadata service doesn't actually deliver it at boot, every
# real deployment fails closed with no admin config, silently.
#
# Also answers the design spec's second open question: does
# metadata.user_data still get delivered correctly when the SAME
# instance's disk was created WITH a StackScript attached (Linode's docs
# position Metadata and StackScripts as alternatives and are silent on
# using both together)? This mirrors LinodeBootTimeInstaller's REAL
# attachment point exactly -- a bare instance (booted:false,
# metadata.user_data only, no image) followed by a SEPARATE disk-create
# call carrying image + stackscript_id + stackscript_data, not a single
# instance-create call with everything on it.
#
# CONFIRMED (2026-07-30, three live runs): the StackScript does NOT run
# when metadata.user_data is also present on the instance -- at BOTH the
# instance-create attachment point and this (real) disk-create attachment
# point. A fourth, isolating run with metadata.user_data omitted entirely
# (same disk-create StackScript attachment, nothing else changed) had the
# StackScript run successfully. This is a real, load-bearing conflict
# between the two mechanisms, not test flakiness or the wrong attachment
# point -- LinodeBootTimeInstaller's current design (metadata.user_data on
# the instance + stackscript_id on the installer disk, simultaneously)
# does not work as built. See the SDD ledger / conversation history for
# the investigation; this needs a design decision before Task 10's
# approach can ship, not a further script tweak.
#
# Unlike production (which deliberately omits authorized_keys on the
# installer disk -- see LinodeBootTimeInstaller's D3 mitigation), this
# diagnostic script DOES add a throwaway authorized_keys to the
# disk-create call, purely so this script itself can SSH in to inspect
# the result. That's a script-only deviation for observability, not a
# claim about what production does -- production's installer disk really
# has no SSH access, by design.
#
# Creates real (but tiny, immediately deleted) Linode resources: a
# throwaway, runtime-generated SSH keypair (never vault-stored -- it's
# disposable, scoped to this one test run), a throwaway no-op
# StackScript, a bare instance, and a disk with that StackScript
# attached. SSHes in once to query the metadata service and check for
# the StackScript's marker file, and reports both results independently
# (one question's outcome never suppresses the other's). Reads
# LINODE_STACKSCRIPT_TOKEN from the environment (injected by the
# secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed) -- needs Linodes + StackScripts read-write, same token
# publish-stackscript.sh uses.
set -eu

AUTH="Authorization: Bearer $LINODE_STACKSCRIPT_TOKEN"
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

TEST_PAYLOAD="PROBE_$(date +%s)"
TEST_PAYLOAD_B64=$(printf '%s' "$TEST_PAYLOAD" | base64)

echo "Generating a throwaway SSH keypair (test-instance-scoped only)..."
ssh-keygen -t ed25519 -N '' -f "$WORKDIR/id_ed25519" -q
PUBKEY=$(cat "$WORKDIR/id_ed25519.pub")

# Linode's API requires root_pass whenever `image` is provided on a
# disk-create call -- authorized_keys alone isn't sufficient. Throwaway,
# never actually used for login (we log in via the SSH key above).
ROOT_PASS=$(openssl rand -base64 24)

NOOP_STACKSCRIPT="#!/bin/bash
# <UDF name=\"noop_var\" label=\"unused test UDF\" default=\"unused\">
touch /root/stackscript-ran
"
echo "Creating throwaway no-op StackScript (coexistence probe)..."
SS_BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'label': 'pocketcoder-metadata-verify-noop-' + sys.argv[1],
    'images': ['linode/debian12'],
    'is_public': False,
    'script': sys.argv[2],
}))
" "$(date +%s)" "$NOOP_STACKSCRIPT")
SS_RESPONSE=$(curl -sf --show-error -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "https://api.linode.com/v4/linode/stackscripts" -d "$SS_BODY")
STACKSCRIPT_ID=$(printf '%s' "$SS_RESPONSE" | grep -o '"id":[[:space:]]*[0-9]*' | head -1 | grep -o '[0-9]*$' || true)

cleanup_stackscript() {
  if [ -n "$STACKSCRIPT_ID" ]; then
    echo "Deleting throwaway StackScript $STACKSCRIPT_ID..."
    curl -sf -X DELETE -H "$AUTH" "https://api.linode.com/v4/linode/stackscripts/$STACKSCRIPT_ID" || true
  else
    echo "WARNING: no StackScript id was ever captured -- cannot auto-cleanup." >&2
    echo "Raw StackScript-create response, for manual cleanup: $SS_RESPONSE" >&2
  fi
}
trap 'cleanup_stackscript; rm -rf "$WORKDIR"' EXIT

# Step 1: bare instance -- exactly LinodeBootTimeInstaller's own step 1
# (booted:false, metadata.user_data only, no image, no authorized_keys).
echo "Creating bare test instance (metadata.user_data only, no image)..."
RESPONSE=$(curl -sf --show-error -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "https://api.linode.com/v4/linode/instances" \
  -d "{
    \"type\": \"g6-nanode-1\",
    \"region\": \"us-east\",
    \"label\": \"pocketcoder-metadata-verify\",
    \"booted\": false,
    \"metadata\": {\"user_data\": \"$TEST_PAYLOAD_B64\"}
  }")

# Cleanup trap installed immediately after the create call succeeds,
# before attempting to parse its response -- see the instance/StackScript
# id-extraction comments below for why (a parse failure under set -eu
# must not leak a just-created, real, billable resource with no id
# recorded anywhere).
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
trap 'cleanup_instance; cleanup_stackscript; rm -rf "$WORKDIR"' EXIT

INSTANCE_ID=$(echo "$RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
echo "Instance created: $INSTANCE_ID"

# Step 2: disk, created FROM the instance with image + stackscript_id +
# stackscript_data attached -- the same attachment point
# LinodeBootTimeInstaller's real installer disk uses. authorized_keys is
# added here (diagnostic-only, see header) so this script can SSH in.
echo "Creating disk (image + StackScript + authorized_keys)..."
# Linode routinely 400s a disk-create with "Linode busy." for a few
# seconds right after instance-create while it settles -- the exact
# same transient error LinodeBootTimeInstaller's own _busyRetry handles
# in production. Bounded retry here, matching that behavior.
DISK_ID=""
busy_attempt=0
while [ -z "$DISK_ID" ]; do
  busy_attempt=$((busy_attempt + 1))
  # No -f: -f discards the response body on a non-2xx status, which is
  # exactly the diagnostic information needed to tell a real 400 apart
  # from a retryable "busy" one. Status is checked explicitly below.
  DISK_HTTP_RESPONSE=$(curl -s -w '\n%{http_code}' -X POST -H "$AUTH" -H "Content-Type: application/json" \
    "https://api.linode.com/v4/linode/instances/$INSTANCE_ID/disks" \
    -d "{
      \"label\": \"verify\",
      \"size\": 3072,
      \"image\": \"linode/debian12\",
      \"root_pass\": \"$ROOT_PASS\",
      \"authorized_keys\": [\"$PUBKEY\"],
      \"stackscript_id\": $STACKSCRIPT_ID,
      \"stackscript_data\": {\"noop_var\": \"unused\"}
    }")
  DISK_HTTP_STATUS=$(printf '%s' "$DISK_HTTP_RESPONSE" | tail -1)
  DISK_RESPONSE=$(printf '%s' "$DISK_HTTP_RESPONSE" | sed '$d')
  if [ "$DISK_HTTP_STATUS" -ge 200 ] && [ "$DISK_HTTP_STATUS" -lt 300 ]; then
    DISK_ID=$(echo "$DISK_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
  elif [ "$DISK_HTTP_STATUS" -eq 400 ] && printf '%s' "$DISK_RESPONSE" | grep -qi busy; then
    if [ "$busy_attempt" -ge 10 ]; then
      echo "FATAL: disk-create still busy after $busy_attempt attempts: $DISK_RESPONSE"
      exit 1
    fi
    echo "Linode busy, retrying disk-create (attempt $busy_attempt)..."
    sleep 3
  else
    echo "FATAL: disk-create returned HTTP $DISK_HTTP_STATUS: $DISK_RESPONSE"
    exit 1
  fi
done
echo "Disk created: $DISK_ID -- waiting for it to become ready..."

attempt=0
until [ "$attempt" -ge 40 ]; do
  attempt=$((attempt + 1))
  # `|| true` on both the curl and the python3 parse: under set -eu, a
  # single transient failure (rate limit, momentary 5xx) inside a
  # command-substitution assignment aborts the WHOLE script immediately,
  # not just this poll attempt -- there is no actual retry without this,
  # despite the surrounding until-loop. A failed poll just means "not
  # ready yet, try again," same as a non-matching status.
  DISK_STATUS=$( (curl -sf -H "$AUTH" \
    "https://api.linode.com/v4/linode/instances/$INSTANCE_ID/disks/$DISK_ID" \
    || true) | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || true)
  [ "$DISK_STATUS" = "ready" ] && break
  sleep 5
done
[ "$DISK_STATUS" = "ready" ] || { echo "FATAL: disk never reached ready (last status: $DISK_STATUS)"; exit 1; }

# Step 3: config profile + boot.
echo "Creating config profile and booting..."
CONFIG_RESPONSE=$(curl -sf --show-error -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "https://api.linode.com/v4/linode/instances/$INSTANCE_ID/configs" \
  -d "{
    \"label\": \"verify\",
    \"kernel\": \"linode/grub2\",
    \"root_device\": \"/dev/sda\",
    \"devices\": {\"sda\": {\"disk_id\": $DISK_ID}}
  }")
CONFIG_ID=$(echo "$CONFIG_RESPONSE" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
curl -sf --show-error -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "https://api.linode.com/v4/linode/instances/$INSTANCE_ID/boot" \
  -d "{\"config_id\": $CONFIG_ID}" >/dev/null

echo "Waiting for instance to reach 'running' status..."
attempt=0
until [ "$attempt" -ge 40 ]; do
  attempt=$((attempt + 1))
  # Same defensive pattern as the disk-status poll above: a transient
  # failure must not abort the whole script under set -eu.
  STATUS=$( (curl -sf -H "$AUTH" "https://api.linode.com/v4/linode/instances/$INSTANCE_ID" \
    || true) | python3 -c "import json,sys; print(json.load(sys.stdin).get('status',''))" 2>/dev/null || true)
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
  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o BatchMode=yes \
    -i "$WORKDIR/id_ed25519" "root@$IP" true 2>/dev/null && break
  sleep 5
done

echo "Querying the metadata service from inside the instance..."
RESULT=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$WORKDIR/id_ed25519" "root@$IP" '
  TOKEN=$(curl -s -X PUT -H "Metadata-Token-Expiry-Seconds: 60" http://169.254.169.254/v1/token)
  curl -s -H "Metadata-Token: $TOKEN" http://169.254.169.254/v1/user-data
')
echo "Raw response from /v1/user-data: $RESULT"

STACKSCRIPT_RAN=false
if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$WORKDIR/id_ed25519" "root@$IP" '[ -f /root/stackscript-ran ]'; then
  STACKSCRIPT_RAN=true
fi

# Diagnostic evidence either way: Linode's own community forum shows
# StackScripts sometimes execute but fail silently, logged here rather
# than just leaving no marker file. Dumped unconditionally so a false
# STACKSCRIPT_RAN=false (marker never written because the script errored
# out before reaching `touch`) is distinguishable from the StackScript
# never having started at all.
echo "--- /var/log/stackscript.log (if any) ---"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$WORKDIR/id_ed25519" "root@$IP" \
  'cat /var/log/stackscript.log 2>/dev/null || echo "(no such file)"'
echo "--- end stackscript.log ---"

# Both questions are evaluated and reported independently -- neither's
# outcome gates or suppresses the other's message. The overall exit code
# only reflects the metadata-delivery question (the actual production
# blocker); StackScript coexistence is reported as informational, since
# LinodeBootTimeInstaller's own design (D3) never depends on SSH access
# to the installer disk the way this diagnostic script does.
METADATA_CONFIRMED=false
if [ "$RESULT" = "$TEST_PAYLOAD_B64" ]; then
  echo "MATCH (still base64-encoded): metadata service delivers user_data as base64, undecoded."
  METADATA_CONFIRMED=true
elif [ "$RESULT" = "$TEST_PAYLOAD" ]; then
  echo "MATCH (already decoded): metadata service delivers user_data already base64-decoded."
  METADATA_CONFIRMED=true
else
  echo "FATAL: response does not match expected payload ('$TEST_PAYLOAD' / '$TEST_PAYLOAD_B64')."
  echo "Metadata delivery is NOT confirmed -- do not rely on metadata.user_data without further investigation."
fi

if [ "$STACKSCRIPT_RAN" = true ]; then
  echo "CONFIRMED: StackScript (disk-create-time attachment) ran alongside metadata.user_data (no coexistence conflict observed)."
else
  echo "NOT CONFIRMED: /root/stackscript-ran marker not found -- the disk-create-time StackScript did not run alongside metadata.user_data."
fi

[ "$METADATA_CONFIRMED" = true ] || exit 1
