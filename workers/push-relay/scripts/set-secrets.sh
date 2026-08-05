#!/bin/sh
# Sets push-relay's wrangler secrets from env vars already present in this
# process's environment (injected by the secrets-daemon via `sops
# exec-env` — never read from a file here, never echoed).
set -eu
cd "$(dirname "$0")/.."

for name in REVENUECAT_SECRET_KEY REVENUECAT_PROJECT_ID FCM_PROJECT_ID FCM_CLIENT_EMAIL FCM_PRIVATE_KEY SUPABASE_URL SUPABASE_SERVICE_KEY; do
  eval "value=\$$name"
  if [ -z "$value" ]; then
    echo "Missing required env var: $name" >&2
    exit 1
  fi
  printf '%s' "$value" | npx wrangler secret put "$name"
done

echo "push-relay secrets set."
