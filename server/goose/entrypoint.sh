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

# Keep the accepted provider list explicit: a typo must fail at boot instead of
# making Goose choose an unintended backend. Ollama is an internal Compose
# service on the private model network, not a host port or external endpoint.
case "${GOOSE_PROVIDER:-anthropic}" in
  anthropic)
    : "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required for GOOSE_PROVIDER=anthropic}"
    ;;
  ollama)
    : "${OLLAMA_HOST:?OLLAMA_HOST is required for GOOSE_PROVIDER=ollama}"
    ;;
  *)
    echo "unsupported GOOSE_PROVIDER: ${GOOSE_PROVIDER}" >&2
    exit 64
    ;;
esac

exec /usr/local/bin/goose serve --host 0.0.0.0 --port 3000
