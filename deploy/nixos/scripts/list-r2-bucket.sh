#!/bin/sh
# Lists every object in an R2 bucket (default: pocketcoder-images), full
# key + size + last-modified, no delimiter/folder collapsing. Reads
# CLOUDFLARE_ACCOUNT_ID/R2_ACCESS_KEY_ID/R2_SECRET_ACCESS_KEY from the
# environment (injected by the secrets-daemon via `sops exec-env` -- never
# read from a file here, never echoed). Reuses the same venv
# test-r2-creds.sh already sets up, since boto3 is already installed there.
set -eu

VENV="$HOME/.local/share/pocketcoder-r2-venv"
if [ ! -x "$VENV/bin/python3" ]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet boto3
fi

exec "$VENV/bin/python3" "$(dirname "$0")/list_r2_bucket.py" "$@"
