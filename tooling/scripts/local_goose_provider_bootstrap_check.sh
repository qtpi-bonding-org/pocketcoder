#!/bin/sh
# Local, real-credential verification of the ProviderBootstrap fix:
# brings up a genuinely fresh goose fixture (docker-compose.agent-test.yml,
# no baked-in provider), runs the checked-in live_acp regression test
# (server/pocketbase/internal/agent/coordinator/live_test.go's
# TestLiveNewSessionBootstrapsProviderCredentialOnFreshContainer) with a
# real provider credential, and prints the actual assistant reply. Tears
# down and restores whatever local dev stack (docker-compose.yml, no
# profile) was running before it started, since the agent-test fixture's
# networks otherwise conflict with it.
set -eu

: "${REAL_PROVIDER_API_KEY:?REAL_PROVIDER_API_KEY must be set (injected by the secrets daemon)}"
PROVIDER_ID="${REAL_PROVIDER_ID:-openrouter}"
MODEL_ID="${REAL_PROVIDER_MODEL:-openrouter/auto}"
CREDENTIAL_FIELD_NAME="${REAL_PROVIDER_CREDENTIAL_FIELD_NAME:-OPENROUTER_API_KEY}"

cd "$(dirname "$0")/../.."

SECRET="$(grep -m1 '^GOOSE_SERVER__SECRET_KEY=' .env | cut -d= -f2-)"
if [ -z "$SECRET" ]; then
  echo "GOOSE_SERVER__SECRET_KEY not found in .env" >&2
  exit 1
fi

MAIN_STACK_WAS_UP=0
if docker compose ps -q 2>/dev/null | grep -q .; then
  MAIN_STACK_WAS_UP=1
  echo "==> Tearing down the currently-running local dev stack (will restore at the end)"
  docker compose down
fi

cleanup() {
  echo "==> Cleaning up test fixture"
  docker rm -f goose-port-forward >/dev/null 2>&1 || true
  docker rm -f pocketcoder-goose >/dev/null 2>&1 || true
  docker volume rm pocketcoder_agent_test_goose_config pocketcoder_agent_test_goose_state >/dev/null 2>&1 || true
  if [ "$MAIN_STACK_WAS_UP" = "1" ]; then
    echo "==> Restoring the local dev stack"
    docker compose up -d
  fi
}
trap cleanup EXIT

echo "==> Bringing up a fresh goose fixture with GOOSE_PROVIDER set but no credential baked in"
# --env-file /dev/null: this repo's own .env carries real dev-convenience
# provider keys. Loading it here (compose's default) would give the
# container a real credential at boot -- not the virgin container this
# check needs. Explicit shell env vars below still take precedence over
# any file, so MCP_GATEWAY_AUTH_TOKEN etc. are unaffected. ANTHROPIC_API_KEY/
# OPENROUTER_API_KEY must NOT be assigned here (not even to ""): the compose
# file's bare pass-through only omits a var when it's truly absent, not when
# it's explicitly empty -- see the comment in docker-compose.agent-test.yml.
#
# GOOSE_PROVIDER/GOOSE_MODEL ARE set here, to the same provider/model the
# credential below is for -- matching a real production launch, where
# hooks.renderEnv always resolves GOOSE_PROVIDER to the user's actually-
# chosen provider before the container ever boots (session/new itself
# requires GOOSE_PROVIDER to resolve to something; leaving it fully unset
# makes session creation fail outright with "Failed to resolve provider").
# Setting it to a DIFFERENT, uncredentialed provider (an earlier version of
# this script defaulted to a stale anthropic/minimax-proxy leftover) raced
# with goose's own session-activation code and produced flaky, unrelated
# "Provider not set" failures -- not a real regression, just a mismatched
# fixture default that doesn't occur in production.
MCP_GATEWAY_AUTH_TOKEN=dummy AGENT_TEST_EMAIL=test@example.com AGENT_TEST_PASSWORD=dummy-pass-123 \
  API_TEST_EMAIL=test@example.com API_TEST_PASSWORD=dummy-pass-123 \
  GOOSE_SERVER__SECRET_KEY="$SECRET" \
  GOOSE_PROVIDER="$PROVIDER_ID" GOOSE_MODEL="$MODEL_ID" \
  docker compose --env-file /dev/null -f docker-compose.yml -f docker-compose.agent-test.yml --profile agent-test \
  up -d --force-recreate -V goose

for i in $(seq 1 20); do
  h=$(docker inspect --format '{{.State.Health.Status}}' pocketcoder-goose 2>/dev/null || echo "")
  if [ "$h" = "healthy" ]; then
    break
  fi
  sleep 3
done
if [ "$h" != "healthy" ]; then
  echo "goose fixture never became healthy" >&2
  docker logs pocketcoder-goose 2>&1 | tail -50
  exit 1
fi

echo "==> Starting a temporary port-forward to the goose ACP endpoint"
docker run -d --rm --name goose-port-forward --network pocketcoder-agent \
  -p 127.0.0.1:3000:3000 alpine/socat tcp-listen:3000,fork,reuseaddr tcp-connect:pocketcoder-goose:3000
sleep 1

echo "==> Running the live provider-bootstrap regression test with a real credential"
cd server/pocketbase
GOOSE_ACP_URL="ws://127.0.0.1:3000/acp" \
  GOOSE_SERVER__SECRET_KEY="$SECRET" \
  GOOSE_WORKSPACE=/workspace \
  GOOSE_LIVE_PROVIDER="$PROVIDER_ID" \
  GOOSE_LIVE_MODEL="$MODEL_ID" \
  GOOSE_LIVE_CREDENTIAL_FIELD_NAME="$CREDENTIAL_FIELD_NAME" \
  GOOSE_LIVE_CREDENTIAL_FIELD_VALUE="$REAL_PROVIDER_API_KEY" \
  GOOSE_LIVE_TIMEOUT_SECONDS=60 \
  /Users/aicoder/develop/tools/go/bin/go test -tags live_acp ./internal/agent/coordinator/ -run TestLiveNewSessionBootstrapsProviderCredentialOnFreshContainer -v
