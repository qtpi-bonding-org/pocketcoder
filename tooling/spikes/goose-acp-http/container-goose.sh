#!/usr/bin/env bash
set -euo pipefail

# Runs the pinned Goose image as the stdio child process consumed by main.go.
# It reads the user-provided auth file inside this wrapper and never logs its key.

auth_file="${MINIMAX_AUTH_FILE:?set MINIMAX_AUTH_FILE to the local gait auth.json path}"
api_key="$(jq -er '.minimax.key' "${auth_file}")"
state_volume="${GOOSE_SPIKE_VOLUME:-pocketcoder-goose-acp-spike-state}"

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
  ghcr.io/block/goose@sha256:d85a724ee487425f38ce015323adf2003591268ee515d9018ac89450ed7d3a5a \
  "$@"
