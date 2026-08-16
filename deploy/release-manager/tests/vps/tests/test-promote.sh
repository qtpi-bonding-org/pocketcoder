. "$VPS_DIR/phases/55-promote.sh"

promote_repo="$TEST_TMP/promote-repo"
promote_bin="$TEST_TMP/promotebin"
digest_64=$(printf 'a%.0s' $(seq 1 64))
baseline_64=$(printf 'b%.0s' $(seq 1 64))

mkdir -p "$promote_repo/deploy/nixos/scripts"
stub_bin "$promote_repo/deploy/nixos/scripts" trigger-ci-build.sh 'echo "candidate build dispatched"'
stub_bin "$promote_repo/deploy/nixos/scripts" promote-latest-candidate.sh \
  "echo \"promotion dispatched: ref=staging channel=nightly manifest=${STUB_PROMOTE_DIGEST:-$digest_64}\""

stub_bin "$promote_bin" git '
for arg in "$@"; do last=$arg; done
case $last in
  HEAD) echo stub-commit-sha ;;
  *) echo "" ;;
esac'

# --- happy path ---
stub_bin "$promote_bin" curl '
for arg in "$@"; do last=$arg; done
case $last in
  *"workflows/nixos-image.yml/runs?"*) echo "{\"workflow_runs\":[{\"id\":123,\"head_sha\":\"stub-commit-sha\"}]}" ;;
  *"/runs/123") echo "{\"status\":\"completed\",\"conclusion\":\"success\"}" ;;
  *"channels/nightly-testing.json") echo "{\"manifest\":{\"sha256\":\"'"$digest_64"'\"},\"sequence\":\"7\"}" ;;
  *) exit 1 ;;
esac'

result=$(GH_TOKEN=test-token PATH="$promote_bin:$PATH" VPS_PROMOTE_POLL_INTERVAL=0 \
  vps_promote_candidate "$promote_repo" "$baseline_64" staging)
rc=$?
check_rc "55-promote: happy path succeeds" 0 "$rc"
check "55-promote: reports the promoted digest" "$digest_64" "$(jq -r '.digest' <<<"$result")"
check "55-promote: reports the source commit" "stub-commit-sha" "$(jq -r '.sourceCommit' <<<"$result")"
check "55-promote: reports the channel sequence" "7" "$(jq -r '.sequence' <<<"$result")"

# --- candidate identical to baseline must fail ---
GH_TOKEN=test-token PATH="$promote_bin:$PATH" VPS_PROMOTE_POLL_INTERVAL=0 \
  vps_promote_candidate "$promote_repo" "$digest_64" staging >/dev/null 2>&1
check_rc "55-promote: candidate identical to baseline fails" 1 "$?"

# --- a failed candidate build must fail, not hang ---
stub_bin "$promote_bin" curl '
for arg in "$@"; do last=$arg; done
case $last in
  *"workflows/nixos-image.yml/runs?"*) echo "{\"workflow_runs\":[{\"id\":123,\"head_sha\":\"stub-commit-sha\"}]}" ;;
  *"/runs/123") echo "{\"status\":\"completed\",\"conclusion\":\"failure\"}" ;;
  *) exit 1 ;;
esac'
GH_TOKEN=test-token PATH="$promote_bin:$PATH" VPS_PROMOTE_POLL_INTERVAL=0 \
  vps_promote_candidate "$promote_repo" "$baseline_64" staging >/dev/null 2>&1
check_rc "55-promote: a failed candidate build fails, not hangs" 1 "$?"

# --- a pointer that never reflects the promoted digest must time out, not hang ---
stub_bin "$promote_bin" curl '
for arg in "$@"; do last=$arg; done
case $last in
  *"workflows/nixos-image.yml/runs?"*) echo "{\"workflow_runs\":[{\"id\":123,\"head_sha\":\"stub-commit-sha\"}]}" ;;
  *"/runs/123") echo "{\"status\":\"completed\",\"conclusion\":\"success\"}" ;;
  *"channels/nightly-testing.json") echo "{\"manifest\":{\"sha256\":\"'"$baseline_64"'\"},\"sequence\":\"7\"}" ;;
  *) exit 1 ;;
esac'
GH_TOKEN=test-token PATH="$promote_bin:$PATH" VPS_PROMOTE_POLL_INTERVAL=0 VPS_PROMOTE_POINTER_ATTEMPTS=2 \
  vps_promote_candidate "$promote_repo" "$baseline_64" staging >/dev/null 2>&1
check_rc "55-promote: a stale pointer times out, not hangs" 1 "$?"

# --- a main-branch promotion polls the unqualified pointer, not -testing ---
stub_bin "$promote_repo/deploy/nixos/scripts" promote-latest-candidate.sh \
  "echo \"promotion dispatched: ref=main channel=nightly manifest=${digest_64}\""
stub_bin "$promote_bin" curl '
for arg in "$@"; do last=$arg; done
case $last in
  *"workflows/nixos-image.yml/runs?"*) echo "{\"workflow_runs\":[{\"id\":123,\"head_sha\":\"stub-commit-sha\"}]}" ;;
  *"/runs/123") echo "{\"status\":\"completed\",\"conclusion\":\"success\"}" ;;
  *"channels/nightly.json") echo "{\"manifest\":{\"sha256\":\"'"$digest_64"'\"},\"sequence\":\"9\"}" ;;
  *) exit 1 ;;
esac'
result=$(GH_TOKEN=test-token PATH="$promote_bin:$PATH" VPS_PROMOTE_POLL_INTERVAL=0 \
  vps_promote_candidate "$promote_repo" "$baseline_64" main)
check_rc "55-promote: main-branch happy path succeeds" 0 "$?"
check "55-promote: main branch polls the unqualified pointer" "9" "$(jq -r '.sequence' <<<"$result")"
