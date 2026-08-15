. "$VPS_DIR/lib/common.sh"
. "$VPS_DIR/lib/result.sh"

VPS_REDACTION_READY=1
VPS_REDACTION_VALUES='supersecret'

run_dir="$TEST_TMP/run1"
result_init "$run_dir"
result_set hostname vps.example.test
result_set instanceId 12345
result_set_json releaseA '{"digest":"aa","sourceCommit":"bb","channel":"nightly","sequence":9}'
phase_record 20-topology readonly passed 100 130 'token=supersecret' '{"tlsDays":80}'
phase_record 90-nixos-update disruptive skipped 130 131 '' '{}' 'configuration.nix absent'
teardown_record true true true 'deleted 12345'
result_write passed ''

out="$run_dir/result.json"
check "result: schemaVersion is 2" "2" "$(jq -r '.schemaVersion' "$out")"
check "result: top-level status" "passed" "$(jq -r '.status' "$out")"
check "result: failurePhase null when passing" "null" "$(jq -r '.failurePhase' "$out")"
check "result: string field set" "vps.example.test" "$(jq -r '.hostname' "$out")"
check "result: json field set" "nightly" "$(jq -r '.releaseA.channel' "$out")"
check "result: records duration" "30" "$(jq -r '.phases[0].durationSeconds' "$out")"
check "result: startedAt precedes endedAt" "true" \
  "$(jq -r '.phases[0].startedAt < .phases[0].endedAt' "$out")"
check "result: detail is redacted" "token=[REDACTED]" "$(jq -r '.phases[0].detail' "$out")"
check "result: typed evidence survives" "80" "$(jq -r '.phases[0].evidence.tlsDays' "$out")"
check "result: skip reason recorded" "configuration.nix absent" \
  "$(jq -r '.phases[1].skipReason' "$out")"
check "result: teardown recorded" "true" "$(jq -r '.teardown.instanceDeleted' "$out")"
check "result: run dir survives" "yes" "$([ -f "$out" ] && echo yes)"
