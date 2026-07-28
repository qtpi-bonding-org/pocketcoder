#!/bin/sh
# Sets mcp-oauth-relay's wrangler secrets from env vars already present in
# this process's environment (injected by the secrets-daemon via `sops
# exec-env` — never read from a file here, never echoed).
set -eu
cd "$(dirname "$0")/.."

for name in GITHUB_OAUTH_CLIENT_ID GITHUB_OAUTH_CLIENT_SECRET; do
  eval "value=\$$name"
  if [ -z "$value" ]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
  printf '%s' "$value" | npx wrangler secret put "$name"
done

echo "mcp-oauth-relay secrets set."
