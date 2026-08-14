#!/usr/bin/env bats

# No-model black-box coverage for the PocketCoder HTTP API. These tests run
# against the real PocketBase container, but deliberately do not require
# Goose, an LLM provider, or the MCP gateway.

# PocketBase rate-limits the auth-with-password endpoint; authenticating
# fresh in every test's setup() trips it once the suite has more than a
# handful of tests. Authenticate once per file instead and cache the tokens
# on disk for each test's setup() to read (each @test runs in its own bats
# subprocess, so env vars set in setup_file() don't otherwise survive).
AUTH_CACHE="${BATS_FILE_TMPDIR:-/tmp}/api-flow-auth-cache"

setup_file() {
  : "${PB_URL:?}"
  : "${PB_AUTH_COLLECTION:?}"
  : "${API_TEST_EMAIL:?}"
  : "${API_TEST_PASSWORD:?}"

  local auth user_token user_id
  auth=$(curl -fsS -X POST "$PB_URL/api/collections/$PB_AUTH_COLLECTION/auth-with-password" \
    -H 'Content-Type: application/json' \
    -d "{\"identity\":\"$API_TEST_EMAIL\",\"password\":\"$API_TEST_PASSWORD\"}")
  user_token=$(jq -r '.token // empty' <<<"$auth")
  user_id=$(jq -r '.record.id // empty' <<<"$auth")
  [ -n "$user_token" ]
  [ -n "$user_id" ]

  local agent_token=''
  # AGENT_EMAIL/AGENT_PASSWORD is the seeded "agent"-role user
  # (pb_migrations/1756000100_seed.go) — required to exercise role-gated
  # endpoints (mcp/request, mcp_servers creation) that "user" role can't reach.
  if [ -n "${AGENT_EMAIL:-}" ] && [ -n "${AGENT_PASSWORD:-}" ]; then
    local agent_auth
    agent_auth=$(curl -fsS -X POST "$PB_URL/api/collections/$PB_AUTH_COLLECTION/auth-with-password" \
      -H 'Content-Type: application/json' \
      -d "{\"identity\":\"$AGENT_EMAIL\",\"password\":\"$AGENT_PASSWORD\"}")
    agent_token=$(jq -r '.token // empty' <<<"$agent_auth")
    [ -n "$agent_token" ]
  fi

  cat >"$AUTH_CACHE" <<EOF
USER_TOKEN=$user_token
USER_ID=$user_id
AGENT_TOKEN=$agent_token
EOF
}

teardown_file() {
  rm -f "$AUTH_CACHE"
}

setup() {
  : "${POCKETBASE_CONTAINER:?}"

  # shellcheck disable=SC1090
  source "$AUTH_CACHE"
  [ -n "$USER_TOKEN" ]
  [ -n "$USER_ID" ]

  CHAT_ID=''
  ACCOUNT_ID=''
  FLOW_FILE="api-flow-${BATS_TEST_NUMBER}-$$.txt"
}

teardown() {
  if [ -n "${CHAT_ID:-}" ]; then
    curl -sS -X DELETE "$PB_URL/api/collections/chats/records/$CHAT_ID" \
      -H "Authorization: $USER_TOKEN" >/dev/null || true
  fi
  if [ -n "${ACCOUNT_ID:-}" ]; then
    curl -sS -X DELETE "$PB_URL/api/collections/harness_accounts/records/$ACCOUNT_ID" \
      -H "Authorization: $USER_TOKEN" >/dev/null || true
  fi
  docker exec "$POCKETBASE_CONTAINER" rm -f "/workspace/$FLOW_FILE" >/dev/null 2>&1 || true
}

new_chat() {
  CHAT_TITLE="api-flow-${BATS_TEST_NUMBER}-$(date +%s%N)"
  local response
  response=$(curl -fsS -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" \
    -H 'Content-Type: application/json' \
    -d "{\"title\":\"$CHAT_TITLE\",\"user\":\"$USER_ID\"}")
  CHAT_ID=$(jq -r '.id // empty' <<<"$response")
  [ -n "$CHAT_ID" ]
}

assert_unauthenticated() {
  local method="$1"
  local path="$2"
  local body="${3:-}"
  local status
  if [ -n "$body" ]; then
    status=$(curl -sS -o /dev/null -w '%{http_code}' -X "$method" \
      "$PB_URL$path" -H 'Content-Type: application/json' -d "$body")
  else
    status=$(curl -sS -o /dev/null -w '%{http_code}' -X "$method" "$PB_URL$path")
  fi
  [ "$status" = 401 ]
}

@test "compatibility is public and release status requires a user token" {
  local compatibility
  compatibility=$(curl -fsS "$PB_URL/api/pocketcoder/v1/compatibility")
  [ "$(jq -r '.schemaVersion' <<<"$compatibility")" = 1 ]
  [ "$(jq -r '.compatibility.server.apiVersion' <<<"$compatibility")" = 1 ]

  local release_status
  release_status=$(curl -fsS "$PB_URL/api/pocketcoder/v1/release/status" \
    -H "Authorization: $USER_TOKEN")
  [ "$(jq -r '.schemaVersion' <<<"$release_status")" = 1 ]
  [ "$(jq -r '.metadataStatus.schemaVersion' <<<"$release_status")" = 1 ]
  assert_unauthenticated GET /api/pocketcoder/v1/release/status
}

@test "authenticated chat records support create, read, update, and delete" {
  new_chat

  local record
  record=$(curl -fsS "$PB_URL/api/collections/chats/records/$CHAT_ID" \
    -H "Authorization: $USER_TOKEN")
  [ "$(jq -r '.title' <<<"$record")" = "$CHAT_TITLE" ]

  local updated
  updated=$(curl -fsS -X PATCH "$PB_URL/api/collections/chats/records/$CHAT_ID" \
    -H "Authorization: $USER_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"title":"api-flow-updated"}')
  [ "$(jq -r '.title' <<<"$updated")" = api-flow-updated ]

  local delete_status
  delete_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X DELETE "$PB_URL/api/collections/chats/records/$CHAT_ID" \
    -H "Authorization: $USER_TOKEN")
  [ "$delete_status" = 204 ] || [ "$delete_status" = 200 ]
  CHAT_ID=''
}

@test "workspace files can be listed and read through the versioned API" {
  local content="api-flow-content-${BATS_TEST_NUMBER}"
  docker exec "$POCKETBASE_CONTAINER" sh -c \
    "printf '%s' '$content' > '/workspace/$FLOW_FILE'"

  local file_response
  file_response=$(curl -fsS -G "$PB_URL/api/pocketcoder/v1/files" \
    -H "Authorization: $USER_TOKEN" \
    --data-urlencode "path=$FLOW_FILE")
  [ "$file_response" = "$content" ]

  local listing
  listing=$(curl -fsS -G "$PB_URL/api/pocketcoder/v1/files-list" \
    -H "Authorization: $USER_TOKEN" \
    --data-urlencode 'path=')
  jq -e --arg name "$FLOW_FILE" '.entries[] | select(.name == $name and .isDir == false)' \
    >/dev/null <<<"$listing"

  assert_unauthenticated GET "/api/pocketcoder/v1/files?path=$FLOW_FILE"
  assert_unauthenticated GET /api/pocketcoder/v1/files-list
}

@test "authenticated control endpoints return stable JSON shapes" {
  local ollama
  ollama=$(curl -fsS "$PB_URL/api/pocketcoder/v1/ollama/models" \
    -H "Authorization: $USER_TOKEN")
  jq -e '.models | type == "array"' >/dev/null <<<"$ollama"
  jq -e '.enabled | type == "boolean"' >/dev/null <<<"$ollama"

  local harnesses
  harnesses=$(curl -fsS "$PB_URL/api/collections/harnesses/records?perPage=1" \
    -H "Authorization: $USER_TOKEN")
  local harness_id
  harness_id=$(jq -r '.items[0].id // empty' <<<"$harnesses")
  if [ -n "$harness_id" ]; then
    local auth_status
    auth_status=$(curl -fsS -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/status" \
      -H "Authorization: $USER_TOKEN" \
      -H 'Content-Type: application/json' \
      -d "{\"harness\":\"$harness_id\"}")
    [ "$(jq -r '.harness' <<<"$auth_status")" = "$harness_id" ]
    [ -n "$(jq -r '.status' <<<"$auth_status")" ]
  fi
}

@test "authenticated and role-gated endpoints reject unauthenticated or ordinary-user calls" {
  assert_unauthenticated GET /api/pocketcoder/v1/ollama/models
  assert_unauthenticated GET /api/pocketcoder/v1/logs/pocketcoder-pocketbase
  assert_unauthenticated POST /api/pocketcoder/v1/push '{"title":"test"}'
  assert_unauthenticated POST /api/pocketcoder/v1/mcp/request '{"server_name":"api-flow"}'
  assert_unauthenticated POST /api/pocketcoder/v1/mcp/oauth/store '{"server_name":"api-flow","access_token":"test"}'
  assert_unauthenticated POST /api/pocketcoder/v1/harness-auth/status '{"harness":"missing"}'
  assert_unauthenticated POST /api/pocketcoder/v1/schedules/missing/run

  local mcp_status
  mcp_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/mcp/request" \
    -H "Authorization: $USER_TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"server_name":"api-flow-ordinary-user","reason":"role check","session_id":"api-flow"}')
  [ "$mcp_status" = 403 ]
}

# Harness provisioning/authentication below deliberately stays within
# credentialMode "none"/"api_key" and the no-active-attempt paths: those are
# pure PocketBase logic (internal/api/harness_auth.go). credentialMode
# "account" invokes harnessauth.Runtime.Start/Poll/Submit against a real
# auth-helper subprocess/container, which this no-model, no-live-harness
# suite does not have available.

@test "harness auth start/status round-trips none and api_key credential modes" {
  local harnesses harness_id harness_cli_id
  harnesses=$(curl -fsS "$PB_URL/api/collections/harnesses/records?perPage=1" \
    -H "Authorization: $USER_TOKEN")
  harness_id=$(jq -r '.items[0].id // empty' <<<"$harnesses")
  harness_cli_id=$(jq -r '.items[0].cli_id // empty' <<<"$harnesses")
  [ -n "$harness_id" ]

  # credentialMode "api_key" takes a provider_keys record id (not a raw
  # secret) in the "providerKey" field, per BindProviderKey in
  # internal/harnessauth/attempts.go.
  local provider_key
  provider_key=$(curl -fsS -X POST "$PB_URL/api/collections/provider_keys/records" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"user\":\"$USER_ID\",\"provider\":\"$harness_cli_id\",\"env_vars\":{\"API_KEY\":\"api-flow-test-key\"}}")
  local provider_key_id
  provider_key_id=$(jq -r '.id // empty' <<<"$provider_key")
  [ -n "$provider_key_id" ]

  local started
  started=$(curl -fsS -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/start" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"harness\":\"$harness_id\",\"credentialMode\":\"none\"}")
  [ "$(jq -r '.status' <<<"$started")" = disconnected ]
  [ "$(jq -r '.credentialMode' <<<"$started")" = none ]
  ACCOUNT_ID=$(jq -r '.accountId // empty' <<<"$started")
  [ -n "$ACCOUNT_ID" ]

  local status
  status=$(curl -fsS -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/status" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"harness\":\"$harness_id\",\"accountId\":\"$ACCOUNT_ID\"}")
  [ "$(jq -r '.accountId' <<<"$status")" = "$ACCOUNT_ID" ]
  [ "$(jq -r '.status' <<<"$status")" = disconnected ]

  local connected
  connected=$(curl -fsS -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/start" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"harness\":\"$harness_id\",\"accountId\":\"$ACCOUNT_ID\",\"credentialMode\":\"api_key\",\"providerKey\":\"$provider_key_id\"}")
  [ "$(jq -r '.credentialMode' <<<"$connected")" = api_key ]
  [ "$(jq -r '.status' <<<"$connected")" = connected ]

  curl -sS -X DELETE "$PB_URL/api/collections/provider_keys/records/$provider_key_id" \
    -H "Authorization: $USER_TOKEN" >/dev/null || true
}

@test "harness auth start and status validate input and reject unknown harnesses" {
  local start_missing_harness
  start_missing_harness=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/start" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' -d '{}')
  [ "$start_missing_harness" = 400 ]

  local start_unknown_harness
  start_unknown_harness=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/start" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"harness":"api-flow-missing-harness"}')
  [ "$start_unknown_harness" = 404 ]

  local harnesses harness_id
  harnesses=$(curl -fsS "$PB_URL/api/collections/harnesses/records?perPage=1" \
    -H "Authorization: $USER_TOKEN")
  harness_id=$(jq -r '.items[0].id // empty' <<<"$harnesses")
  [ -n "$harness_id" ]

  local bad_mode
  bad_mode=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/start" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"harness\":\"$harness_id\",\"credentialMode\":\"bogus\"}")
  [ "$bad_mode" = 400 ]

  local status_unknown_harness
  status_unknown_harness=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/status" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"harness":"api-flow-missing-harness"}')
  [ "$status_unknown_harness" = 404 ]

  assert_unauthenticated POST /api/pocketcoder/v1/harness-auth/start "{\"harness\":\"$harness_id\"}"
}

@test "harness auth poll, submit, and cancel report 404 without an active attempt" {
  local harnesses harness_id
  harnesses=$(curl -fsS "$PB_URL/api/collections/harnesses/records?perPage=1" \
    -H "Authorization: $USER_TOKEN")
  harness_id=$(jq -r '.items[0].id // empty' <<<"$harnesses")
  [ -n "$harness_id" ]

  local started
  started=$(curl -fsS -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/start" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"harness\":\"$harness_id\",\"credentialMode\":\"none\"}")
  ACCOUNT_ID=$(jq -r '.accountId // empty' <<<"$started")
  [ -n "$ACCOUNT_ID" ]

  local body="{\"harness\":\"$harness_id\",\"accountId\":\"$ACCOUNT_ID\"}"

  local poll_status
  poll_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/poll" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' -d "$body")
  [ "$poll_status" = 404 ]

  local submit_status
  submit_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/submit" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"harness\":\"$harness_id\",\"accountId\":\"$ACCOUNT_ID\",\"code\":\"123456\"}")
  [ "$submit_status" = 404 ]

  local cancel_status
  cancel_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/harness-auth/cancel" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' -d "$body")
  [ "$cancel_status" = 404 ]

  assert_unauthenticated POST /api/pocketcoder/v1/harness-auth/poll "$body"
}

# MCP approval/execution below covers the parts of the flow that are pure
# PocketBase logic (internal/api/mcp_oauth.go's token intake, and
# mcp/request's role gate + body validation in internal/api/mcp.go). A full
# mcp/request success response resolves the server image's digest via a
# container registry (internal/mcpserver.ResolveImageDigest -> crane.Digest)
# and does not require the mcp-gateway container itself, but does require
# outbound registry network access this suite does not assume is available,
# so it is intentionally left untested here.

@test "mcp oauth token store validates input and persists tokens into mcp_servers config" {
  [ -n "${AGENT_TOKEN:-}" ]

  local server_name="api-flow-oauth-${BATS_TEST_NUMBER}-$(date +%s%N)"
  local created
  created=$(curl -fsS -X POST "$PB_URL/api/collections/mcp_servers/records" \
    -H "Authorization: $AGENT_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$server_name\",\"status\":\"pending\",\"oauth_token_env_var\":\"API_FLOW_TEST_TOKEN\"}")
  local server_id
  server_id=$(jq -r '.id // empty' <<<"$created")
  [ -n "$server_id" ]

  local unconfigured_name="api-flow-oauth-unconfigured-${BATS_TEST_NUMBER}-$(date +%s%N)"
  local unconfigured
  unconfigured=$(curl -fsS -X POST "$PB_URL/api/collections/mcp_servers/records" \
    -H "Authorization: $AGENT_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$unconfigured_name\",\"status\":\"pending\"}")
  local unconfigured_id
  unconfigured_id=$(jq -r '.id // empty' <<<"$unconfigured")
  [ -n "$unconfigured_id" ]

  local missing_fields_status
  missing_fields_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/mcp/oauth/store" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' -d '{}')
  [ "$missing_fields_status" = 400 ]

  local not_found_status
  not_found_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/mcp/oauth/store" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"server_name":"api-flow-oauth-does-not-exist","access_token":"tok"}')
  [ "$not_found_status" = 404 ]

  local unconfigured_status
  unconfigured_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/mcp/oauth/store" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"server_name\":\"$unconfigured_name\",\"access_token\":\"tok\"}")
  [ "$unconfigured_status" = 400 ]

  local stored
  stored=$(curl -fsS -X POST "$PB_URL/api/pocketcoder/v1/mcp/oauth/store" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"server_name\":\"$server_name\",\"access_token\":\"tok-abc\",\"refresh_token\":\"ref-xyz\"}")
  [ "$(jq -r '.stored' <<<"$stored")" = true ]

  local record
  record=$(curl -fsS "$PB_URL/api/collections/mcp_servers/records/$server_id" \
    -H "Authorization: $AGENT_TOKEN")
  [ "$(jq -r '.config.API_FLOW_TEST_TOKEN' <<<"$record")" = tok-abc ]
  [ "$(jq -r '.config.API_FLOW_TEST_TOKEN_REFRESH_TOKEN' <<<"$record")" = ref-xyz ]

  assert_unauthenticated POST /api/pocketcoder/v1/mcp/oauth/store \
    "{\"server_name\":\"$server_name\",\"access_token\":\"tok\"}"

  # mcp_servers deleteRule requires the admin role; the seeded agent/user
  # tokens available to this suite can't clean these rows up, so they are
  # intentionally left behind as accumulated test data.
}

@test "mcp request validates the request body once the agent role gate passes" {
  [ -n "${AGENT_TOKEN:-}" ]

  local missing_server_name
  missing_server_name=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/mcp/request" \
    -H "Authorization: $AGENT_TOKEN" -H 'Content-Type: application/json' \
    -d '{"reason":"api-flow","session_id":"api-flow"}')
  [ "$missing_server_name" = 400 ]
}
