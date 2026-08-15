#!/usr/bin/env bats

# Real-model acceptance coverage for c1 PocketBase + c2 Goose. Each test owns
# its chats and deletes them in teardown; no PocketBase messages or approvals
# are asserted because Goose is authoritative for those.
#
# Transport (post-cutover): POST .../session/prompt returns 202+runId
# immediately; the run's events are observed on a SEPARATE durable
# GET .../stream?cursor= subscription, which does not close itself when the
# run finishes (any number of subscribers can attach/reattach without
# stalling or conflicting with an active run). Tests therefore drive the
# prompt POST and the stream GET as two independent processes and detect
# completion by grepping the stream capture for RUN_FINISHED rather than by
# waiting for the stream's own process to exit.

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
	if [ -n "${STREAM_PID:-}" ]; then
	  kill "$STREAM_PID" 2>/dev/null || true
	  wait "$STREAM_PID" 2>/dev/null || true
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

# open_stream starts (or restarts) the durable subscription for the current
# CHAT_ID at the given cursor (default 0 = everything), writing frames to
# STREAM_FILE. Kept on its own inode per open so a c1 restart can't make an
# older curl's final transport diagnostic land in a newer capture.
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
  # Give the subscription a moment to attach before a caller posts a prompt,
  # so RUN_STARTED is never missed on a slow-starting connection.
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
    [ "$run_status" = provisioning ] || [ "$run_status" = 409 ] || {
      printf '%s\n' "$resp" >&2
      return 1
    }
    sleep 2
  done
  return 1
}

wait_for() {
  local pattern="$1"
  local attempts="${2:-40}"
  for _ in $(seq 1 "$attempts"); do
    grep -q "$pattern" "$STREAM_FILE" 2>/dev/null && return 0
    sleep 1
  done
  cat "$STREAM_FILE" >&2 || true
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

approval_id() {
  grep -o '"requestId":"[^"]*"' "$STREAM_FILE" | tail -1 | cut -d'"' -f4
}

wait_for_approval() {
  APPROVAL_ID=''
  for _ in $(seq 1 40); do
    APPROVAL_ID=$(approval_id)
    [ -n "$APPROVAL_ID" ] && return 0
    sleep 1
  done
  cat "$STREAM_FILE" >&2 || true
  return 1
}

submit_option() {
  local option_id="$1"
  [ -n "${APPROVAL_ID:-}" ]
  APPROVAL_HTTP_STATUS=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/session/request-permission/$APPROVAL_ID" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d "{\"outcome\":{\"outcome\":\"selected\",\"optionId\":\"$option_id\"}}")
}

# wait_for_finish polls the stream capture for RUN_FINISHED rather than
# waiting on the streaming curl's own exit: the stream is a durable
# subscription and does not close itself when a run ends.
wait_for_finish() {
  wait_for '"type":"RUN_FINISHED"'
}

# A rejected shell call can cause a real model to try a different command.
# Continue resolving distinct offered requests so this test verifies the c1
# pass-through, rather than assuming one particular model decision tree.
resolve_permissions_until_finish() {
  local option_id="$1"
  local submitted=''
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

@test "same chat reconnects through Goose session/load" {
  new_chat
  open_stream
  start_run "Reply with exactly: agent-c1-first"
  wait_for_text 'agent-c1-first'
  wait_for_finish

  open_stream
  start_run "Reply with exactly: agent-c1-second"
  wait_for_text 'agent-c1-second'
  wait_for_finish
}

@test "owned chat stream is Goose history and an unmapped chat is empty" {
  new_chat
  open_stream
  grep -q '"type":"RUN_STARTED"' "$STREAM_FILE"
  grep -q '"type":"RUN_FINISHED"' "$STREAM_FILE"
  ! grep -q '"type":"TEXT_MESSAGE_CONTENT"' "$STREAM_FILE"

  open_stream
  start_run "Reply with exactly: replayed-by-goose"
  wait_for_text 'replayed-by-goose'
  wait_for_finish

  open_stream
  grep '^data: ' "$STREAM_FILE" | sed 's/^data: //' |
    jq -r 'select(.type == "TEXT_MESSAGE_CONTENT") | .delta' | tr -d '\n' |
    grep -Fq 'replayed-by-goose'
}

@test "offered allow and deny decisions reach Goose" {
  new_chat
  open_stream
  start_run "Invoke the shell tool immediately. Execute exactly: printf allowed-by-c1. Do not ask a question, explain, or reply with text before the tool call."
  resolve_permissions_until_finish allow_once

  new_chat
  open_stream
  start_run "Invoke the shell tool immediately. Execute exactly: printf denied-by-c1. Do not ask a question, explain, or reply with text before the tool call."
  resolve_permissions_until_finish reject_once
}

@test "cancel and concurrent run behave deterministically; stream never 409s" {
  new_chat
  open_stream
  start_run "Invoke the shell tool immediately. Execute exactly: sleep 20. Do not ask a question, explain, or reply with text before the tool call."
  wait_for_approval

  local conflict
  conflict=$(curl -sS -o "$BATS_TEST_TMPDIR/conflict.json" -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/session/prompt" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"prompt":[{"type":"text","text":"This must be rejected as concurrent."}]}')
  [ "$conflict" = 409 ]

  # A second, independent subscriber attaching mid-run must never see a 409
  # (streams never Reserve; any number of subscribers can join a live run).
  # The stream is durable and never closes itself, so curl always hits
  # --max-time and exits 28; `|| true` keeps that expected timeout from failing
  # the line while -w still captures the 200 status line received up front.
  local concurrent_stream_status
  concurrent_stream_status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 \
    "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/stream?cursor=0" \
    -H "Authorization: $USER_TOKEN" || true)
  [ "$concurrent_stream_status" = 200 ]

  local cancelled
  cancelled=$(curl -fsS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/session/cancel" \
    -H "Authorization: $USER_TOKEN")
  [ "$cancelled" = 202 ]
  wait_for_finish
}

@test "set_mode dispatches to Goose mid-run" {
  new_chat
  open_stream
  start_run "Invoke the shell tool immediately. Execute exactly: sleep 20. Do not ask a question, explain, or reply with text before the tool call."
  wait_for_approval

  local set_mode_status
  set_mode_status=$(curl -sS -o /dev/null -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/session/set-mode" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"modeId":"approve"}')
  [ "$set_mode_status" = 202 ]

  submit_option allow_once
  wait_for_finish
}

@test "c1 restart resolves pending work and same chat reloads; c2 restart reloads session" {
  new_chat
  open_stream
  start_run "Invoke the shell tool immediately. Execute exactly: printf pending-c1-restart. Do not ask a question, explain, or reply with text before the tool call."
  wait_for_approval
  local old_approval
  old_approval="$APPROVAL_ID"
  docker restart "$POCKETBASE_CONTAINER" >/dev/null
  wait_for_pocketbase
  # Docker reports the container started before PocketBase has finished
  # replacing its listener. wait_for_pocketbase requires three healthy polls.
  # Let the old stream curl observe the restart before reusing its capture
  # path. Otherwise its connection-refused diagnostic can race into the
  # follow-up run's file and hide the same-chat recovery result.
  if [ -n "${STREAM_PID:-}" ]; then
    wait "$STREAM_PID" 2>/dev/null || true
    unset STREAM_PID
  fi
  local stale_status
  stale_status=$(curl -sS -o "$BATS_TEST_TMPDIR/stale.json" -w '%{http_code}' \
    -X POST "$PB_URL/api/pocketcoder/v1/chats/$CHAT_ID/session/request-permission/$old_approval" \
    -H "Authorization: $USER_TOKEN" -H 'Content-Type: application/json' \
    -d '{"outcome":{"outcome":"selected","optionId":"allow_once"}}')
  [ "$stale_status" = 404 ]

  # This must use the original chat. A c1 restart cannot leave its Goose
  # request_permission blocked indefinitely after the in-memory ID is gone.
  # The reloaded session carries the prior shell-tool context, so a real model
  # tends to re-invoke the tool and stall on a fresh permission prompt. Rather
  # than fight that bias with "reply as text" (which the model ignores on
  # reload, making the assertion flaky), drive a tool run and resolve whatever
  # prompt appears: reaching RUN_FINISHED on the same chat IS the recovery.
  open_stream
  start_run "Invoke the shell tool and run exactly: printf same-chat-after-c1-restart"
  resolve_permissions_until_finish allow_once
  docker restart "$GOOSE_CONTAINER" >/dev/null
  wait_for_goose
  open_stream
  start_run "Invoke the shell tool and run exactly: printf after-c2-restart"
  resolve_permissions_until_finish allow_once
}
