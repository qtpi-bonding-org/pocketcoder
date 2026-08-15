#!/usr/bin/env bash
# Shared assertions and stubs for the VPS harness self-test.

test_pass=0
test_fail=0

check() {
  local name=$1 expected=$2 actual=$3
  if [ "$expected" = "$actual" ]; then
    test_pass=$((test_pass + 1))
    printf 'ok   %s\n' "$name"
  else
    test_fail=$((test_fail + 1))
    printf 'FAIL %s\n  expected: %s\n  actual:   %s\n' "$name" "$expected" "$actual"
  fi
}

check_rc() {
  check "$1" "$2" "$3"
}

check_contains() {
  local name=$1 needle=$2 haystack=$3
  case $haystack in
    *"$needle"*) test_pass=$((test_pass + 1)); printf 'ok   %s\n' "$name" ;;
    *) test_fail=$((test_fail + 1))
       printf 'FAIL %s\n  expected to contain: %s\n  actual: %s\n' "$name" "$needle" "$haystack" ;;
  esac
}

# stub_bin <dir> <name> <body> — write an executable stub onto a PATH dir.
stub_bin() {
  local dir=$1 name=$2 body=$3
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\n%s\n' "$body" > "$dir/$name"
  chmod +x "$dir/$name"
}
