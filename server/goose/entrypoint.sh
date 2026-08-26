#!/bin/sh
set -eu

: "${GOOSE_SERVER__SECRET_KEY:?GOOSE_SERVER__SECRET_KEY is required}"

# Account-scoped provider keys may be stored beside Goose's durable config under
# GOOSE_PATH_ROOT. Provider environment variables rendered by PocketBase remain
# the normal path; this optional file keeps account-based configuration usable.
GOOSE_KEYS_ENV="${GOOSE_PATH_ROOT:-/workspace/.pocketcoder_auth}/config/keys.env"
if [ -r "$GOOSE_KEYS_ENV" ]; then
  set -a
  . "$GOOSE_KEYS_ENV"
  set +a
fi
if [ -r "$GOOSE_KEYS_ENV" ] && ! grep -qE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=' "$GOOSE_KEYS_ENV"; then
  echo "WARNING: $GOOSE_KEYS_ENV was read but contains no KEY=VALUE assignments" >&2
fi

# Do not maintain a second provider allowlist here. Goose owns provider
# discovery and validation; this wrapper must not reject providers that Goose
# supports (for example openrouter, openai, google, or future additions).
# Provider credentials and provider-specific settings arrive through the
# rendered keys.env or the container environment and are validated by Goose.

exec /usr/local/bin/goose serve --host 0.0.0.0 --port 3000
