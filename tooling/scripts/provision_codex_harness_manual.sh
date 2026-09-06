#!/bin/sh
# Docker Desktop's macOS file sharing does not preserve a single-file bind
# mount's content once the host-side path is deleted, so TMPFILE must stay
# at a fixed path for the container's lifetime, not a mktemp path removed
# after `docker run`.
set -eu

: "${TOKEN:?TOKEN must be set (injected by the secrets daemon)}"
: "${ACCESS_TOKEN:?ACCESS_TOKEN must be set (injected by the secrets daemon)}"
: "${REFRESH_TOKEN:?REFRESH_TOKEN must be set (injected by the secrets daemon)}"
: "${ACCOUNT_ID:?ACCOUNT_ID must be set (injected by the secrets daemon)}"

CONTAINER_NAME="pocketcoder-harness-codex-manual"
export TMPFILE="/tmp/pocketcoder-codex-manual-auth.json"
: > "$TMPFILE"
chmod 600 "$TMPFILE"

python3 -c '
import json, os
from datetime import datetime, timezone
json.dump({
    "OPENAI_API_KEY": None,
    "auth_mode": "chatgpt",
    "tokens": {
        "id_token": os.environ["TOKEN"],
        "access_token": os.environ["ACCESS_TOKEN"],
        "refresh_token": os.environ["REFRESH_TOKEN"],
        "account_id": os.environ["ACCOUNT_ID"],
    },
    "last_refresh": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
}, open(os.environ["TMPFILE"], "w"))
'

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
SECRET=$(openssl rand -hex 24)
docker run -d --name "$CONTAINER_NAME" \
  --network pocketcoder-agent \
  -e HARNESS_ADAPTER_SECRET="$SECRET" \
  -e POCKETCODER_HARNESS_CLI_ID=codex \
  -v "$TMPFILE:/root/.codex/auth.json:ro" \
  pocketcoder-harness-codex:1.1.9 --cmd codex-acp --port 3000
docker network connect pocketcoder-harness-egress "$CONTAINER_NAME"

: > /tmp/codex_secret.txt
chmod 600 /tmp/codex_secret.txt
echo "$SECRET" > /tmp/codex_secret.txt
echo "codex harness container started: $CONTAINER_NAME"
