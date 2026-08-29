#!/usr/bin/env bash
set -euo pipefail

# Set the secrets required by the image-relay Worker. Run from any directory
# with Wrangler authenticated to the target Cloudflare account.
for secret in SUPABASE_URL SUPABASE_SERVICE_KEY REVENUECAT_SECRET_KEY REVENUECAT_PROJECT_ID; do
  if [[ -z "${!secret:-}" ]]; then
    echo "Missing required environment variable: $secret" >&2
    exit 1
  fi
  printf '%s' "${!secret}" | npx wrangler secret put "$secret" --name pocketcoder-image-relay
 done

echo "Image-relay secrets updated."
