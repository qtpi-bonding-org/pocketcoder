#!/usr/bin/env bats

# Regression coverage for the full MCP gateway pipeline: gateway registration,
# catalog approval, and tool exposure through a real model-invoked call.

setup() {
  : "${PB_URL:?}"
  : "${PB_AUTH_COLLECTION:?}"
  : "${AGENT_TEST_EMAIL:?}"
  : "${AGENT_TEST_PASSWORD:?}"
  : "${MCP_GATEWAY_AUTH_TOKEN:?}"
  : "${GOOSE_CONTAINER:?}"
  : "${POCKETBASE_CONTAINER:?}"
  : "${MCP_GATEWAY_CONTAINER:?}"

  AUTH=$(curl -fsS -X POST "$PB_URL/api/collections/$PB_AUTH_COLLECTION/auth-with-password" \
    -H 'Content-Type: application/json' \
    -d "{\"identity\":\"$AGENT_TEST_EMAIL\",\"password\":\"$AGENT_TEST_PASSWORD\"}")
  USER_TOKEN=$(jq -r .token <<<"$AUTH")
  USER_ID=$(jq -r .record.id <<<"$AUTH")
  [ -n "$USER_TOKEN" ] && [ "$USER_TOKEN" != null ]
  CHAT_IDS=()
  MCP_SERVER_IDS=()
}

teardown() {
  if [ -n "${STREAM_PID:-}" ]; then
    kill "$STREAM_PID" 2>/dev/null || true
    wait "$STREAM_PID" 2>/dev/null || true
  fi
  for chat_id in "${CHAT_IDS[@]}"; do
    curl -sS -X DELETE "$PB_URL/api/collections/chats/records/$chat_id" \
      -H "Authorization: $USER_TOKEN" >/dev/null || true
  done
  for server_id in "${MCP_SERVER_IDS[@]}"; do
    curl -sS -X DELETE "$PB_URL/api/collections/mcp_servers/records/$server_id" \
      -H "Authorization: $USER_TOKEN" >/dev/null || true
  done
}

# goose_config_dir mirrors config_pipeline.bats's helper — the directory
# Goose actually reads config.yaml from, taken from `goose info`.
goose_config_dir() {
  docker exec "$GOOSE_CONTAINER" goose info 2>/dev/null |
    awk '/Config yaml:/{print $3}' | xargs dirname
}

wait_for_gateway() {
  for _ in $(seq 1 60); do
    curl -fsS http://mcp-gateway:8811/health >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

new_chat() {
  local title="mcp-gateway-${BATS_TEST_NUMBER}-$(date +%s%N)"
  local record
  record=$(curl -fsS -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"title\":\"$title\",\"user\":\"$USER_ID\"}")
  CHAT_ID=$(jq -r .id <<<"$record")
  CHAT_IDS+=("$CHAT_ID")
}

open_stream() {
  local cursor="${1:-0}"
  if [ -n "${STREAM_PID:-}" ]; then
    kill "$STREAM_PID" 2>/dev/null || true
    wait "$STREAM_PID" 2>/dev/null || true
  fi
  STREAM_FILE="$BATS_TEST_TMPDIR/stream-${RANDOM}.sse"
  curl --retry 5 --retry-connrefused --retry-delay 1 \
    --max-time "${AGENT_TEST_TIMEOUT_SECONDS:-120}" -sS -N \
    "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/stream?cursor=$cursor" \
    -H "Authorization: $USER_TOKEN" >"$STREAM_FILE" 2>&1 &
  STREAM_PID=$!
  sleep 1
}

start_run() {
  local prompt="$1"
  local resp run_status
  for _ in $(seq 1 30); do
    resp=$(curl --retry 5 --retry-connrefused --retry-delay 1 --max-time 15 -sS \
      -X POST "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/session/prompt" \
      -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
      -d "{\"prompt\":[{\"type\":\"text\",\"text\":$(jq -Rs . <<<"$prompt")}] }" || true)
    [ -n "$resp" ] || { sleep 2; continue; }
    RUN_ID=$(jq -r .runId <<<"$resp")
    [ -n "$RUN_ID" ] && [ "$RUN_ID" != null ] && return 0
    run_status=$(jq -r .status <<<"$resp")
    [ "$run_status" = provisioning ] || { printf '%s\n' "$resp" >&2; return 1; }
    sleep 2
  done
  return 1
}

wait_for_text() {
  local expected="$1"
  local attempts="${2:-40}"
  local text
  for _ in $(seq 1 "$attempts"); do
    text=$(grep '^data: ' "$STREAM_FILE" 2>/dev/null | sed 's/^data: //' |
      jq -r 'select(.type == "TEXT_MESSAGE_CONTENT") | .delta' 2>/dev/null | tr -d '\n')
    printf '%s' "$text" | grep -Fq "$expected" && return 0
    sleep 1
  done
  cat "$STREAM_FILE" >&2 || true
  return 1
}

wait_for_finish() {
  for _ in $(seq 1 40); do
    grep -q '"type":"RUN_FINISHED"' "$STREAM_FILE" 2>/dev/null && return 0
    sleep 1
  done
  cat "$STREAM_FILE" >&2 || true
  return 1
}

# approval_id/submit_option/resolve_permissions_until_finish mirror
# acceptance.bats's own helpers (each bats file in this suite duplicates its
# helpers rather than sharing a `load`ed file). A gateway tool call is still
# gated by this deployment's default tool_permissions policy (ask_before for
# mcp_request), so a real model-invoked call needs the same permission
# resolution loop acceptance.bats's shell-tool tests already use — plain
# wait_for_finish alone hangs on the pending request.
approval_id() {
  grep -o '"requestId":"[^"]*"' "$STREAM_FILE" | tail -1 | cut -d'"' -f4
}

submit_option() {
  local option_id="$1"
  [ -n "${APPROVAL_ID:-}" ]
  APPROVAL_HTTP_STATUS=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/session/request-permission/$APPROVAL_ID" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"outcome\":{\"outcome\":\"selected\",\"optionId\":\"$option_id\"}}")
}

resolve_permissions_until_finish() {
  local option_id="$1"
  local submitted=''
  # A fresh stream's first event pair is a synthetic RUN_STARTED/RUN_FINISHED
  # tied to the connection's own sync marker, not to the prompt started by
  # start_run — a blind RUN_FINISHED grep matches that pair immediately and
  # returns before the real run (and its pending permission) ever resolves.
  # Match on the specific $RUN_ID captured by start_run instead.
  for _ in $(seq 1 40); do
    if grep -q "\"runId\":\"$RUN_ID\"" "$STREAM_FILE" 2>/dev/null &&
       grep "\"runId\":\"$RUN_ID\"" "$STREAM_FILE" | grep -q '"type":"RUN_FINISHED"'; then
      return 0
    fi
    local current
    current=$(approval_id)
    if [ -n "$current" ] && [ "$current" != "$submitted" ]; then
      APPROVAL_ID="$current"
      submit_option "$option_id"
      [ "$APPROVAL_HTTP_STATUS" = 202 ] || return 1
      submitted="$current"
    fi
    sleep 1
  done
  cat "$STREAM_FILE" >&2 || true
  return 1
}

@test "mcp gateway remains available across a pocketbase restart" {
  wait_for_gateway
  docker restart "$POCKETBASE_CONTAINER"
  for _ in $(seq 1 30); do
    curl --max-time 5 -fsS "$PB_URL/api/health" >/dev/null 2>&1 && break
    sleep 2
  done
  wait_for_gateway
}

@test "approving an mcp_servers row reaches the gateway's catalog" {
  local name="agent-c1-test-server-$(date +%s%N)"
  local record
  record=$(curl -fsS -X POST "$PB_URL/api/collections/mcp_servers/records" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"status\":\"approved\",\"image\":\"mcp/n8n@sha256:061cdb8fbaa78f5a09787338715b180a0759057759f402c473b5f6ee13a8709e\"}")
  local server_id
  server_id=$(jq -r .id <<<"$record")
  [ -n "$server_id" ] && [ "$server_id" != null ]
  MCP_SERVER_IDS+=("$server_id")

  local found=0
  for _ in $(seq 1 30); do
    if docker exec "$MCP_GATEWAY_CONTAINER" cat /root/.docker/mcp/catalogs/docker-mcp.yaml 2>/dev/null | grep -q "$name"; then
      found=1
      break
    fi
    sleep 2
  done
  [ "$found" -eq 1 ]
}

@test "one gateway tool request requires and uses the configured authorization" {
  wait_for_gateway

  local init_body="$BATS_TEST_TMPDIR/gateway-init.json"
  local init_headers="$BATS_TEST_TMPDIR/gateway-init.headers"
  local init_status
  init_status=$(curl -sS -D "$init_headers" -o "$init_body" -w '%{http_code}' \
    -X POST http://mcp-gateway:8811/mcp \
    -H "Authorization: Bearer $MCP_GATEWAY_AUTH_TOKEN" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"agent-c1","version":"1"}}}')
  [ "$init_status" = 200 ]
  grep -iq '^mcp-session-id:' "$init_headers"

  local session_id
  session_id=$(awk -F': ' 'tolower($1) == "mcp-session-id" {gsub("\r", "", $2); print $2}' "$init_headers")
  [ -n "$session_id" ]

  local tool_body="$BATS_TEST_TMPDIR/gateway-tool.json"
  local tool_status
  tool_status=$(curl -sS -o "$tool_body" -w '%{http_code}' \
    -X POST http://mcp-gateway:8811/mcp \
    -H "Authorization: Bearer $MCP_GATEWAY_AUTH_TOKEN" \
    -H "Mcp-Session-Id: $session_id" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-find","arguments":{"query":"hello","limit":5}}}')
  [ "$tool_status" = 200 ]
  grep -Eq 'total_matches|totalMatches' "$tool_body"

  local unauthorized_status
  unauthorized_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST http://mcp-gateway:8811/mcp \
    -H 'Authorization: Bearer wrong-gateway-token' \
    -H "Mcp-Session-Id: $session_id" \
    -H 'Content-Type: application/json' \
    -H 'Accept: application/json, text/event-stream' \
    -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"mcp-find","arguments":{"query":"hello","limit":5}}}')
  [ "$unauthorized_status" = 401 ]
}

@test "gateway tools are reachable through a real model-invoked call" {
  wait_for_gateway

  new_chat
  open_stream
  start_run "Call the gateway__mcp-find tool with query 'hello' and limit 5, then reply with exactly the raw tool result text and nothing else."
  resolve_permissions_until_finish allow_once
  wait_for_text 'total_matches'
}
