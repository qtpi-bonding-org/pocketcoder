#!/bin/sh
set -eu

: "${CLAUDE_CODE_OAUTH_TOKEN:?CLAUDE_CODE_OAUTH_TOKEN must be set (injected by the secrets daemon)}"

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
set -a
[ -f "$REPO_ROOT/.env" ] && . "$REPO_ROOT/.env"
set +a

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

HARNESS_ID=$(curl -fsS "$PB_URL/api/collections/harnesses/records?filter=cli_id='claude-code'" \
  -H "Authorization: $USER_TOKEN" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["items"][0]["id"])')

# Redirects the placeholder api_key set below off ANTHROPIC_API_KEY -- the
# var claude-code's CLI checks before CLAUDE_CODE_OAUTH_TOKEN.
: "${POCKETBASE_SUPERUSER_EMAIL:?POCKETBASE_SUPERUSER_EMAIL must be set}"
: "${POCKETBASE_SUPERUSER_PASSWORD:?POCKETBASE_SUPERUSER_PASSWORD must be set}"
SUPERUSER_AUTH=$(curl -fsS -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
  -H 'Content-Type: application/json' \
  -d "{\"identity\":\"$POCKETBASE_SUPERUSER_EMAIL\",\"password\":\"$POCKETBASE_SUPERUSER_PASSWORD\"}")
SUPERUSER_TOKEN=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["token"])' <<EOF
$SUPERUSER_AUTH
EOF
)
EDGE_ID=$(curl -fsS "$PB_URL/api/collections/harness_providers/records?filter=harness='$HARNESS_ID'%20%26%26%20provider='$PROVIDER_ID'" \
  -H "Authorization: $SUPERUSER_TOKEN" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["items"][0]["id"])')
curl -fsS -X PATCH "$PB_URL/api/collections/harness_providers/records/$EDGE_ID" \
  -H "Authorization: $SUPERUSER_TOKEN" -H 'Content-Type: application/json' \
  -d '{"api_key_env_override": "ANTHROPIC_API_KEY_UNUSED_BY_OAUTH_TOKEN_TEST"}' >/dev/null

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

# A running harness container has this credential baked into its env at
# creation time and is never live-updated -- if one is already up for this
# user+harness from before, the fresh credential above would silently
# never reach it. Clear it so the next test run provisions fresh.
STALE=$(curl -fsS "$PB_URL/api/collections/harness_instances/records?filter=user='$USER_ID'%20%26%26%20harness='$HARNESS_ID'" \
  -H "Authorization: $SUPERUSER_TOKEN")
python3 -c 'import json,sys
for i in json.load(sys.stdin)["items"]: print(i["id"], i.get("container_name",""))' <<EOF |
$STALE
EOF
while read -r instance_id container_name; do
  [ -n "$container_name" ] && docker rm -f "$container_name" >/dev/null 2>&1
  curl -fsS -X DELETE "$PB_URL/api/collections/harness_instances/records/$instance_id" \
    -H "Authorization: $SUPERUSER_TOKEN" >/dev/null
  echo "cleared stale harness instance: $instance_id ($container_name)"
done
