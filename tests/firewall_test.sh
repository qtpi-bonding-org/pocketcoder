#!/bin/bash
# �� POCKETCODER FIREWALL & LEDGER TEST
# This script verifies the Execution Firewall and Sovereignty Ledger.

set -e

# Load Secrets from current directory .env if available
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ${NC} $1"; }
log_success() { echo -e "${GREEN}✅${NC} $1"; }
log_error() { echo -e "${RED}❌${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠️${NC} $1"; }

# Check Dependencies
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed."
    exit 1
fi

POCKETBASE_URL="http://localhost:8090"
AGENT_EMAIL="agent@pocketcoder.local"
[ -z "$AGENT_PASSWORD" ] && AGENT_PASSWORD=$(docker exec pocketcoder-pocketbase env | grep AGENT_PASSWORD | cut -d= -f2)
[ -z "$ADMIN_EMAIL" ] && ADMIN_EMAIL="admin@pocketcoder.local"
[ -z "$ADMIN_PASSWORD" ] && ADMIN_PASSWORD=$(docker exec pocketcoder-pocketbase env | grep ADMIN_PASSWORD | cut -d= -f2)

log_info "Authenticating as Agent for monitoring..."
AUTH_RES=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$AGENT_EMAIL\", \"password\":\"$AGENT_PASSWORD\"}")
TOKEN=$(echo "$AUTH_RES" | jq -r .token)

log_info "Authenticating as Admin for setup..."
ADMIN_AUTH=$(curl -s -X POST "$POCKETBASE_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASSWORD\"}")
ADMIN_TOKEN=$(echo "$ADMIN_AUTH" | jq -r .token)

if [ "$ADMIN_TOKEN" == "null" ]; then
    log_warn "Superuser auth failed, trying regular user auth as admin..."
    ADMIN_AUTH=$(curl -s -X POST "$POCKETBASE_URL/api/collections/users/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"$ADMIN_EMAIL\", \"password\":\"$ADMIN_PASSWORD\"}")
    ADMIN_TOKEN=$(echo "$ADMIN_AUTH" | jq -r .token)
fi

# --- STAGE 1: DIRECT BASH HIJACK ---
log_info "STAGE 1: Direct Bash Hijack Verification"
HIJACK_SIGNAL="HIJACK_SIGNAL_$(date +%s)"
docker exec pocketcoder-opencode /bin/bash -c "echo $HIJACK_SIGNAL" > /dev/null 2>&1
sleep 2
PANES=$(docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder capture-pane -p -t pocketcoder_session.0)

if echo "$PANES" | grep -q "$HIJACK_SIGNAL"; then
    log_success "Bash hijacked correctly (intercepted and sent to sandbox)."
else
    log_error "Bash hijack failed. Signal not found in Sandbox."
    exit 1
fi

# --- STAGE 2: OPENCODE RUN HIJACK & USAGE ---
log_info "STAGE 2: OpenCode 'run bash' & Usage Linking"
USAGE_SIGNAL="USAGE_SIGNAL_$(date +%s)"

# Explicitly whitelist the test command
TEST_CMD="echo $USAGE_SIGNAL > usage_test.txt"
log_info "Whitelisting command: $TEST_CMD"

# 1. Ensure command exists
CMD_ID=$(curl -s -X POST "$POCKETBASE_URL/api/collections/commands/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d "{\"command\":\"$TEST_CMD\"}" | jq -r .id)
if [ "$CMD_ID" == "null" ] || [ -z "$CMD_ID" ]; then
    CMD_ID=$(curl -s "$POCKETBASE_URL/api/collections/commands/records?filter=(command='$TEST_CMD')" \
        -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.items[0].id')
fi

# 2. Add to whitelist
curl -s -X POST "$POCKETBASE_URL/api/collections/whitelists/records" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d "{\"command\":\"$CMD_ID\", \"active\":true}" > /dev/null

log_info "Triggering OpenCode turn..."
docker exec pocketcoder-opencode opencode run "run bash command: $TEST_CMD" --attach http://localhost:4096 --thinking > /dev/null 2>&1 &
OP_PID=$!

log_info "Waiting for usage record creation..."
USAGE_ID=""
for i in {1..20}; do
    USAGE_REC=$(curl -s "$POCKETBASE_URL/api/collections/usages/records?perPage=1&page=1" -H "Authorization: Bearer $TOKEN")
    TOTAL=$(echo "$USAGE_REC" | jq -r '.totalItems // 0')
    if [ "$TOTAL" -gt 0 ]; then
        STATUS=$(echo "$USAGE_REC" | jq -r '.items[0].status')
        if [ "$STATUS" == "in-progress" ]; then
            USAGE_ID=$(echo "$USAGE_REC" | jq -r '.items[0].id')
            log_info "Found Usage: $USAGE_ID (Status: $STATUS)"
            break
        fi
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ -z "$USAGE_ID" ]; then
    log_error "No usage record created after polling."
    exit 1
fi

log_info "Waiting for execution record linking..."
EXEC_ID=""
for i in {1..20}; do
    EXEC_REC=$(curl -s "$POCKETBASE_URL/api/collections/executions/records?filter=(usage='$USAGE_ID')" -H "Authorization: Bearer $TOKEN")
    TOTAL=$(echo "$EXEC_REC" | jq -r '.totalItems // 0')
    if [ "$TOTAL" -gt 0 ]; then
        EXEC_ID=$(echo "$EXEC_REC" | jq -r '.items[0].id')
        log_success "Execution record successfully linked: $EXEC_ID"
        
        # Verify Permission linkage
        PERM_ID=$(echo "$EXEC_REC" | jq -r '.items[0].permission // ""')
        if [ -n "$PERM_ID" ]; then
            PERM_REC=$(curl -s "$POCKETBASE_URL/api/collections/permissions/records/$PERM_ID" -H "Authorization: Bearer $TOKEN")
            PERM_STATUS=$(echo "$PERM_REC" | jq -r '.status // "unknown"')
            log_success "Permission record found: $PERM_ID (Status: $PERM_STATUS)"
            if [ "$PERM_STATUS" != "authorized" ]; then
                log_error "Permission status is $PERM_STATUS, expected authorized!"
                exit 1
            fi
        else
            log_error "Execution record $EXEC_ID has no permission link!"
            exit 1
        fi
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

log_info "Waiting for turn completion and token sync..."
wait $OP_PID || true

FINAL_USAGE=""
for i in {1..20}; do
    FINAL_USAGE=$(curl -s "$POCKETBASE_URL/api/collections/usages/records/$USAGE_ID" -H "Authorization: Bearer $TOKEN")
    STATUS=$(echo "$FINAL_USAGE" | jq -r '.status // "unknown"')
    if [ "$STATUS" == "completed" ] || [ "$STATUS" == "error" ]; then
        log_success "Usage record reached terminal state: $STATUS"
        P_TOKENS=$(echo "$FINAL_USAGE" | jq -r '.tokens_prompt // 0')
        C_TOKENS=$(echo "$FINAL_USAGE" | jq -r '.tokens_completion // 0')
        log_success "Sovereign Ledger Audit: $P_TOKENS prompt, $C_TOKENS completion tokens logged."
        break
    fi
    echo -n "."
    sleep 3
done
echo ""

echo ""
echo "✨ FIREWALL & LEDGER TESTS PASSED! ✨"
echo "Usage Audit: $POCKETBASE_URL/_/#/collections/usages/records?id=$USAGE_ID"
