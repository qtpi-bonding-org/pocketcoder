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
SCRIPT_BODY=$(cat "$SCRIPT_DIR/stackscripts/pocketcoder-image-installer.sh")
AUTH="Authorization: Bearer $LINODE_STACKSCRIPT_TOKEN"

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
    'images': ['linode/debian12'],
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
  curl -sf --show-error -X PUT -H "$AUTH" -H "Content-Type: application/json" \
    "https://api.linode.com/v4/linode/stackscripts/$EXISTING_ID" \
    -d "$BODY" | python3 -m json.tool
else
  echo "Creating new StackScript"
  curl -sf --show-error -X POST -H "$AUTH" -H "Content-Type: application/json" \
    "https://api.linode.com/v4/linode/stackscripts" \
    -d "$BODY" | python3 -m json.tool
fi
