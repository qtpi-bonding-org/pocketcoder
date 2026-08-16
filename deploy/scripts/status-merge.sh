#!/bin/sh
# Merge the fields owned by a release operation into the public status snapshot.
# The lock is deliberately compatible with deploy/nixos/status.sh.

pc_status_update() {
  pc_status_file=$1
  pc_status_run_id=$2
  pc_status_source=$3
  pc_status_phase=$4
  pc_status_detail=${5:-}
  pc_status_error=${6:-}
  pc_status_dir=$(dirname -- "$pc_status_file")
  install -d -m 0755 "$pc_status_dir"
  exec 9>>"$pc_status_dir/.status.lock"
  flock 9
  pc_status_existing='{}'
  if [ -s "$pc_status_file" ] && jq -e . "$pc_status_file" >/dev/null 2>&1; then
    pc_status_existing=$pc_status_file
  fi
  pc_status_tmp=$(mktemp -p "$pc_status_dir" .status.XXXXXX)
  jq --argjson schema 2 \
    --arg runId "$pc_status_run_id" --arg sourceCommit "$pc_status_source" \
    --arg phase "$pc_status_phase" --arg detail "$pc_status_detail" \
    --arg error "$pc_status_error" \
    --arg updatedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '(. + {schema:$schema,runId:$runId,phase:$phase,
      detail:(if $detail == "" then null else $detail end),
      sourceCommit:$sourceCommit,updatedAt:$updatedAt,
      error:(if $error == "" then null else $error end)})' \
    "$pc_status_existing" > "$pc_status_tmp"
  chmod 0644 "$pc_status_tmp"
  mv -f "$pc_status_tmp" "$pc_status_file"
  flock -u 9
  exec 9>&-
}
