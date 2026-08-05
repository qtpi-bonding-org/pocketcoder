#!/bin/sh
# Real, scripted test of push-relay's monetization tollbooth: the
# RevenueCat subscription gate, the Supabase daily-quota gate, and (if
# FCM_TEST_TOKEN is set) a real FCM v1 send. No mocks -- every call in
# this script hits the real deployed Worker plus the real RevenueCat and
# Supabase APIs.
#
# Reads every secret from the environment (populate a gitignored .env
# from .env.template and `set -a; . ./.env; set +a` before running --
# never hardcode a real value here).
#
# Required:
#   PN_RELAY_SECRET        base secret used to derive the per-user relay secret
#   REVENUECAT_SECRET_KEY  RevenueCat V2 secret API key (sk_...)
#   REVENUECAT_PROJECT_ID  RevenueCat project id (proj...)
#   SUPABASE_URL           e.g. https://xxx.supabase.co
#   SUPABASE_SERVICE_KEY   Supabase service_role key
#
# Optional:
#   FCM_TEST_TOKEN         a real FCM device/registration token (see
#                          get-fcm-test-token.html) -- Stage 3 is skipped
#                          without it, since no CLI/API can mint one.
#   DAILY_PUSH_LIMIT       must match the limit configured on the deployed
#                          Worker (defaults to 1000, push-relay's default).
set -eu

PUSH_RELAY_URL="${PUSH_RELAY_URL:-https://push.relay.pocketcoder.org}"
export PUSH_RELAY_URL
: "${PN_RELAY_SECRET:?}"
: "${REVENUECAT_SECRET_KEY:?}"
: "${REVENUECAT_PROJECT_ID:?}"
: "${SUPABASE_URL:?}"
: "${SUPABASE_SERVICE_KEY:?}"
DAILY_PUSH_LIMIT="${DAILY_PUSH_LIMIT:-1000}"
# Must match PREMIUM_LOOKUP_KEY in src/index.js -- the RevenueCat
# entitlement identifier the deployed Worker checks against.
export PREMIUM_LOOKUP_KEY="${PREMIUM_LOOKUP_KEY:-PocketCoder Pro}"

RUN_ID=$(date +%s)
GRANTED_ENTITLEMENTS_FILE=$(mktemp)
FAIL=0

cleanup() {
  # Revoke any promotional entitlements this run granted, regardless of
  # how the script exits -- this test must never leave a throwaway test
  # user permanently "subscribed" in RevenueCat.
  if [ -s "$GRANTED_ENTITLEMENTS_FILE" ]; then
    while IFS='|' read -r user_id entitlement_id; do
      echo "Cleanup: revoking $entitlement_id from $user_id"
      curl -sS -f --retry 3 --retry-delay 2 --retry-all-errors -X POST \
        "https://api.revenuecat.com/v2/projects/${REVENUECAT_PROJECT_ID}/customers/${user_id}/actions/revoke_granted_entitlement" \
        -H "Authorization: Bearer ${REVENUECAT_SECRET_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"entitlement_id\":\"${entitlement_id}\"}" >/dev/null || \
        echo "  (revoke failed -- may need manual cleanup in the RevenueCat dashboard)"
    done < "$GRANTED_ENTITLEMENTS_FILE"
  fi
  rm -f "$GRANTED_ENTITLEMENTS_FILE"
}
trap cleanup EXIT

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1"; FAIL=1; }

# ---------------------------------------------------------------------------
# Helper: resolve the "premium" entitlement's internal id (lookup_key !=
# id in the V2 API -- grant/revoke need the internal id).
# ---------------------------------------------------------------------------
resolve_premium_entitlement_id() {
  body_file=$(mktemp)
  code=$(curl -sS -o "$body_file" -w '%{http_code}' --retry 3 --retry-delay 2 --retry-all-errors \
    "https://api.revenuecat.com/v2/projects/${REVENUECAT_PROJECT_ID}/entitlements" \
    -H "Authorization: Bearer ${REVENUECAT_SECRET_KEY}")
  if [ "$code" != "200" ]; then
    echo "RevenueCat GET /entitlements failed: HTTP $code: $(cat "$body_file")" >&2
    rm -f "$body_file"
    return 1
  fi
  python3 -c "import json,sys,os; d=json.load(sys.stdin); print(next(e['id'] for e in d['items'] if e['lookup_key']==os.environ['PREMIUM_LOOKUP_KEY']))" < "$body_file"
  rc=$?
  rm -f "$body_file"
  return $rc
}

create_customer_if_needed() {
  user_id="$1"
  body_file=$(mktemp)
  code=$(curl -sS -o "$body_file" -w '%{http_code}' --retry 3 --retry-delay 2 --retry-all-errors -X POST \
    "https://api.revenuecat.com/v2/projects/${REVENUECAT_PROJECT_ID}/customers" \
    -H "Authorization: Bearer ${REVENUECAT_SECRET_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"${user_id}\"}")
  # 201 = created, 409 = already exists (fine, idempotent from this
  # script's point of view -- every other code is a real failure).
  if [ "$code" != "201" ] && [ "$code" != "409" ]; then
    echo "create_customer failed for $user_id: HTTP $code: $(cat "$body_file")" >&2
    rm -f "$body_file"
    return 1
  fi
  rm -f "$body_file"
}

grant_premium() {
  user_id="$1"
  create_customer_if_needed "$user_id"
  expires_at_ms=$(( ($(date +%s) + 3600) * 1000 ))
  body_file=$(mktemp)
  code=$(curl -sS -o "$body_file" -w '%{http_code}' --retry 3 --retry-delay 2 --retry-all-errors -X POST \
    "https://api.revenuecat.com/v2/projects/${REVENUECAT_PROJECT_ID}/customers/${user_id}/actions/grant_entitlement" \
    -H "Authorization: Bearer ${REVENUECAT_SECRET_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"entitlement_id\":\"${PREMIUM_ENTITLEMENT_ID}\",\"expires_at\":${expires_at_ms}}")
  if [ "$code" != "201" ] && [ "$code" != "200" ]; then
    echo "grant_entitlement failed for $user_id: HTTP $code: $(cat "$body_file")" >&2
    rm -f "$body_file"
    return 1
  fi
  rm -f "$body_file"
  echo "${user_id}|${PREMIUM_ENTITLEMENT_ID}" >> "$GRANTED_ENTITLEMENTS_FILE"
}

call_push_relay() {
  user_id="$1"
  token="$2"
  curl -s -o /tmp/push-relay-resp.json -w '%{http_code}' -X POST "$PUSH_RELAY_URL" \
    -H "X-Relay-Secret: ${PN_RELAY_SECRET}-${user_id}" \
    -H "Content-Type: application/json" \
    -d "{\"token\":\"${token}\",\"user_id\":\"${user_id}\",\"service\":\"fcm\",\"title\":\"test\",\"message\":\"test\",\"type\":\"general\"}"
}

echo "=== Resolving RevenueCat 'premium' entitlement id ==="
PREMIUM_ENTITLEMENT_ID=$(resolve_premium_entitlement_id)
if [ -z "$PREMIUM_ENTITLEMENT_ID" ]; then
  fail "could not resolve the 'premium' entitlement -- has it been created in the RevenueCat dashboard?"
  exit 1
fi
echo "premium entitlement id: $PREMIUM_ENTITLEMENT_ID"

# ---------------------------------------------------------------------------
# Stage 1: RevenueCat subscription gate
# ---------------------------------------------------------------------------
echo ""
echo "=== Stage 1: RevenueCat subscription gate ==="

USER_NOSUB="push-relay-test-nosub-${RUN_ID}"
code=$(call_push_relay "$USER_NOSUB" "fake-token-unsubscribed")
if [ "$code" = "403" ] && grep -q NOT_SUBSCRIBED /tmp/push-relay-resp.json; then
  pass "unsubscribed user is rejected (403 NOT_SUBSCRIBED)"
else
  fail "unsubscribed user expected 403 NOT_SUBSCRIBED, got HTTP $code: $(cat /tmp/push-relay-resp.json)"
fi

USER_SUB="push-relay-test-sub-${RUN_ID}"
grant_premium "$USER_SUB"
code=$(call_push_relay "$USER_SUB" "fake-token-subscribed")
echo "  (subscribed-user call: HTTP $code, body: $(cat /tmp/push-relay-resp.json))"
if [ "$code" != "403" ]; then
  pass "subscribed user passes the RevenueCat gate (HTTP $code, not 403)"
else
  fail "subscribed user was rejected: $(cat /tmp/push-relay-resp.json)"
fi

# ---------------------------------------------------------------------------
# Stage 2: Supabase daily quota gate
# ---------------------------------------------------------------------------
echo ""
echo "=== Stage 2: Supabase daily quota gate ==="

QUOTA_USER="push-relay-test-quota-${RUN_ID}"

increment_quota_direct() {
  body_file=$(mktemp)
  code=$(curl -sS -o "$body_file" -w '%{http_code}' --retry 2 --retry-delay 1 --retry-all-errors -X POST "${SUPABASE_URL}/rest/v1/rpc/increment_push" \
    -H "apikey: ${SUPABASE_SERVICE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_SERVICE_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"p_user_id\":\"${QUOTA_USER}\"}")
  if [ "$code" != "200" ]; then
    echo "increment_push failed: HTTP $code: $(cat "$body_file")" >&2
    rm -f "$body_file"
    return 1
  fi
  cat "$body_file"
  rm -f "$body_file"
}

count=$(increment_quota_direct)
if [ "$count" = "1" ]; then
  pass "increment_push starts a fresh user at count 1"
else
  fail "increment_push expected 1 for a fresh user, got: $count"
fi

echo "Driving $QUOTA_USER to the daily limit directly against Supabase ($DAILY_PUSH_LIMIT calls)..."
i=1
while [ "$i" -lt "$DAILY_PUSH_LIMIT" ]; do
  increment_quota_direct >/dev/null
  i=$((i + 1))
done
final_count=$(increment_quota_direct)
if [ "$final_count" -gt "$DAILY_PUSH_LIMIT" ]; then
  pass "increment_push is atomic and reaches $final_count > limit $DAILY_PUSH_LIMIT"
else
  fail "expected count > $DAILY_PUSH_LIMIT after $((DAILY_PUSH_LIMIT + 1)) increments, got $final_count"
fi

grant_premium "$QUOTA_USER"
code=$(call_push_relay "$QUOTA_USER" "fake-token-over-quota")
if [ "$code" = "429" ] && grep -q 'Daily push limit exceeded' /tmp/push-relay-resp.json; then
  pass "worker enforces the same quota table (429 Daily push limit exceeded)"
else
  fail "expected 429 Daily push limit exceeded for a user already over quota, got HTTP $code: $(cat /tmp/push-relay-resp.json)"
fi

# ---------------------------------------------------------------------------
# Stage 3: real FCM send (only with a real device token)
# ---------------------------------------------------------------------------
echo ""
echo "=== Stage 3: real FCM send ==="

if [ -z "${FCM_TEST_TOKEN:-}" ]; then
  echo "SKIPPED: FCM_TEST_TOKEN not set. Open scripts/get-fcm-test-token.html in a"
  echo "browser to mint one, then re-run with FCM_TEST_TOKEN=<token>."
else
  FCM_USER="push-relay-test-fcm-${RUN_ID}"
  grant_premium "$FCM_USER"
  code=$(call_push_relay "$FCM_USER" "$FCM_TEST_TOKEN")
  if [ "$code" = "200" ] && python3 -c "import json;d=json.load(open('/tmp/push-relay-resp.json'));exit(0 if d.get('success') and d.get('fcm_message_name') else 1)"; then
    pass "real FCM send succeeded: $(cat /tmp/push-relay-resp.json)"
  else
    fail "expected a successful FCM send, got HTTP $code: $(cat /tmp/push-relay-resp.json)"
  fi
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo "=== ALL STAGES PASSED ==="
else
  echo "=== ONE OR MORE STAGES FAILED ==="
  exit 1
fi
