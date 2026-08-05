#!/bin/sh
# Integration test for push-relay's trust-on-first-use tenant binding.
set -eu

PUSH_RELAY_URL="${PUSH_RELAY_URL:-https://push.relay.pocketcoder.org}"
: "${SUPABASE_URL:?}"
: "${SUPABASE_SERVICE_KEY:?}"
RUN_ID=$(date +%s)
FAIL=0
pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

sha256_hex() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1; else shasum -a 256 | cut -d' ' -f1; fi; }

call_push_relay() {
	secret="$1"; user_id="$2"
	curl -s -o /tmp/push-relay-bind-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
		-H "X-Relay-Secret: ${secret}" -H 'Content-Type: application/json' \
		-d "{\"token\":\"fake-token\",\"user_id\":\"${user_id}\",\"service\":\"fcm\",\"title\":\"t\",\"message\":\"m\",\"type\":\"general\"}"
}

row_user_id_for_secret() {
	secret="$1"; hash=$(printf '%s' "$secret" | sha256_hex)
	curl -sS "${SUPABASE_URL}/rest/v1/relay_bindings?secret_hash=eq.${hash}&select=user_id" \
		-H "apikey: ${SUPABASE_SERVICE_KEY}" -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
		| python3 -c "import json,sys; d=json.load(sys.stdin); print(d[0]['user_id'] if d else '')"
}

echo '=== Stage 1: unifiedpush is gone ==='
code=$(curl -s -o /tmp/push-relay-bind-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
	-H "X-Relay-Secret: test-bind-unknown-${RUN_ID}" -H 'Content-Type: application/json' -d '{"token":"anything","service":"unifiedpush"}')
if [ "$code" = 400 ] && grep -q 'Unknown service' /tmp/push-relay-bind-resp.json; then pass 'unifiedpush is rejected'; else fail "expected 400 Unknown service, got $code: $(cat /tmp/push-relay-bind-resp.json)"; fi

SECRET_A="test-bind-a-${RUN_ID}"; USER_A="push-relay-test-bind-user-a-${RUN_ID}"; USER_B="push-relay-test-bind-user-b-${RUN_ID}"
echo '=== Stage 2: first use binds the secret ==='
code=$(call_push_relay "$SECRET_A" "$USER_A")
if grep -q 'another user' /tmp/push-relay-bind-resp.json; then fail "first use mismatched ($code)"; else pass "first use passes binding gate ($code)"; fi
bound=$(row_user_id_for_secret "$SECRET_A")
if [ "$bound" = "$USER_A" ]; then pass 'binding row created'; else fail "expected $USER_A, got $bound"; fi

echo '=== Stage 3: mismatched user is rejected ==='
code=$(call_push_relay "$SECRET_A" "$USER_B")
if [ "$code" = 403 ] && grep -q 'another user' /tmp/push-relay-bind-resp.json; then pass 'mismatch rejected'; else fail "expected 403 mismatch, got $code"; fi

echo '=== Stage 4: original user still works ==='
code=$(call_push_relay "$SECRET_A" "$USER_A")
if ! grep -q 'another user' /tmp/push-relay-bind-resp.json; then pass "original user accepted ($code)"; else fail 'original user rejected'; fi

echo '=== Stage 5: user_id is mandatory ==='
code=$(curl -s -o /tmp/push-relay-bind-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
	-H "X-Relay-Secret: test-bind-c-${RUN_ID}" -H 'Content-Type: application/json' -d '{"token":"anything","service":"fcm"}')
if [ "$code" = 400 ] && grep -q 'user_id is required' /tmp/push-relay-bind-resp.json; then pass 'missing user_id rejected'; else fail "expected mandatory user_id, got $code"; fi

echo '=== Stage 6: concurrent first use has one winner ==='
SECRET_RACE="test-bind-race-${RUN_ID}"; USER_R1="push-relay-test-bind-race-1-${RUN_ID}"; USER_R2="push-relay-test-bind-race-2-${RUN_ID}"
curl -s -o /dev/null -X POST "$PUSH_RELAY_URL" -H "X-Relay-Secret: ${SECRET_RACE}" -H 'Content-Type: application/json' -d "{\"token\":\"fake-token\",\"user_id\":\"${USER_R1}\",\"service\":\"fcm\"}" & pid1=$!
curl -s -o /dev/null -X POST "$PUSH_RELAY_URL" -H "X-Relay-Secret: ${SECRET_RACE}" -H 'Content-Type: application/json' -d "{\"token\":\"fake-token\",\"user_id\":\"${USER_R2}\",\"service\":\"fcm\"}" & pid2=$!
wait "$pid1"; wait "$pid2"
bound_race=$(row_user_id_for_secret "$SECRET_RACE")
if [ "$bound_race" = "$USER_R1" ] || [ "$bound_race" = "$USER_R2" ]; then pass "race resolved to $bound_race"; else fail "unexpected race binding: $bound_race"; fi

if [ "$FAIL" -eq 0 ]; then echo '=== ALL STAGES PASSED ==='; else echo '=== ONE OR MORE STAGES FAILED ==='; exit 1; fi
