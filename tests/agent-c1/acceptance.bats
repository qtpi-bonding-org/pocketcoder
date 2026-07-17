#!/usr/bin/env bats

# Real-model acceptance coverage for c1 PocketBase + c2 Goose. Each test owns
# its chats and deletes them in teardown; no PocketBase messages or approvals
# are asserted because Goose is authoritative for those.

setup() {
  : "${PB_URL:?}"
  : "${PB_AUTH_COLLECTION:?}"
  : "${AGENT_TEST_EMAIL:?}"
  : "${AGENT_TEST_PASSWORD:?}"
  : "${GOOSE_CONTAINER:?}"
  : "${POCKETBASE_CONTAINER:?}"

  AUTH=$(curl -fsS -X POST "$PB_URL/api/collections/$PB_AUTH_COLLECTION/auth-with-password" \
    -H 'Content-Type: application/json' \
    -d "{\"identity\":\"$AGENT_TEST_EMAIL\",\"password\":\"$AGENT_TEST_PASSWORD\"}")
  USER_TOKEN=$(jq -r .token <<<"$AUTH")
  USER_ID=$(jq -r .record.id <<<"$AUTH")
  [ -n "$USER_TOKEN" ] && [ "$USER_TOKEN" != null ]
  CHAT_IDS=()
}

teardown() {
	if [ -n "${RUN_PID:-}" ]; then
	  kill "$RUN_PID" 2>/dev/null || true
	  wait "$RUN_PID" 2>/dev/null || true
	fi
	for chat_id in "${CHAT_IDS[@]}"; do
    curl -sS -X DELETE "$PB_URL/api/collections/chats/records/$chat_id" \
      -H "Authorization: $USER_TOKEN" >/dev/null || true
  done
}

wait_for_pocketbase() {
  for _ in $(seq 1 30); do
    curl --max-time 5 -fsS "$PB_URL/api/health" >/dev/null && return 0
    sleep 1
  done
  return 1
}

wait_for_goose() {
  for _ in $(seq 1 30); do
    [ "$(docker inspect "$GOOSE_CONTAINER" --format '{{.State.Health.Status}}')" = healthy ] && return 0
    sleep 1
  done
  return 1
}

new_chat() {
  local title="agent-c1-${BATS_TEST_NUMBER}-$(date +%s%N)"
  local record
  record=$(curl -fsS -X POST "$PB_URL/api/collections/chats/records" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"title\":\"$title\",\"user\":\"$USER_ID\"}")
  CHAT_ID=$(jq -r .id <<<"$record")
  CHAT_IDS+=("$CHAT_ID")
}

start_run() {
  local prompt="$1"
  RUN_FILE="$BATS_TEST_TMPDIR/run.sse"
  curl --max-time "${AGENT_TEST_TIMEOUT_SECONDS:-120}" -sS -N \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/runs" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"prompt\":$(jq -Rs . <<<"$prompt")}" >"$RUN_FILE" 2>&1 &
  RUN_PID=$!
}

wait_for() {
  local pattern="$1"
  local attempts="${2:-40}"
  for _ in $(seq 1 "$attempts"); do
    grep -q "$pattern" "$RUN_FILE" 2>/dev/null && return 0
    sleep 1
  done
  cat "$RUN_FILE" >&2 || true
  return 1
}

approval_id() {
  grep -o '"requestId":"[^"]+"' "$RUN_FILE" | head -1 | cut -d'"' -f4
}

submit_option() {
  local option_id="$1"
  local request_id
  request_id=$(approval_id)
  [ -n "$request_id" ]
  curl -fsS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/approvals/$request_id" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"optionId\":\"$option_id\"}"
}

wait_for_finish() {
  wait "$RUN_PID"
  grep -q '"type":"RUN_FINISHED"' "$RUN_FILE"
}

@test "same chat reconnects through Goose session/load" {
  new_chat
  start_run "Reply with exactly: agent-c1-first"
  wait_for 'agent-c1-first'
  wait_for_finish

  start_run "Reply with exactly: agent-c1-second"
  wait_for 'agent-c1-second'
  wait_for_finish
}

@test "offered allow and deny decisions reach Goose" {
  new_chat
  start_run "Use your shell tool to run: printf allowed-by-c1. Do not answer before requesting permission."
  wait_for '"requestId"'
  [ "$(submit_option allow_once)" = 202 ]
  wait_for_finish

  new_chat
  start_run "Use your shell tool to run: printf denied-by-c1. Do not answer before requesting permission."
  wait_for '"requestId"'
  [ "$(submit_option reject_once)" = 202 ]
  wait_for_finish
}

@test "cancel and concurrent run behave deterministically" {
  new_chat
  start_run "Use your shell tool to run: sleep 20. Do not answer before requesting permission."
  wait_for '"requestId"'

  local conflict
  conflict=$(curl -sS -o "$BATS_TEST_TMPDIR/conflict.json" -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/runs" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"prompt":"This must be rejected as concurrent."}')
  [ "$conflict" = 409 ]

  local cancelled
  cancelled=$(curl -fsS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/cancel" \
    -H "Authorization: $USER_TOKEN")
  [ "$cancelled" = 202 ]
  wait_for_finish
}

@test "c1 restart drops pending approval and c2 restart reloads session" {
  new_chat
  start_run "Use your shell tool to run: printf pending-c1-restart. Do not answer before requesting permission."
  wait_for '"requestId"'
  local old_approval
  old_approval=$(approval_id)
  docker restart "$POCKETBASE_CONTAINER" >/dev/null
  wait_for_pocketbase
  local stale_status
  stale_status=$(curl -sS -o "$BATS_TEST_TMPDIR/stale.json" -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/approvals/$old_approval" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"optionId":"allow_once"}')
  [ "$stale_status" = 404 ]

  # The previous run's connection is expected to end at c1 restart. A fresh
  # chat proves the restarted c1 is usable before testing c2 persistence.
  new_chat
  start_run "Reply with exactly: before-c2-restart"
  wait_for 'before-c2-restart'
  wait_for_finish
  docker restart "$GOOSE_CONTAINER" >/dev/null
  wait_for_goose
  start_run "Reply with exactly: after-c2-restart"
  wait_for 'after-c2-restart'
  wait_for_finish
}
