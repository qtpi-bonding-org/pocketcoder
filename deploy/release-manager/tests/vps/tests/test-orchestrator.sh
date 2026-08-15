suite="$VPS_DIR/run-vps-suite.sh"

# A fixture phase directory the orchestrator can be pointed at.
fixtures="$TEST_TMP/phases"
mkdir -p "$fixtures"
cat > "$fixtures/10-alpha.sh" <<'EOF'
phase_name=alpha
phase_tier=readonly
phase_run() { echo "alpha ran"; [ "${ALPHA_FAIL:-0}" = 1 ] && return 1; return 0; }
EOF
cat > "$fixtures/20-bravo.sh" <<'EOF'
phase_name=bravo
phase_tier=safe-mutating
phase_run() { echo "bravo ran"; return 0; }
EOF
cat > "$fixtures/30-charlie.sh" <<'EOF'
phase_name=charlie
phase_tier=disruptive
phase_run() { echo "charlie ran"; return 0; }
EOF
cat > "$fixtures/40-delta.sh" <<'EOF'
phase_name=delta
phase_tier=disruptive
phase_run() { echo "skipping"; return 78; }
EOF

run_suite() {
  POCKETCODER_VPS_SCRIPT_TEST=1 \
  VPS_PHASE_DIR="$fixtures" \
  VPS_SKIP_PROVISION=1 \
    bash "$suite" --run-dir "$1" --keep "${@:2}" >"$1.log" 2>&1
}

# Gate
VPS_PHASE_DIR="$fixtures" bash "$suite" --run-dir "$TEST_TMP/g" >/dev/null 2>&1
check_rc "orchestrator: refuses without the opt-in gate" 64 "$?"

# Happy path
run_suite "$TEST_TMP/r1"
check_rc "orchestrator: passes when all phases pass" 0 "$?"
check "orchestrator: records four phases" "4" "$(jq '.phases | length' "$TEST_TMP/r1/result.json")"
check "orchestrator: exit 78 is skipped, not failed" "skipped" \
  "$(jq -r '.phases[] | select(.phase=="delta") | .status' "$TEST_TMP/r1/result.json")"
check "orchestrator: a skip does not fail the run" "passed" \
  "$(jq -r '.status' "$TEST_TMP/r1/result.json")"

# Tier gating: a readonly failure must stop everything after it.
ALPHA_FAIL=1 run_suite "$TEST_TMP/r2"
check_rc "orchestrator: fails when a readonly phase fails" 1 "$?"
check "orchestrator: records the failing phase" "alpha" \
  "$(jq -r '.failurePhase' "$TEST_TMP/r2/result.json")"
check "orchestrator: aborts before safe-mutating tier" "0" \
  "$(jq '[.phases[] | select(.phase=="bravo")] | length' "$TEST_TMP/r2/result.json")"
check "orchestrator: aborts before disruptive tier" "0" \
  "$(jq '[.phases[] | select(.phase=="charlie")] | length' "$TEST_TMP/r2/result.json")"

# Selection
run_suite "$TEST_TMP/r3" --only alpha,charlie
check "orchestrator: --only selects the named phases" "alpha charlie" \
  "$(jq -r '[.phases[].phase] | join(" ")' "$TEST_TMP/r3/result.json")"

run_suite "$TEST_TMP/r4" --skip delta
check "orchestrator: --skip excludes the named phase" "0" \
  "$(jq '[.phases[] | select(.phase=="delta")] | length' "$TEST_TMP/r4/result.json")"

# Evidence survival
check "orchestrator: run dir survives the run" "yes" \
  "$( [ -f "$TEST_TMP/r1/result.json" ] && echo yes )"
