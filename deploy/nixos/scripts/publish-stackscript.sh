#!/bin/sh
# Publishes/updates the pocketcoder-image-installer StackScript from
# deploy/nixos/stackscripts/pocketcoder-image-installer.sh. Run once to
# create it (prints the new numeric id -- update
# LinodeAPIClient._bootTimePullStackscriptId with it), and again any time
# the StackScript's content changes (updates in place, same id). Reads
# LINODE_STACKSCRIPT_TOKEN from the environment (injected by the
# secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed) -- a token scoped to StackScripts/Linodes/Images
# read-write, separate from the broader LINODE_TOKEN this vault file
# also carries.
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/stackscripts/pocketcoder-image-installer.sh"
SCRIPT_BODY=$(cat "$SCRIPT_PATH")
AUTH="Authorization: Bearer $LINODE_STACKSCRIPT_TOKEN"

# Fail closed rather than silently publishing an empty/truncated script --
# live-confirmed 2026-08-27: a box booted the real installer disk with a
# genuinely empty StackScript payload (Linode's own metadata delivered a
# valid MIME envelope with a zero-byte part-001), and nothing anywhere
# caught it before or after publish. 500 bytes is well under the real
# script's size (~6KB) but well above any truncation/empty-read accident.
SCRIPT_BYTES=$(wc -c < "$SCRIPT_PATH")
if [ "$SCRIPT_BYTES" -lt 500 ]; then
  echo "FATAL: $SCRIPT_PATH is only $SCRIPT_BYTES bytes -- refusing to publish an empty/truncated StackScript" >&2
  exit 1
fi
case "$SCRIPT_BODY" in
  '#!'*) ;;
  *) echo "FATAL: $SCRIPT_PATH does not start with a shebang -- refusing to publish" >&2; exit 1 ;;
esac

# Server-side filter (not client-side page scan): without this, the
# unfiltered first page of a potentially-huge public StackScript listing
# will essentially never contain our one script, so every run would
# create a new StackScript instead of updating the existing one in place.
EXISTING_ID=$(curl -sf --show-error -H "$AUTH" \
  -H 'X-Filter: {"mine": true, "label": "pocketcoder-image-installer"}' \
  "https://api.linode.com/v4/linode/stackscripts?page_size=100" \
  | python3 -c "
import json, sys
data = json.load(sys.stdin)['data']
matches = [s for s in data if s.get('label') == 'pocketcoder-image-installer']
if len(matches) > 1:
    sys.exit('FATAL: multiple StackScripts match label pocketcoder-image-installer '
              '(ids: ' + ', '.join(str(m['id']) for m in matches) + ') -- '
              'this should never happen; investigate before proceeding.')
print(matches[0]['id'] if matches else '')
")

BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'label': 'pocketcoder-image-installer',
    'description': 'Pulls the PocketCoder NixOS image from R2 onto a raw target disk (boot-time-pull provisioning)',
    # debian13, not debian12: see installer_disk_operations.dart's own
    # comment on the CreateInstallerDiskOperation 'image' field --
    # debian12's cloud-init (22.4.2) is below Akamai's documented minimum
    # (23.3.1) for their metadata-service datasource, live-confirmed
    # 2026-08-27 to deliver StackScript user-data as empty.
    'images': ['linode/debian13'],
    # Deliberately public: this StackScript is published once, centrally,
    # from our own Linode account, but is REFERENCED at deploy time by
    # each end user's own Linode token/instance-create call -- a private
    # StackScript is only visible to the owning account, so it would be
    # unusable by any real end-user deployment. Also permanent: Linode
    # public StackScripts cannot be made private or deleted once published.
    'is_public': True,
    'script': sys.argv[1],
}))
" "$SCRIPT_BODY")

if [ -n "$EXISTING_ID" ]; then
  echo "Updating existing StackScript $EXISTING_ID"
  RESULT=$(curl -sf --show-error -X PUT -H "$AUTH" -H "Content-Type: application/json" \
    "https://api.linode.com/v4/linode/stackscripts/$EXISTING_ID" \
    -d "$BODY")
  PUBLISHED_ID="$EXISTING_ID"
else
  echo "Creating new StackScript"
  RESULT=$(curl -sf --show-error -X POST -H "$AUTH" -H "Content-Type: application/json" \
    "https://api.linode.com/v4/linode/stackscripts" \
    -d "$BODY")
  PUBLISHED_ID=$(printf '%s' "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
fi
printf '%s' "$RESULT" | python3 -m json.tool

# Read back what Linode actually stored -- the create/update response
# already echoes the object, but reading it back via a fresh GET confirms
# what other callers (i.e. the next real boot) will actually receive,
# not just what this same request round-tripped.
LIVE_SCRIPT=$(curl -sf --show-error -H "$AUTH" \
  "https://api.linode.com/v4/linode/stackscripts/$PUBLISHED_ID" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["script"], end="")')
if [ "$LIVE_SCRIPT" != "$SCRIPT_BODY" ]; then
  echo "FATAL: live StackScript $PUBLISHED_ID content does not match $SCRIPT_PATH after publish -- Linode may have stored something else" >&2
  exit 1
fi
echo "Verified: live StackScript $PUBLISHED_ID matches $SCRIPT_PATH ($SCRIPT_BYTES bytes)"
