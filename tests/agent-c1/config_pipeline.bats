#!/usr/bin/env bats

# Config-delivery verification for the agent-definition pipeline (spec §13).
#
# The render pipeline is only correct if the files PocketBase writes reach the
# exact paths Goose reads. That path is a load-bearing verify item (§13.1):
# Goose derives its config dir from GOOSE_PATH_ROOT, NOT ~/.config/goose. A
# guessed-wrong mount renders config that Goose silently ignores — every unit
# and golden test still passes while the app runs on compose-env defaults.
#
# These tests assert the live mount==configdir invariant against the running
# containers, so a path regression fails loudly instead of going unnoticed.

setup() {
  : "${GOOSE_CONTAINER:?}"
  : "${POCKETBASE_CONTAINER:?}"
}

# goose_config_dir reports the directory Goose actually reads config.yaml from,
# taken from Goose's own `goose info` output rather than any assumption.
goose_config_dir() {
  docker exec "$GOOSE_CONTAINER" goose info 2>/dev/null |
    awk '/Config yaml:/{print $3}' | xargs dirname
}

@test "PocketBase-written config lands where Goose reads it (§13.1)" {
  local cfg_dir
  cfg_dir=$(goose_config_dir)
  [ -n "$cfg_dir" ]

  # Write a sentinel into the volume PocketBase owns (its /goose-config mount).
  local sentinel="pipeline-probe-${BATS_TEST_NUMBER}-$$"
  docker exec "$POCKETBASE_CONTAINER" sh -c \
    "printf '%s' '$sentinel' > /goose-config/.pipeline-probe"

  # It MUST be visible at the directory Goose reads from. If the volume is
  # mounted anywhere else in the goose container, this is empty and the test
  # fails — which is exactly the §13.1 mismatch we are guarding against.
  local seen
  seen=$(docker exec "$GOOSE_CONTAINER" cat "$cfg_dir/.pipeline-probe" 2>/dev/null || true)

  docker exec "$POCKETBASE_CONTAINER" rm -f /goose-config/.pipeline-probe || true
  [ "$seen" = "$sentinel" ]
}

@test "Goose config path is inside the shared config volume (§13.2)" {
  local cfg_dir
  cfg_dir=$(goose_config_dir)
  [ -n "$cfg_dir" ]

  # The entrypoint sources $GOOSE_PATH_ROOT/config/keys.env before provider
  # validation. That path must be inside the config dir Goose reports, so the
  # PocketBase-rendered keys.env is the one the entrypoint reads.
  local path_root
  path_root=$(docker exec "$GOOSE_CONTAINER" printenv GOOSE_PATH_ROOT)
  [ "$cfg_dir" = "${path_root}/config" ]

  # Goose is provisioned dynamically now; provider keys belong to the
  # user-owned harness rather than the fixed control-plane Goose container.
  [ "$cfg_dir" = "/workspace/.pocketcoder_auth/config" ]
}

@test "a rendered config.yaml is picked up by Goose (§13.1 end-to-end)" {
  local cfg_dir
  cfg_dir=$(goose_config_dir)
  [ -n "$cfg_dir" ]

  # Simulate a pipeline render landing config.yaml on the PocketBase side and
  # confirm Goose stops reporting it as missing. This exercises the full
  # volume path both writers share, independent of DB seed state.
  docker exec "$POCKETBASE_CONTAINER" sh -c \
    "printf 'GOOSE_PROVIDER: anthropic\n' > /goose-config/config.yaml"

  run docker exec "$GOOSE_CONTAINER" goose info
  [ "$status" -eq 0 ]
  echo "$output" | grep -E "Config yaml:.*config\.yaml" | grep -vq missing

  docker exec "$POCKETBASE_CONTAINER" rm -f /goose-config/config.yaml || true
}
