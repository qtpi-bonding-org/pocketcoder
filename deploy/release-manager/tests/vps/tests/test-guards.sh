. "$VPS_DIR/lib/guards.sh"

guard_required_commands jq curl >/dev/null 2>&1
check_rc "guards: present commands pass" 0 "$?"

err=$(guard_required_commands definitely-not-a-real-binary 2>&1)
check_rc "guards: missing command fails" 1 "$?"
check_contains "guards: names the missing command" "definitely-not-a-real-binary" "$err"

repo="$TEST_TMP/repo"
mkdir -p "$repo"
git -C "$repo" init -q
git -C "$repo" config user.email t@test
git -C "$repo" config user.name t
mkdir -p "$repo/docs/testing"
echo a > "$repo/tracked.txt"
echo a > "$repo/docs/testing/mvp-code-gap-todo.md"
git -C "$repo" add -A
git -C "$repo" commit -qm init

guard_clean_checkout "$repo" >/dev/null 2>&1
check_rc "guards: clean checkout passes" 0 "$?"

echo changed > "$repo/docs/testing/mvp-code-gap-todo.md"
guard_clean_checkout "$repo" >/dev/null 2>&1
check_rc "guards: checklist doc edits are allowed" 0 "$?"

echo changed > "$repo/tracked.txt"
err=$(guard_clean_checkout "$repo" 2>&1)
check_rc "guards: other dirty paths fail" 1 "$?"
check_contains "guards: names the dirty path" "tracked.txt" "$err"

flutter_dir="$TEST_TMP/fbin"
stub_bin "$flutter_dir" flutter 'echo flutter'
check "guards: resolve_flutter_bin falls back to PATH" "$flutter_dir/flutter" \
  "$(FLUTTER_BIN= PATH="$flutter_dir:$PATH" resolve_flutter_bin)"

err=$(FLUTTER_BIN=/nonexistent/flutter resolve_aeroform_root /nonexistent 2>&1)
check_rc "guards: missing aeroform root fails" 1 "$?"
check_contains "guards: aeroform failure is actionable" "AEROFORM_ROOT" "$err"
