#!/usr/bin/env bash
set -euo pipefail

read -r -s -p 'Claude authentication code: ' pc_code
printf '\n'

pc_env=$(docker inspect pocketcoder-pocketbase --format '{{range .Config.Env}}{{println .}}{{end}}')
pc_email=$(printf '%s\n' "$pc_env" | sed -n 's/^AGENT_EMAIL=//p')
pc_password=$(printf '%s\n' "$pc_env" | sed -n 's/^AGENT_PASSWORD=//p')

pc_login=$(curl -fsS -X POST http://127.0.0.1:8090/api/collections/users/auth-with-password \
  -H 'Content-Type: application/json' \
  -d "{\"identity\":\"$pc_email\",\"password\":\"$pc_password\"}")
pc_token=$(printf '%s' "$pc_login" | jq -r '.token')
pc_harness=$(curl -fsS http://127.0.0.1:8090/api/collections/harnesses/records \
  -H "Authorization: $pc_token" | jq -r '.items[] | select(.cli_id == "claude-code") | .id')

jq -n --arg harness "$pc_harness" --arg code "$pc_code" '{harness: $harness, code: $code}' |
  curl -fsS -X POST http://127.0.0.1:8090/api/pocketcoder/harness_auth/submit \
    -H "Authorization: $pc_token" \
    -H 'Content-Type: application/json' \
    --data-binary @- |
  jq '{status, lastError, attempt}'
