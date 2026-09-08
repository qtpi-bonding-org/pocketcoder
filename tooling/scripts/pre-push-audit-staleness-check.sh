#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$repo_root"

readme_backup=$(mktemp)
codebase_backup=$(mktemp)
cleanup() { rm -f "$readme_backup" "$codebase_backup"; }
trap cleanup EXIT

cp README.md "$readme_backup"
[ -f CODEBASE.md ] && cp CODEBASE.md "$codebase_backup" || : > "$codebase_backup"

bash tooling/scripts/generate_audit.sh >/dev/null 2>&1 || true

stale=0
if ! diff -q "$readme_backup" README.md >/dev/null 2>&1; then
  stale=1
fi
if ! diff -q "$codebase_backup" CODEBASE.md >/dev/null 2>&1; then
  stale=1
fi

cp "$readme_backup" README.md
cp "$codebase_backup" CODEBASE.md

if [ "$stale" -eq 1 ]; then
  echo "" >&2
  echo "pre-push: the LoC audit in README.md/CODEBASE.md is stale." >&2
  echo "  Run tooling/scripts/generate_audit.sh and commit the result." >&2
fi

exit 0
