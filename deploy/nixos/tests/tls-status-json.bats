#!/usr/bin/env bats

setup() {
  export POCKETCODER_STATUS_FILE="$BATS_TEST_TMPDIR/public/status.json"
  mkdir -p "$(dirname "$POCKETCODER_STATUS_FILE")"
}

@test "tls-status writes schema 3 and a pending state with no certificate present" {
  run "$BATS_TEST_DIRNAME/../../scripts/tls-status.sh" example.test
  [ "$status" -eq 0 ]
  [ "$(jq -r .schema "$POCKETCODER_STATUS_FILE")" = 3 ]
  [ "$(jq -r .tls.state "$POCKETCODER_STATUS_FILE")" = pending ]
  [ "$(jq -r .tls.hostname "$POCKETCODER_STATUS_FILE")" = example.test ]
}

@test "tls-status preserves fields it does not own" {
  mkdir -p "$(dirname "$POCKETCODER_STATUS_FILE")"
  echo '{"schema":3,"operation":"loading_images","runId":"run-1"}' > "$POCKETCODER_STATUS_FILE"
  run "$BATS_TEST_DIRNAME/../../scripts/tls-status.sh" example.test
  [ "$status" -eq 0 ]
  [ "$(jq -r .operation "$POCKETCODER_STATUS_FILE")" = loading_images ]
  [ "$(jq -r .runId "$POCKETCODER_STATUS_FILE")" = run-1 ]
  [ "$(jq -r .tls.state "$POCKETCODER_STATUS_FILE")" = pending ]
}
