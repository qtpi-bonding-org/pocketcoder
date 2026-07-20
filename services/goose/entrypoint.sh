#!/bin/sh
set -eu

: "${GOOSE_SERVER__SECRET_KEY:?GOOSE_SERVER__SECRET_KEY is required}"

# App-managed provider keys (rendered by PocketBase onto the shared goose_config
# volume, which is mounted at Goose's config dir: $GOOSE_PATH_ROOT/config, spec
# §13.1). Sourced before provider validation so ANTHROPIC_API_KEY etc. are
# present in the goose process. Guarded so set -e cannot abort on a missing or
# unreadable file at cold boot, before PocketBase has rendered the first set.
GOOSE_KEYS_ENV="${GOOSE_PATH_ROOT:-/goose}/config/keys.env"
if [ -r "$GOOSE_KEYS_ENV" ]; then
  set -a
  . "$GOOSE_KEYS_ENV"
  set +a
fi

# The pinned c2 image has only the provider used in the verified spike. Do not
# silently accept a provider that would cause Goose to spawn an unchecked host
# binary or fall back to a different tool policy.
case "${GOOSE_PROVIDER:-anthropic}" in
  anthropic)
    : "${ANTHROPIC_API_KEY:?ANTHROPIC_API_KEY is required for GOOSE_PROVIDER=anthropic}"
    ;;
  *)
    echo "unsupported GOOSE_PROVIDER: ${GOOSE_PROVIDER}" >&2
    exit 64
    ;;
esac

exec /usr/local/bin/goose serve --host 0.0.0.0 --port 3000
