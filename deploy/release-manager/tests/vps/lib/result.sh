#!/usr/bin/env bash
# Result schema v2 emission. Sourced, never executed directly.

VPS_RUN_DIR=
_phase_file=
_top_file=
_teardown_file=

result_init() {
  VPS_RUN_DIR=$1
  mkdir -p "$VPS_RUN_DIR"
  _phase_file="$VPS_RUN_DIR/.phases.jsonl"
  _top_file="$VPS_RUN_DIR/.top.jsonl"
  _teardown_file="$VPS_RUN_DIR/.teardown.json"
  : > "$_phase_file"
  : > "$_top_file"
  jq -n '{attempted:false,succeeded:false,instanceDeleted:false,detail:""}' \
    > "$_teardown_file"
}

result_set() {
  jq -n --arg k "$1" --arg v "$2" '{($k): $v}' >> "$_top_file"
}

result_set_json() {
  jq -n --arg k "$1" --argjson v "$2" '{($k): $v}' >> "$_top_file"
}

_iso() {
  # Portable epoch -> RFC3339 across macOS and Linux date(1).
  if date -u -r "$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null; then
    return 0
  fi
  date -u -d "@$1" '+%Y-%m-%dT%H:%M:%SZ'
}

phase_record() {
  local name=$1 tier=$2 status=$3 started=$4 ended=$5 detail=$6 evidence=$7
  local skip_reason=${8:-}
  jq -n \
    --arg phase "$name" --arg tier "$tier" --arg status "$status" \
    --arg startedAt "$(_iso "$started")" --arg endedAt "$(_iso "$ended")" \
    --argjson durationSeconds "$(( ended - started ))" \
    --arg detail "$(redact "$detail")" \
    --argjson evidence "${evidence:-\{\}}" \
    --arg skipReason "$skip_reason" \
    '{phase:$phase,tier:$tier,status:$status,
      skipReason:(if $skipReason=="" then null else $skipReason end),
      startedAt:$startedAt,endedAt:$endedAt,
      durationSeconds:$durationSeconds,detail:$detail,evidence:$evidence}' \
    >> "$_phase_file"
}

teardown_record() {
  jq -n --argjson attempted "$1" --argjson succeeded "$2" \
    --argjson instanceDeleted "$3" --arg detail "$4" \
    '{attempted:$attempted,succeeded:$succeeded,
      instanceDeleted:$instanceDeleted,detail:$detail}' \
    > "$_teardown_file"
}

result_write() {
  local status=$1 failure_phase=$2
  local phases top teardown
  phases=$(jq -s . "$_phase_file")
  top=$(jq -s 'add // {}' "$_top_file")
  teardown=$(cat "$_teardown_file")
  jq -n \
    --arg status "$status" --arg failurePhase "$failure_phase" \
    --argjson phases "$phases" --argjson top "$top" \
    --argjson teardown "$teardown" \
    '{schemaVersion:2,suite:"vps-script",status:$status,
      failurePhase:(if $failurePhase=="" then null else $failurePhase end)}
     + $top + {phases:$phases,teardown:$teardown}' \
    > "$VPS_RUN_DIR/result.json.tmp"
  mv "$VPS_RUN_DIR/result.json.tmp" "$VPS_RUN_DIR/result.json"
}
