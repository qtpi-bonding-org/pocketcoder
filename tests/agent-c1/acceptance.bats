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
  local consecutive=0
  for _ in $(seq 1 30); do
    if curl --max-time 5 -fsS "$PB_URL/api/health" >/dev/null; then
      consecutive=$((consecutive + 1))
      [ "$consecutive" -ge 3 ] && return 0
    else
      consecutive=0
    fi
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
  # Keep each SSE client on its own inode. A c1 restart can make an older curl
  # write its final transport diagnostic after a newer run has begun.
  RUN_FILE="$BATS_TEST_TMPDIR/run-${RANDOM}.sse"
  curl --retry 5 --retry-connrefused --retry-delay 1 \
    --max-time "${AGENT_TEST_TIMEOUT_SECONDS:-120}" -sS -N \
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

wait_for_text() {
  local expected="$1"
  local attempts="${2:-40}"
  local text
  for _ in $(seq 1 "$attempts"); do
    text=$(grep '^data: ' "$RUN_FILE" 2>/dev/null | sed 's/^data: //' |
      jq -r 'select(.type == "TEXT_MESSAGE_CONTENT") | .delta' 2>/dev/null | tr -d '\n')
    printf '%s' "$text" | grep -Fq "$expected" && return 0
    sleep 1
  done
  cat "$RUN_FILE" >&2 || true
  return 1
}

approval_id() {
  grep -o '"requestId":"[^"]*"' "$RUN_FILE" | tail -1 | cut -d'"' -f4
}

wait_for_approval() {
  APPROVAL_ID=''
  for _ in $(seq 1 10); do
    APPROVAL_ID=$(approval_id)
    [ -n "$APPROVAL_ID" ] && return 0
    sleep 1
  done
  cat "$RUN_FILE" >&2 || true
  return 1
}

submit_option() {
  local option_id="$1"
  [ -n "${APPROVAL_ID:-}" ]
  APPROVAL_HTTP_STATUS=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/approvals/$APPROVAL_ID" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"optionId\":\"$option_id\"}")
}

wait_for_finish() {
  wait "$RUN_PID"
  grep -q '"type":"RUN_FINISHED"' "$RUN_FILE"
}

# A rejected shell call can cause a real model to try a different command.
# Continue resolving distinct offered requests so this test verifies the c1
# pass-through, rather than assuming one particular model decision tree.
resolve_permissions_until_finish() {
  local option_id="$1"
  local submitted=''
  for _ in $(seq 1 40); do
    if grep -q '"type":"RUN_FINISHED"' "$RUN_FILE" 2>/dev/null; then
      wait_for_finish
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
  cat "$RUN_FILE" >&2 || true
  return 1
}

replay_chat() {
  REPLAY_FILE="$BATS_TEST_TMPDIR/replay.sse"
  curl --max-time "${AGENT_TEST_TIMEOUT_SECONDS:-120}" -sS -N \
    "$PB_URL/api/pocketcoder/chats/$CHAT_ID/events" \
    -H "Authorization: $USER_TOKEN" >"$REPLAY_FILE" 2>&1
}

@test "same chat reconnects through Goose session/load" {
  new_chat
  start_run "Reply with exactly: agent-c1-first"
  wait_for_text 'agent-c1-first'
  wait_for_finish

  start_run "Reply with exactly: agent-c1-second"
  wait_for_text 'agent-c1-second'
  wait_for_finish
}

@test "owned chat replay is Goose history and an unmapped chat is empty" {
  new_chat
  replay_chat
  grep -q '"type":"RUN_STARTED"' "$REPLAY_FILE"
  grep -q '"type":"RUN_FINISHED"' "$REPLAY_FILE"
  ! grep -q '"type":"TEXT_MESSAGE_CONTENT"' "$REPLAY_FILE"

  start_run "Reply with exactly: replayed-by-goose"
  wait_for_text 'replayed-by-goose'
  wait_for_finish

  replay_chat
  grep '^data: ' "$REPLAY_FILE" | sed 's/^data: //' |
    jq -r 'select(.type == "TEXT_MESSAGE_CONTENT") | .delta' | tr -d '\n' |
    grep -Fq 'replayed-by-goose'
}

@test "offered allow and deny decisions reach Goose" {
  new_chat
  start_run "Invoke the shell tool immediately. Execute exactly: printf allowed-by-c1. Do not ask a question, explain, or reply with text before the tool call."
  resolve_permissions_until_finish allow_once

  new_chat
  start_run "Invoke the shell tool immediately. Execute exactly: printf denied-by-c1. Do not ask a question, explain, or reply with text before the tool call."
  resolve_permissions_until_finish reject_once
}

@test "cancel and concurrent run behave deterministically" {
  new_chat
  start_run "Invoke the shell tool immediately. Execute exactly: sleep 20. Do not ask a question, explain, or reply with text before the tool call."
  wait_for_approval

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

@test "c1 restart resolves pending work and same chat reloads; c2 restart reloads session" {
  new_chat
  start_run "Invoke the shell tool immediately. Execute exactly: printf pending-c1-restart. Do not ask a question, explain, or reply with text before the tool call."
  wait_for_approval
  local old_approval
  old_approval="$APPROVAL_ID"
  docker restart "$POCKETBASE_CONTAINER" >/dev/null
  wait_for_pocketbase
  # Docker reports the container started before PocketBase has finished
  # replacing its listener. wait_for_pocketbase requires three healthy polls.
  # Let the old SSE curl observe the restart before reusing its capture path.
  # Otherwise its connection-refused diagnostic can race into the follow-up
  # run's file and hide the same-chat recovery result.
  wait "$RUN_PID" 2>/dev/null || true
  unset RUN_PID
  local stale_status
  stale_status=$(curl -sS -o "$BATS_TEST_TMPDIR/stale.json" -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/chats/$CHAT_ID/approvals/$old_approval" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"optionId":"allow_once"}')
  [ "$stale_status" = 404 ]

  # This must use the original chat. A c1 restart cannot leave its Goose
  # request_permission blocked indefinitely after the in-memory ID is gone.
  start_run "Reply with exactly: same-chat-after-c1-restart"
  wait_for_text 'same-chat-after-c1-restart'
  wait_for_finish
  docker restart "$GOOSE_CONTAINER" >/dev/null
  wait_for_goose
  start_run "Reply with exactly: after-c2-restart"
  wait_for_text 'after-c2-restart'
  wait_for_finish
}
