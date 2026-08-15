#!/usr/bin/env bats

# Compose-level contract for the private Pocket Memory MCP endpoint. The
# caller supplies attribution; the service owns account scoping.

setup() {
  : "${POCKET_MEMORY_URL:?}"
  ACCOUNT_A="memory-test-account-a-${BATS_TEST_NUMBER}"
  ACCOUNT_B="memory-test-account-b-${BATS_TEST_NUMBER}"
  PROFILE="memory-test-profile"
  BODY="memory-compose-${BATS_TEST_NUMBER}-$(date +%s%N)"
  SESSION_ID=""
}

context_header() {
  local account="$1"
  jq -cn --arg account "$account" --arg profile "$PROFILE" \
    '{version: 1, account_id: $account, agent_profile_id: $profile, agent_name: "Poco"}' |
    base64 | tr '+/' '-_' | tr -d '=\n'
}

mcp_post() {
  local account="$1"
  local request="$2"
  local headers="$BATS_TEST_TMPDIR/headers"
  local body="$BATS_TEST_TMPDIR/body"
  local args=(
    -fsS -D "$headers" -o "$body"
    -X POST "$POCKET_MEMORY_URL/mcp"
    -H 'Host: localhost'
    -H 'MCP-Protocol-Version: 2025-03-26'
    -H 'Content-Type: application/json'
    -H 'Accept: application/json, text/event-stream'
    -H "X-PocketCoder-Memory-Context: $(context_header "$account")"
  )
  if [ -n "$SESSION_ID" ]; then
    args+=(-H "Mcp-Session-Id: $SESSION_ID")
  fi
  curl "${args[@]}" --data "$request"
  local response_session
  response_session=$(awk 'tolower($1) == "mcp-session-id:" {print $2}' "$headers" | tr -d '\r')
  [ -z "$response_session" ] || SESSION_ID="$response_session"
  cat "$body"
}

rpc() {
  local account="$1"
  local id="$2"
  local method="$3"
  local params="${4:-null}"
  mcp_post "$account" "$(jq -cn --argjson id "$id" --arg method "$method" --argjson params "$params" \
    '{jsonrpc: "2.0", id: $id, method: $method, params: $params}')"
}

initialize() {
  SESSION_ID=""
  rpc "$1" 1 initialize \
    '{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"pocketcoder-memory-test","version":"1.0"}}'
}

@test "MCP creates and reads an observation, isolates accounts, and cleans up" {
  run initialize "$ACCOUNT_A"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"protocolVersion"'* ]]

  run rpc "$ACCOUNT_A" 3 tools/call \
    "$(jq -cn --arg body "$BODY" '{name:"memory_create_observation",arguments:{body:$body}}')"
  [ "$status" -eq 0 ]
  OBSERVATION_ID=$(jq -r '.result.structuredContent.id // empty' <<<"$output")
  [ -n "$OBSERVATION_ID" ]
  [ "$(jq -r '.result.structuredContent.account_id' <<<"$output")" = "$ACCOUNT_A" ]

  run rpc "$ACCOUNT_A" 4 tools/call \
    '{"name":"memory_list","arguments":{"kind":"observation"}}'
  [ "$status" -eq 0 ]
  [ "$(jq -r '.result.structuredContent[0].id' <<<"$output")" = "$OBSERVATION_ID" ]
  [ "$(jq -r '.result.structuredContent[0].body' <<<"$output")" = "$BODY" ]

  SESSION_ID=""
  run initialize "$ACCOUNT_B"
  [ "$status" -eq 0 ]
  run rpc "$ACCOUNT_B" 3 tools/call \
    '{"name":"memory_list","arguments":{"kind":"observation"}}'
  [ "$status" -eq 0 ]
  [ "$(jq '.result.structuredContent | length' <<<"$output")" -eq 0 ]

  # There is deliberately no primitive delete MCP tool. The runner owns a
  # dedicated Compose project/volume and removes it after this test suite.
  run rpc "$ACCOUNT_A" 4 tools/list '{}'
  [ "$status" -eq 0 ]
  ! grep -q 'memory_delete' <<<"$output"
}
