#!/usr/bin/env bats

# Regression coverage for docs/superpowers/specs/2026-07-23-mcp-governance-ui-design.md.
# Proves the full pipeline spikes/goose-mcp-gateway-attach/README.md validated
# manually: gateway registration, catalog approval, and tool exposure through
# a real model-invoked call.

setup() {
  : "${PB_URL:?}"
  : "${PB_AUTH_COLLECTION:?}"
  : "${AGENT_TEST_EMAIL:?}"
  : "${AGENT_TEST_PASSWORD:?}"
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

gateway_extension_count() {
  local cfg_dir
  cfg_dir=$(goose_config_dir)
  docker exec "$GOOSE_CONTAINER" sh -c "grep -c '^  gateway:' '$cfg_dir/config.yaml' 2>/dev/null || echo 0"
}

wait_for_gateway_extension() {
  for _ in $(seq 1 60); do
    [ "$(gateway_extension_count)" -ge 1 ] && return 0
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
    "$PB_URL/api/pocketcoder/chats/$CHAT_ID/stream?cursor=$cursor" \
    -H "Authorization: $USER_TOKEN" >"$STREAM_FILE" 2>&1 &
  STREAM_PID=$!
  sleep 1
}

start_run() {
  local prompt="$1"
  local resp
  resp=$(curl --max-time 15 -sS \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/session/prompt" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"prompt\":[{\"type\":\"text\",\"text\":$(jq -Rs . <<<"$prompt")}]}")
  RUN_ID=$(jq -r .runId <<<"$resp")
  [ -n "$RUN_ID" ] && [ "$RUN_ID" != null ]
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

@test "mcp gateway extension registers exactly once and survives a pocketbase restart" {
  wait_for_gateway_extension
  [ "$(gateway_extension_count)" -eq 1 ]

  docker restart "$POCKETBASE_CONTAINER"
  # Give PocketBase's OnServe (and RegisterMcpGatewayExtension's first
  # attempt) time to run again after the restart.
  for _ in $(seq 1 30); do
    curl --max-time 5 -fsS "$PB_URL/api/health" >/dev/null 2>&1 && break
    sleep 2
  done

  wait_for_gateway_extension
  [ "$(gateway_extension_count)" -eq 1 ]
}

@test "approving an mcp_servers row reaches the gateway's catalog" {
  local name="agent-c1-test-server-$(date +%s%N)"
  local record
  record=$(curl -fsS -X POST "$PB_URL/api/collections/mcp_servers/records" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"name\":\"$name\",\"status\":\"approved\",\"image\":\"mcp/hello-world:latest\"}")
  local server_id
  server_id=$(jq -r .id <<<"$record")
  [ -n "$server_id" ] && [ "$server_id" != null ]
  MCP_SERVER_IDS+=("$server_id")

  local found=0
  for _ in $(seq 1 30); do
    if docker exec "$MCP_GATEWAY_CONTAINER" cat /root/.docker/mcp/docker-mcp.yaml 2>/dev/null | grep -q "$name"; then
      found=1
      break
    fi
    sleep 2
  done
  [ "$found" -eq 1 ]
}

@test "gateway tools are reachable through a real model-invoked call" {
  wait_for_gateway_extension

  new_chat
  open_stream
  start_run "Call the gateway__mcp-find tool with query 'hello' and limit 5, then reply with exactly the raw tool result text and nothing else."
  wait_for_finish
  wait_for_text 'total_matches'
}
