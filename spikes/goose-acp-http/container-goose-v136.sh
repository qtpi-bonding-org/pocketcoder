#!/usr/bin/env bash
set -euo pipefail

# Same as container-goose.sh but pins the SELECTED c2 image (Goose v1.36.0,
# aaif-goose) to test the stdio session/load-across-process question directly
# against what production c2 runs.

auth_file="${MINIMAX_AUTH_FILE:?set MINIMAX_AUTH_FILE to the local gait auth.json path}"
api_key="$(jq -er '.minimax.key' "${auth_file}")"
state_volume="${GOOSE_SPIKE_VOLUME:-pocketcoder-goose-stdio-load-test}"

exec docker run --rm -i \
  --user root \
  --mount "type=bind,src=$(pwd),dst=/workspace" \
  --mount "type=volume,src=${state_volume},dst=/goose" \
  --workdir /workspace \
  -e GOOSE_DISABLE_KEYRING=1 \
  -e GOOSE_PATH_ROOT=/goose \
  -e GOOSE_TELEMETRY_ENABLED=false \
  -e GOOSE_PROVIDER=anthropic \
  -e "GOOSE_MODEL=${GOOSE_MODEL:-MiniMax-M2.5}" \
  -e "ANTHROPIC_API_KEY=${api_key}" \
  -e "ANTHROPIC_HOST=${ANTHROPIC_HOST:-https://api.minimax.io/anthropic}" \
  ghcr.io/aaif-goose/goose@sha256:8452dbb1aed8b46ec8b25895a1dd60a2e8ad89a10692f782cff32a6cbe35176e \
  "$@"
