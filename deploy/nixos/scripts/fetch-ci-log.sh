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
RUN_STATUS=$(printf '%s' "$RUNS_JSON" | jq -r '.workflow_runs[0].status // "unknown"')
RUN_CONCLUSION=$(printf '%s' "$RUNS_JSON" | jq -r '.workflow_runs[0].conclusion // "pending"')
echo "=== run $RUN_ID status=$RUN_STATUS conclusion=$RUN_CONCLUSION ==="
JOBS_JSON=$(curl --http1.1 -sS -f -H "$AUTH" "$API/runs/$RUN_ID/jobs?per_page=100")
printf '%s' "$JOBS_JSON" | jq -r '.jobs[] | "job=\(.name) status=\(.status) conclusion=\(.conclusion // "pending")"'
if [ "$RUN_STATUS" != "completed" ]; then
  exit 0
fi

for JOB_NAME in docker-images promote; do
  JOB_ID=$(printf '%s' "$JOBS_JSON" | jq -r --arg name "$JOB_NAME" '.jobs[] | select(.name == $name) | .id' | head -1)
  if [ -z "$JOB_ID" ]; then
    echo "=== $JOB_NAME job not found ==="
    continue
  fi

  ZIP="/tmp/pocketcoder-ci-$JOB_NAME.zip"
  LOGDIR="/tmp/pocketcoder-ci-$JOB_NAME-log"
  curl --http1.1 -sS -fL -H "$AUTH" "$API/jobs/$JOB_ID/logs" -o "$ZIP"
  echo "=== $JOB_NAME log tail ==="
  if unzip -tq "$ZIP" >/dev/null 2>&1; then
    rm -rf "$LOGDIR"
    mkdir -p "$LOGDIR"
    cd "$LOGDIR"
    unzip -q "$ZIP"
    (cat ./*/*.txt 2>/dev/null || cat ./*.txt) | tail -300
  else
    tail -300 "$ZIP"
  fi
done
