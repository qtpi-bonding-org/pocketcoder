#!/usr/bin/env bash
# Deploys every workers/* Cloudflare Worker in sequence. Each worker stays
# an independent deploy (own wrangler.toml, own secrets) — this only saves
# running `npm run deploy` three times by hand after a shared change.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for worker_dir in "$repo_root"/workers/*/; do
  name="$(basename "$worker_dir")"
  echo "==> Deploying $name"
  (cd "$worker_dir" && npm run deploy)
done

echo "==> All workers deployed"
