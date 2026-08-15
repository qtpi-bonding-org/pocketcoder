check "helpers: equal values pass" "a" "a"
check_contains "helpers: substring match" "ell" "hello"

stub_bin "$TEST_TMP/bin" fakecmd 'echo stubbed'
check "helpers: stub_bin is executable" "stubbed" "$(PATH=$TEST_TMP/bin:$PATH fakecmd)"
