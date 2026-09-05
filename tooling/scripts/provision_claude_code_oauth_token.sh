#!/bin/sh
set -eu

: "${CLAUDE_CODE_OAUTH_TOKEN:?CLAUDE_CODE_OAUTH_TOKEN must be set (injected by the secrets daemon)}"

PB_URL="${PB_URL:-http://127.0.0.1:8090}"
EMAIL="skills-files-integration-test@pocketcoder.local"
PASS="skills-files-integration-test-pw"

AUTH=$(curl -fsS -X POST "$PB_URL/api/collections/users/auth-with-password" \
  -H 'Content-Type: application/json' \
  -d "{\"identity\":\"$EMAIL\",\"password\":\"$PASS\"}")
USER_TOKEN=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])' <<EOF
$AUTH
EOF
)
USER_ID=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["record"]["id"])' <<EOF
$AUTH
EOF
)

PROVIDER_ID=$(curl -fsS "$PB_URL/api/collections/providers/records?filter=provider_id='anthropic'" \
  -H "Authorization: $USER_TOKEN" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["items"][0]["id"])')

EXISTING=$(curl -fsS "$PB_URL/api/collections/provider_api_keys/records?filter=owner='$USER_ID'%20%26%26%20provider='$PROVIDER_ID'" \
  -H "Authorization: $USER_TOKEN")
for id in $(python3 -c 'import json,sys
for i in json.load(sys.stdin)["items"]: print(i["id"])' <<EOF
$EXISTING
EOF
); do
  curl -fsS -X DELETE "$PB_URL/api/collections/provider_api_keys/records/$id" \
    -H "Authorization: $USER_TOKEN" >/dev/null
done

USER_ID="$USER_ID" PROVIDER_ID="$PROVIDER_ID" PB_URL="$PB_URL" USER_TOKEN="$USER_TOKEN" CLAUDE_CODE_OAUTH_TOKEN="$CLAUDE_CODE_OAUTH_TOKEN" python3 -c '
import json, os, urllib.request
body = json.dumps({
    "owner": os.environ["USER_ID"],
    "provider": os.environ["PROVIDER_ID"],
    "api_key": "claude-code-oauth-managed",
    "extra_env": {"CLAUDE_CODE_OAUTH_TOKEN": os.environ["CLAUDE_CODE_OAUTH_TOKEN"]},
}).encode()
req = urllib.request.Request(
    os.environ["PB_URL"] + "/api/collections/provider_api_keys/records",
    data=body,
    method="POST",
    headers={"Authorization": os.environ["USER_TOKEN"], "Content-Type": "application/json"},
)
with urllib.request.urlopen(req) as resp:
    print("saved provider_api_keys record:", json.load(resp)["id"])
'
