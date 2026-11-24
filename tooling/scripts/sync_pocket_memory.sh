#!/usr/bin/env bash
# server/memory is a vendored copy of https://github.com/qtpi-bonding/pocket-memory.
# Edit that repository, not this copy.
#
#   sync_pocket_memory.sh <repository path or URL> <full commit>   update the copy
#   sync_pocket_memory.sh --check                                  fail if it was edited
#
# README.md is PocketCoder's own and is not vendored. --check needs no network.
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
target="$repo_root/server/memory"
record="$target/VENDORED"
paths=(Cargo.lock Cargo.toml Dockerfile schema.sql model src tests)

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}

hashes() {
  (cd "$target" && find "${paths[@]}" -type f ! -name .DS_Store | LC_ALL=C sort |
    while IFS= read -r file; do sha256 "$file"; done)
}

if [[ ${1:-} == --check ]]; then
  if ! diff <(sed '1,/^---$/d' "$record") <(hashes); then
    echo "server/memory differs from its vendored commit; edit pocket-memory and sync instead" >&2
    exit 1
  fi
  echo "server/memory matches its vendored commit"
  exit 0
fi

source=${1:?repository path or URL is required}
commit=${2:?full commit is required}
if [[ ! $commit =~ ^[0-9a-f]{40}$ ]]; then
  echo "commit must be 40 lowercase hex characters: $commit" >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone -q --no-checkout "$source" "$work/repo"
git -C "$work/repo" cat-file -e "$commit^{commit}"
mkdir "$work/files"
git -C "$work/repo" archive "$commit" "${paths[@]}" | tar -x -C "$work/files"

for path in "${paths[@]}"; do
  rm -rf "${target:?}/$path"
  cp -R "$work/files/$path" "$target/$path"
done
{
  echo "Vendored from https://github.com/qtpi-bonding/pocket-memory"
  echo "Commit: $commit"
  echo "Edit there, then run tooling/scripts/sync_pocket_memory.sh. README.md is not vendored."
  echo "---"
  hashes
} >"$record.new"
mv "$record.new" "$record"
echo "server/memory is now pocket-memory $commit"
