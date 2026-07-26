#!/usr/bin/env bash
set -euo pipefail

# Validates goose serve's authenticated HTTP surface before a Go streamable-HTTP
# adapter is selected or written. It intentionally does not send ACP requests.

base_url="${GOOSE_URL:-http://127.0.0.1:3000}"
secret="${GOOSE_SERVER__SECRET_KEY:?set GOOSE_SERVER__SECRET_KEY}"

curl --fail --silent --show-error "${base_url}/status"
printf '\n'

status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' \
  --header 'Accept: text/event-stream' \
  --header "X-Secret-Key: ${secret}" \
  "${base_url}/acp")"

if [[ "${status}" == "401" || "${status}" == "403" ]]; then
  printf 'ACP authentication failed with HTTP %s\n' "${status}" >&2
  exit 1
fi

printf 'ACP endpoint authenticated (HTTP %s)\n' "${status}"
