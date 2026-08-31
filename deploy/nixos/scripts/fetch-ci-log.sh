#!/bin/sh
# Fetches and prints a short summary of the last few "Build NixOS Image"
# GitHub Actions runs (id, commit, status), then the full log of the most
# recent one. The summary exists so an agent can tell its own dispatched
# run apart from a concurrent one from another agent/process (there is no
# way to query a specific run id directly -- this is the workaround: match
# by commit sha instead). Reads GH_TOKEN from the environment (injected by
# the secrets-daemon via `sops exec-env` -- never read from a file here,
# never echoed).
set -eu

API="https://api.github.com/repos/qtpi-bonding-org/pocketcoder/actions"
AUTH="Authorization: Bearer $GH_TOKEN"

WORKFLOW=${POCKETCODER_CI_WORKFLOW:-nixos-image.yml}
RECENT_COUNT=${POCKETCODER_CI_RECENT_COUNT:-5}
RUNS_JSON=$(curl -sf -H "$AUTH" "$API/workflows/$WORKFLOW/runs?per_page=$RECENT_COUNT")

echo "=== last $RECENT_COUNT runs (newest first) ==="
printf '%s' "$RUNS_JSON" | jq -r \
  '.workflow_runs[] | "run \(.id) sha=\(.head_sha[0:12]) status=\(.status) conclusion=\(.conclusion // "pending")"'

RUN_ID=$(printf '%s' "$RUNS_JSON" | jq -r '.workflow_runs[0].id // empty')

if [ -z "$RUN_ID" ]; then
  echo "ERROR: could not extract a run id for $WORKFLOW. Raw API response:" >&2
  printf '%s\n' "$RUNS_JSON" >&2
  exit 1
fi
RUN_STATUS=$(printf '%s' "$RUNS_JSON" | jq -r '.workflow_runs[0].status // "unknown"')
RUN_CONCLUSION=$(printf '%s' "$RUNS_JSON" | jq -r '.workflow_runs[0].conclusion // "pending"')
echo "=== most recent: run $RUN_ID status=$RUN_STATUS conclusion=$RUN_CONCLUSION ==="
JOBS_JSON=$(curl --http1.1 -sS -f -H "$AUTH" "$API/runs/$RUN_ID/jobs?per_page=100")
printf '%s' "$JOBS_JSON" | jq -r '.jobs[] | "job=\(.name) status=\(.status) conclusion=\(.conclusion // "pending")"'
if [ "$RUN_STATUS" != "completed" ] || [ "$RUN_CONCLUSION" != "success" ]; then
  FAILED_JOB_ID=$(printf '%s' "$JOBS_JSON" | jq -r '.jobs[] | select(.conclusion == "failure") | .id' | head -1)
  if [ -n "$FAILED_JOB_ID" ]; then
    FAILED_LOG="/tmp/pocketcoder-ci-failed.zip"
    curl --http1.1 -sS -fL -H "$AUTH" "$API/jobs/$FAILED_JOB_ID/logs" -o "$FAILED_LOG"
    echo "=== failed job log tail ==="
    if unzip -tq "$FAILED_LOG" >/dev/null 2>&1; then
      LOGDIR="/tmp/pocketcoder-ci-failed-log"
      rm -rf "$LOGDIR"
      mkdir -p "$LOGDIR"
      unzip -q "$FAILED_LOG" -d "$LOGDIR"
      (cat "$LOGDIR"/*/*.txt 2>/dev/null || cat "$LOGDIR"/*.txt) | tail -300
    else
      tail -300 "$FAILED_LOG"
    fi
  fi
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
