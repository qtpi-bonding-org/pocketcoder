#!/bin/bash

# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# tooling/scripts/generate_audit.sh
# @pocketcoder-core: Audit Generator. Programmatically builds the index of original code.
#
# Counts lines of code across PocketCoder core components.
# EXCLUDES: bash scripts, .bats files, test files. Those are tallied separately.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_FILE="$REPO_ROOT/CODEBASE.md"
TAG="@pocketcoder-core"

# ---------------------------------------------------------------------------
# Core source directories to scan for the tag index (new server/ layout)
# ---------------------------------------------------------------------------
# Active product code only. Dormant components (dormant/) are intentionally
# excluded — they are retained for reference but are not built or shipped.
CORE_DIRS=(
  "server/pocketbase"
  "server/goose"
  "server/mcp-gateway"
  "scripts"
  "client"
)
ROOT_FILES=("deploy.sh")

# Source extensions that count as "core logic" (not bash)
LOGIC_EXTS=("go" "rs" "ts" "py" "dart")
# Source extensions that count as "infra / scripts" (separate tally)
SCRIPT_EXTS=("sh")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
count_loc() {
  # Usage: count_loc <file>
  wc -l < "$1" | tr -d ' '
}

is_test_file() {
  local f="$1"
  [[ "$f" == *_test.* ]] || [[ "$f" == */test/* ]] || [[ "$f" == */tests/* ]] || [[ "$f" == *test_*.py ]]
}

# ---------------------------------------------------------------------------
# Write header
# ---------------------------------------------------------------------------
cat > "$TARGET_FILE" << 'EOF'
# 🦅 The Sovereign Audit (Original Code Index)

This document is **programmatically generated** by `tooling/scripts/generate_audit.sh`.
It lists files explicitly tagged with `@pocketcoder-core`.
If a file isn't on this list, it's either a third-party dependency or unlabelled infra.

> **Counting rules**: Core logic = Go / Rust / TypeScript / Python / Dart.
> Shell scripts are tallied separately. Tests are excluded from both counts.

## 🏛️ Original Logic Index

| File | Tech | Role |
| :--- | :--- | :--- |
EOF

# ---------------------------------------------------------------------------
# Scan tagged files
# ---------------------------------------------------------------------------
LOGIC_LOC=0
SCRIPT_LOC=0
FILE_COUNT=0

scan_file() {
  local FILE_PATH="$1"
  local REL_PATH="${FILE_PATH#$REPO_ROOT/}"

  # Skip test files
  if is_test_file "$FILE_PATH"; then
    return
  fi

  local TAG_LINE
  TAG_LINE=$(grep -m1 "$TAG:" "$FILE_PATH" 2>/dev/null || true)
  [[ -z "$TAG_LINE" ]] && return

  local DESCRIPTION
  DESCRIPTION=$(echo "$TAG_LINE" | sed -n "s/.*$TAG: //p" | sed 's/ \*\/$//; s/ -->$//')
  [[ -z "$DESCRIPTION" ]] && return

  local EXT="${FILE_PATH##*.}"
  local TECH
  case "$EXT" in
    go)   TECH="Go" ;;
    rs)   TECH="Rust" ;;
    ts)   TECH="TypeScript" ;;
    py)   TECH="Python" ;;
    dart) TECH="Dart" ;;
    sh)   TECH="Bash" ;;
    *)    TECH="Other" ;;
  esac

  local LINES
  LINES=$(count_loc "$FILE_PATH")

  echo "| \`$REL_PATH\` | $TECH | $DESCRIPTION |" >> "$TARGET_FILE"

  # Tally separately: scripts vs logic
  if [[ "$EXT" == "sh" ]]; then
    SCRIPT_LOC=$((SCRIPT_LOC + LINES))
  else
    LOGIC_LOC=$((LOGIC_LOC + LINES))
  fi
  FILE_COUNT=$((FILE_COUNT + 1))
}

for DIR in "${CORE_DIRS[@]}"; do
  ABS_DIR="$REPO_ROOT/$DIR"
  if [[ ! -d "$ABS_DIR" ]]; then
    echo "⚠️  [Audit] Skipping missing directory: $DIR" >&2
    continue
  fi

  # Build extension pattern for find
  EXT_ARGS=()
  ALL_EXTS=("${LOGIC_EXTS[@]}" "${SCRIPT_EXTS[@]}")
  for e in "${ALL_EXTS[@]}"; do
    EXT_ARGS+=(-o -name "*.${e}")
  done

  # Prune cao submodule, node_modules, build artifacts, generated code
  while IFS= read -r FILE; do
    scan_file "$FILE"
  done < <(find "$ABS_DIR" \
    -path "$ABS_DIR/node_modules" -prune -o \
    -path "$ABS_DIR/cao" -prune -o \
    -path "$ABS_DIR/.dart_tool" -prune -o \
    -path "$ABS_DIR/build" -prune -o \
    -path "*/generated/*" -prune -o \
    -type f \( -false "${EXT_ARGS[@]}" \) -print)
done

for f in "${ROOT_FILES[@]}"; do
  ABS_F="$REPO_ROOT/$f"
  if [[ -f "$ABS_F" ]]; then
    scan_file "$ABS_F"
  fi
done

# ---------------------------------------------------------------------------
# The CAO fork submodule was removed with the legacy sandbox service;
# Python delta accounting is retired along with it.
# ---------------------------------------------------------------------------
CAO_ADDED=0
CAO_DELETED=0
CAO_NOTE="(retired — sandbox/cao removed)"

# ---------------------------------------------------------------------------
# Flutter client: full Dart count (non-generated, non-test)
# ---------------------------------------------------------------------------
DART_LOC=0
while IFS= read -r DART_FILE; do
  is_test_file "$DART_FILE" && continue
  DART_LOC=$((DART_LOC + $(count_loc "$DART_FILE")))
done < <(find "$REPO_ROOT/client" \
  -path "*/generated/*" -prune -o \
  -path "*/.dart_tool/*" -prune -o \
  -path "*/build/*" -prune -o \
  -type f -name "*.dart" -print)

# ---------------------------------------------------------------------------
# Footer: language breakdown
# ---------------------------------------------------------------------------
# Product Go excludes both a tests/ dir AND Go's *_test.go convention files,
# which live alongside their packages — otherwise ~2k of test code would be
# miscounted as product code.
GO_LOC=$(find "$REPO_ROOT/server/pocketbase" -name '*.go' ! -name '*_test.go' ! -path '*/tests/*' -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')
GO_TEST_LOC=$(find "$REPO_ROOT/server/pocketbase" -name '*_test.go' -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')

# Dart tests: *_test.dart or files under a test/ or tests/ dir (non-generated).
DART_TEST_LOC=$(find "$REPO_ROOT/client" \
  -path "*/.dart_tool/*" -prune -o \
  -path "*/build/*" -prune -o \
  -path "*/generated/*" -prune -o \
  -type f \( -name '*_test.dart' -o -path '*/test/*.dart' \) -print 2>/dev/null \
  | sort -u | xargs wc -l 2>/dev/null | awk 'END{print $1+0}')

# Bash tests: the tests/ tree — .bats suites plus their .sh harnesses.
BASH_TEST_LOC=$(find "$REPO_ROOT/tests" \( -name '*.bats' -o -name '*.sh' \) -type f 2>/dev/null \
  | xargs wc -l 2>/dev/null | awk 'END{print $1+0}')

# Bash tooling: git-TRACKED shell scripts, EXCLUDING the tests/ tree. A repo-wide
# find would sweep in gitignored vendored trees (.independent_repos, venv,
# fdroid_env, client iOS/Flutter tooling), inflating the count several-fold.
BASH_LOC=$( (cd "$REPO_ROOT" && git ls-files -z '*.sh' ':!:*/tests/*' | xargs -0 cat 2>/dev/null) | wc -l | tr -d ' ')

# Core = active product code only: Go (c1) + Dart (client). Dormant Rust is
# excluded (see dormant/); tests and tooling are tallied separately, never core.
CORE_TOTAL=$((GO_LOC + DART_LOC))
TEST_TOTAL=$((GO_TEST_LOC + DART_TEST_LOC + BASH_TEST_LOC))

{
echo ""
echo "---"
echo ""
echo "## 📊 Lines of Code"
echo ""
echo "**Core product code:**"
echo ""
echo "| Language | LoC | Component |"
echo "| :--- | ---: | :--- |"
echo "| Go | ${GO_LOC} | c1: PocketBase + ACP client + AG-UI server |"
echo "| Dart | ${DART_LOC} | Flutter client (non-generated, non-test) |"
echo "| **Core total** | **${CORE_TOTAL}** | Go + Dart |"
echo ""
echo "**Tests** (not product code):"
echo ""
echo "| Type | LoC | Notes |"
echo "| :--- | ---: | :--- |"
echo "| Go tests | ${GO_TEST_LOC} | \`*_test.go\` |"
echo "| Dart tests | ${DART_TEST_LOC} | \`*_test.dart\`, \`test/\` |"
echo "| Bash tests | ${BASH_TEST_LOC} | \`tests/\` — bats suites + shell harnesses |"
echo "| **Test total** | **${TEST_TOTAL}** | |"
echo ""
echo "**Tooling** (not product code):"
echo ""
echo "| Type | LoC | Notes |"
echo "| :--- | ---: | :--- |"
echo "| Bash | ${BASH_LOC} | Scripts / infra (git-tracked, excludes tests/) |"
echo ""
echo "_Dormant (retained, not built): Rust sandbox proxy & poco-agents — see \`dormant/\`._"
echo ""
echo "*Tagged core files (index above): $FILE_COUNT.*"
} >> "$TARGET_FILE"

echo "✅ [Audit] Generated $TARGET_FILE"
echo "   Core logic : $LOGIC_LOC LoC across $FILE_COUNT tagged files"
echo "   Shell infra : $SCRIPT_LOC LoC (separate)"
echo "   Flutter     : $DART_LOC LoC (Dart, non-generated)"
if [[ -n "$CAO_NOTE" ]]; then
  echo "   CAO fork    : $CAO_NOTE"
fi

# ---------------------------------------------------------------------------
# Sync README.md stats table
# ---------------------------------------------------------------------------
README_FILE="$REPO_ROOT/README.md"
if [[ -f "$README_FILE" ]]; then
  # Format numbers with commas (portable printf)
  fmt() { printf "%'d" "$1" 2>/dev/null || echo "$1"; }

  # Write replacement table to temp file
  README_TABLE_FILE=$(mktemp)
  cat > "$README_TABLE_FILE" <<READMEEOF
| Language | LoC | Component |
| :--- | ---: | :--- |
| Go | $(fmt $GO_LOC) | c1: PocketBase + ACP client + AG-UI server |
| Dart | $(fmt $DART_LOC) | Flutter client (non-generated) |
| **Core code** | **~$(fmt $CORE_TOTAL)** | Go + Dart — product code |
| Tests | $(fmt $TEST_TOTAL) | not code — Go $(fmt $GO_TEST_LOC) · Dart $(fmt $DART_TEST_LOC) · Bash $(fmt $BASH_TEST_LOC) |
| Tooling | $(fmt $BASH_LOC) | not code — Bash scripts / infra |
READMEEOF

  # Replace the table: find header row, insert replacement, skip old rows until blank line
  awk '
    /^\| Language \| LoC \| Component \|/ {
      replacing=1
      while ((getline line < "'"$README_TABLE_FILE"'") > 0) print line
      next
    }
    replacing && /^$/ { replacing=0 }
    replacing { next }
    { print }
  ' "$README_FILE" > "${README_FILE}.tmp" && mv "${README_FILE}.tmp" "$README_FILE"

  rm -f "$README_TABLE_FILE"
  echo "✅ [Audit] Synced README.md stats table"
fi
