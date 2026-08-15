#!/usr/bin/env bash
# Real Docker integration coverage for the local Ollama path. This is opt-in:
# it downloads a model and performs CPU inference, so it does not belong in
# ordinary unit-test or release-image CI.
set -euo pipefail

: "${GOOSE_SERVER__SECRET_KEY:?set the Goose ACP secret}"

model="${OLLAMA_SMOKE_MODEL:-qwen2.5:0.5b}"
timeout="${OLLAMA_SMOKE_TIMEOUT_SECONDS:-300}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$root"

GOOSE_PROVIDER=ollama GOOSE_MODEL="$model" docker compose \
  -f docker-compose.yml -f docker-compose.agent-test.yml \
  --profile agent-test up -d --build ollama goose

for _ in $(seq 1 30); do
  [ "$(docker inspect --format '{{.State.Health.Status}}' pocketcoder-ollama)" = healthy ] && break
  sleep 1
done
[ "$(docker inspect --format '{{.State.Health.Status}}' pocketcoder-ollama)" = healthy ]

docker exec pocketcoder-ollama ollama pull "$model"
docker volume create pocketcoder-live-go-cache >/dev/null
docker volume create pocketcoder-live-go-build-cache >/dev/null

# Drive the production ACP coordinator from an isolated container on the
# private agent network. The selected model is applied through Goose's live
# ACP config-option path, exactly as a chat-specific harness model is.
GOOSE_SERVER__SECRET_KEY="$(docker exec pocketcoder-goose printenv GOOSE_SERVER__SECRET_KEY)" \
docker run --rm --network pocketcoder-agent \
  -v "$root/server/pocketbase:/src:ro" \
  -v pocketcoder-live-go-cache:/go \
  -v pocketcoder-live-go-build-cache:/tmp/go-build \
  -w /src \
  -e GOOSE_ACP_URL=ws://goose:3000/acp \
  -e GOOSE_SERVER__SECRET_KEY \
  -e GOOSE_WORKSPACE=/workspace \
  -e GOOSE_LIVE_PROVIDER=ollama \
  -e GOOSE_LIVE_MODEL="$model" \
  -e GOOSE_LIVE_TIMEOUT_SECONDS="$timeout" \
  -e GOCACHE=/tmp/go-build \
  golang:1.24.4-alpine \
  sh -c 'go test -tags live_acp ./internal/agent/coordinator -run TestLiveRunNewSession -count=1 -v'
