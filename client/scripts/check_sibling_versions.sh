#!/usr/bin/env bash
# Verifies the SHA pinned in pubspec.yaml's git dependency matches
# sibling-versions.lock, and (on --update) refuses to record a new SHA
# unless that SHA's flutter test suite passes in a scratch clone.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/sibling-versions.lock"
UPDATE=0
NEW_SHA=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update) UPDATE=1; shift ;;
    --sha) NEW_SHA="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$LOCK" ]] || { echo "lock file not found: $LOCK" >&2; exit 2; }

if [[ "$UPDATE" -eq 1 ]]; then
  [[ -n "$NEW_SHA" ]] || { echo "--update requires --sha <sha>" >&2; exit 2; }
  tmp_clone="$(mktemp -d)"
  echo "cloning ag_ui_widgets_flutter@$NEW_SHA to verify tests pass..."
  git clone --quiet https://github.com/qtpi-bonding-org/ag_ui_widgets_flutter.git "$tmp_clone"
  git -C "$tmp_clone" checkout --quiet "$NEW_SHA"
  (cd "$tmp_clone" && flutter pub get && flutter test) || {
    echo "REFUSED: ag_ui_widgets_flutter@$NEW_SHA does not pass its own test suite" >&2
    rm -rf "$tmp_clone"
    exit 1
  }
  rm -rf "$tmp_clone"
  sed -i.bak "s/\tag_ui_widgets_flutter.git\t.*/\tag_ui_widgets_flutter.git\t$NEW_SHA/" "$LOCK" 2>/dev/null || \
    printf 'ag_ui_widgets_flutter\thttps://github.com/qtpi-bonding-org/ag_ui_widgets_flutter.git\t%s\n' "$NEW_SHA" > "$LOCK"
  rm -f "$LOCK.bak"
  echo "updated ag_ui_widgets_flutter -> $NEW_SHA (tests passed)"
  exit 0
fi

pinned_sha="$(grep '^ag_ui_widgets_flutter' "$LOCK" | cut -f3)"
pubspec_sha="$(grep -A3 'ag_ui_widgets_flutter:' "$ROOT/packages/pocketcoder_flutter/pubspec.yaml" | grep 'ref:' | sed 's/.*ref: *//')"

if [[ "$pinned_sha" != "$pubspec_sha" ]]; then
  echo "MISMATCH: pubspec.yaml pins $pubspec_sha but lock says $pinned_sha" >&2
  exit 1
fi
echo "ok       ag_ui_widgets_flutter @ ${pinned_sha:0:7}"
