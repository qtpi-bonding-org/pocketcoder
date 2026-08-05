#!/bin/sh
# One-shot test: does creating a Linode instance from a standard
# distribution image (linode/debian12) require the Images:Read scope in
# addition to Linodes:Read/Write, or is Linodes:Read/Write alone
# sufficient? Answers this by actually attempting a real instance
# creation with a token scoped to Linodes:Read/Write only, everything
# else (Account, Domains, Images, NodeBalancers, Object Storage, Users,
# ...) set to None -- then deletes the instance immediately either way.
#
# Reads LINODE_SCOPE_TEST_PAT from the environment (injected by the
# secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed). This token should be short-lived (a day or two) since
# it exists purely to answer this one question.
set -eu

AUTH="Authorization: Bearer $LINODE_SCOPE_TEST_PAT"
BASE="https://api.linode.com/v4"

RESPONSE=$(curl -sS -w '\n%{http_code}' -X POST "$BASE/linode/instances" \
  -H "$AUTH" \
  -H 'Content-Type: application/json' \
  -d '{
    "region": "us-east",
    "type": "g6-nanode-1",
    "image": "linode/debian12",
    "root_pass": "ScopeTest9384kdLQ!",
    "label": "pocketcoder-scope-test",
    "booted": false
  }')

BODY=$(printf '%s\n' "$RESPONSE" | sed '$d')
STATUS=$(printf '%s\n' "$RESPONSE" | tail -n1)

echo "CREATE_HTTP_STATUS=$STATUS"
echo "CREATE_BODY=$BODY"

if [ "$STATUS" = "200" ]; then
  INSTANCE_ID=$(printf '%s' "$BODY" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')
  echo "RESULT=PASS_LINODES_SCOPE_ALONE_IS_SUFFICIENT instance_id=$INSTANCE_ID"

  DELETE_STATUS=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE \
    "$BASE/linode/instances/$INSTANCE_ID" \
    -H "$AUTH")
  echo "CLEANUP_HTTP_STATUS=$DELETE_STATUS"
else
  echo "RESULT=FAIL_NEEDS_ADDITIONAL_SCOPE"
fi
