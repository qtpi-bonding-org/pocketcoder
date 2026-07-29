#!/bin/sh
# Fetches and prints the full log of the most recent "Build NixOS Image"
# GitHub Actions run. Reads GH_TOKEN from the environment (injected by the
# secrets-daemon via `sops exec-env` -- never read from a file here, never
# echoed).
set -eu

API="https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions"
AUTH="Authorization: Bearer $GH_TOKEN"

RUNS_JSON=$(curl -sf -H "$AUTH" "$API/workflows/nixos-image.yml/runs?per_page=1")
RUN_ID=$(printf '%s' "$RUNS_JSON" | grep -o '"id":[[:space:]]*[0-9]*' | head -1 | tr -dc '0-9')

if [ -z "$RUN_ID" ]; then
  echo "ERROR: could not extract a run id. Raw API response:" >&2
  printf '%s\n' "$RUNS_JSON" >&2
  exit 1
fi
echo "=== run $RUN_ID ==="

ZIP="/tmp/pocketcoder-ci-run.zip"
LOGDIR="/tmp/pocketcoder-ci-log"
curl -sfL -H "$AUTH" "$API/runs/$RUN_ID/logs" -o "$ZIP"

rm -rf "$LOGDIR"
mkdir -p "$LOGDIR"
cd "$LOGDIR"
unzip -q "$ZIP"
cat ./*/*.txt 2>/dev/null || cat ./*.txt
