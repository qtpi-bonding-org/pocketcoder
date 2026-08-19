#!/usr/bin/env bats

setup() {
  export PC_STATUS_DIR="$BATS_TEST_TMPDIR/public"
  export PC_SOURCE_COMMIT=deadbeef
  mkdir -p "$PC_STATUS_DIR"
  source "$BATS_TEST_DIRNAME/../status.sh"
}

@test "init writes a clean document" {
  pc_status_init
  [ "$(jq -r .schema "$PC_STATUS_DIR/status.json")" = 3 ]
  [ "$(jq -r .operation "$PC_STATUS_DIR/status.json")" = configuring_operating_system ]
  [ "$(jq -r '.errorCode // "null"' "$PC_STATUS_DIR/status.json")" = null ]
  [ "$(jq -r '.errorMessage // "null"' "$PC_STATUS_DIR/status.json")" = null ]
  [ -n "$(jq -r .runId "$PC_STATUS_DIR/status.json")" ]
}

@test "the document never claims ready" {
  pc_status_init
  pc_status_phase loading_images "docker load"
  pc_status_phase compose_up
  pc_status_phase bootstrap_complete
  ! grep -q '"ready"' "$PC_STATUS_DIR/status.json"
}

@test "file mode is explicit" {
  umask 077
  pc_status_init
  [ "$(stat -c %a "$PC_STATUS_DIR/status.json")" = 644 ]
}

@test "concurrent reads never see a partial document" {
  pc_status_init
  for i in $(seq 1 50); do pc_status_phase loading_images "write $i" & done
  for i in $(seq 1 50); do jq -e . "$PC_STATUS_DIR/status.json" >/dev/null; done
  wait
}

@test "error is retained as errorCode" {
  pc_status_init
  pc_status_error fetching_release "git clone failed"
  [ "$(jq -r .errorCode "$PC_STATUS_DIR/status.json")" = "git clone failed" ]
  [ "$(jq -r .operation "$PC_STATUS_DIR/status.json")" = fetching_release ]
}
