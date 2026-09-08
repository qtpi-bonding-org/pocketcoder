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
  "server/memory"
  "workers"
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

  while IFS= read -r FILE; do
    scan_file "$FILE"
  done < <(find "$ABS_DIR" \
    -path "*/node_modules/*" -prune -o \
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
  -type f \( -name '*_test.dart' -o -path '*/test/*.dart' -o -path '*/tests/*.dart' \) -print 2>/dev/null \
  | sort -u | xargs wc -l 2>/dev/null | awk 'END{print $1+0}')

RUST_LOC=$(find "$REPO_ROOT/server/memory" -name '*.rs' ! -path '*/tests/*' ! -path '*/target/*' -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')
RUST_TEST_LOC=$(find "$REPO_ROOT/server/memory" -name '*.rs' -path '*/tests/*' ! -path '*/target/*' -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')

TS_LOC=$(find "$REPO_ROOT/workers" -name '*.ts' \
  ! -path '*/node_modules/*' ! -path '*/test/*' ! -path '*/tests/*' ! -name '*.test.ts' \
  -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')
TS_TEST_LOC=$(find "$REPO_ROOT/workers" -name '*.ts' ! -path '*/node_modules/*' \
  \( -path '*/test/*' -o -path '*/tests/*' -o -name '*.test.ts' \) \
  -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')

# Bash tests: the tests/ tree — .bats suites plus their .sh harnesses.
BASH_TEST_LOC=$(find "$REPO_ROOT/tests" \( -name '*.bats' -o -name '*.sh' \) -type f 2>/dev/null \
  | xargs wc -l 2>/dev/null | awk 'END{print $1+0}')

# Bash tooling: git-TRACKED shell scripts, EXCLUDING the tests/ tree. A repo-wide
# find would sweep in gitignored vendored trees (.independent_repos, venv,
# fdroid_env, client iOS/Flutter tooling), inflating the count several-fold.
BASH_LOC=$( (cd "$REPO_ROOT" && git ls-files -z '*.sh' ':!:*/tests/*' | xargs -0 cat 2>/dev/null) | wc -l | tr -d ' ')

# Kept distinct rather than one "core" blob: TypeScript (Workers) runs on
# our Cloudflare account, not a self-hoster's device, unlike VPS/Mobile.
VPS_TOTAL=$((GO_LOC + RUST_LOC))
MOBILE_TOTAL=$DART_LOC
INFRA_TOTAL=$TS_LOC
CORE_TOTAL=$((VPS_TOTAL + MOBILE_TOTAL + INFRA_TOTAL))
TEST_TOTAL=$((GO_TEST_LOC + DART_TEST_LOC + RUST_TEST_LOC + TS_TEST_LOC + BASH_TEST_LOC))

{
echo ""
echo "---"
echo ""
echo "## 📊 Lines of Code"
echo ""
echo "**VPS** (runs on a self-hoster's own box):"
echo ""
echo "| Language | LoC | Component |"
echo "| :--- | ---: | :--- |"
echo "| Go | ${GO_LOC} | c1: PocketBase + ACP client + AG-UI server |"
echo "| Rust | ${RUST_LOC} | Pocket Memory (server/memory) |"
echo "| **VPS total** | **${VPS_TOTAL}** | Go + Rust |"
echo ""
echo "**Mobile** (runs on the user's phone, not the VPS):"
echo ""
echo "| Language | LoC | Component |"
echo "| :--- | ---: | :--- |"
echo "| Dart | ${DART_LOC} | Flutter client (non-generated, non-test) |"
echo ""
echo "**Infra** (FOSS, auditable, but runs centrally on our Cloudflare"
echo "account, not a self-hoster's own device — see CLAUDE.md's Deployment"
echo "Model):"
echo ""
echo "| Language | LoC | Component |"
echo "| :--- | ---: | :--- |"
echo "| TypeScript | ${TS_LOC} | Cloudflare Workers (workers/) |"
echo ""
echo "**Grand total (all product code):** ${CORE_TOTAL}"
echo ""
echo "**Tests** (not product code):"
echo ""
echo "| Type | LoC | Notes |"
echo "| :--- | ---: | :--- |"
echo "| Go tests | ${GO_TEST_LOC} | \`*_test.go\` |"
echo "| Dart tests | ${DART_TEST_LOC} | \`*_test.dart\`, \`test/\` |"
echo "| Rust tests | ${RUST_TEST_LOC} | \`server/memory/tests/\` |"
echo "| TypeScript tests | ${TS_TEST_LOC} | \`workers/**/test/\`, \`*.test.ts\` |"
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
echo "   Tagged index : $LOGIC_LOC LoC across $FILE_COUNT tagged files (+ $SCRIPT_LOC LoC bash)"
echo "   VPS (Go+Rust): $VPS_TOTAL LoC"
echo "   Mobile (Dart): $MOBILE_TOTAL LoC"
echo "   Infra (TS)   : $INFRA_TOTAL LoC"

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
| Go | $(fmt $GO_LOC) | VPS — c1: PocketBase + ACP client + AG-UI server |
| Rust | $(fmt $RUST_LOC) | VPS — Pocket Memory |
| **VPS total** | **~$(fmt $VPS_TOTAL)** | self-hosted server stack |
| Dart | $(fmt $DART_LOC) | Mobile — Flutter client (non-generated) |
| TypeScript | $(fmt $TS_LOC) | Infra — Cloudflare Workers (FOSS, runs on our account) |
| **Grand total** | **~$(fmt $CORE_TOTAL)** | VPS + Mobile + Infra — product code |
| Tests | $(fmt $TEST_TOTAL) | not code — Go $(fmt $GO_TEST_LOC) · Dart $(fmt $DART_TEST_LOC) · Rust $(fmt $RUST_TEST_LOC) · TS $(fmt $TS_TEST_LOC) · Bash $(fmt $BASH_TEST_LOC) |
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
