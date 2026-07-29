#!/bin/sh
# Verifies R2 S3-compatible credentials work by listing pocketcoder-images
# (read-only). Reads CLOUDFLARE_ACCOUNT_ID/R2_ACCESS_KEY_ID/
# R2_SECRET_ACCESS_KEY from the environment (injected by the
# secrets-daemon via `sops exec-env` -- never read from a file here, never
# echoed).
set -eu

VENV="$HOME/.local/share/pocketcoder-r2-venv"
if [ ! -x "$VENV/bin/python3" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet boto3
fi

exec "$VENV/bin/python3" "$(dirname "$0")/test_r2_creds.py"
