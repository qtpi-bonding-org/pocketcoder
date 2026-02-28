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

# scripts/generate_audit.sh
# @pocketcoder-core: Audit Generator. Programmatically builds the index of original code.
#
# Counts lines of code across PocketCoder core components.
# EXCLUDES: bash scripts, .bats files, test files. Those are tallied separately.
# For services/sandbox/cao: counts lines ADDED vs awslabs/cli-agent-orchestrator upstream.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_FILE="$REPO_ROOT/CODEBASE.md"
TAG="@pocketcoder-core"

# ---------------------------------------------------------------------------
# Core source directories to scan for the tag index (new services/ layout)
# ---------------------------------------------------------------------------
CORE_DIRS=(
  "services/pocketbase"
  "services/proxy"
  "services/sandbox"   # entrypoint.sh, sync_keys.sh (not cao submodule python — handled below)
  "services/opencode"
  "services/mcp-gateway"
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

This document is **programmatically generated** by `scripts/generate_audit.sh`.
It lists files explicitly tagged with `@pocketcoder-core`.
If a file isn't on this list, it's either a third-party dependency or unlabelled infra.

> **Counting rules**: Core logic = Go / Rust / TypeScript / Python / Dart.
> Shell scripts are tallied separately. Tests are excluded from both counts.
> The `sandbox/cao` forked submodule is measured as a diff vs [awslabs/cli-agent-orchestrator](https://github.com/awslabs/cli-agent-orchestrator).

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

  # Skip CAO python files — handled via git diff below
  if [[ "$REL_PATH" == services/sandbox/cao/* ]]; then
    return
  fi

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
# CAO submodule: diff vs awslabs upstream
# ---------------------------------------------------------------------------
CAO_DIR="$REPO_ROOT/services/sandbox/cao"
CAO_ADDED=0
CAO_DELETED=0
CAO_NOTE="(skipped)"

if [[ -d "$CAO_DIR/.git" || -f "$CAO_DIR/.git" ]]; then
  cd "$CAO_DIR"

  # Ensure upstream remote exists
  if ! git remote get-url upstream &>/dev/null; then
    git remote add upstream https://github.com/awslabs/cli-agent-orchestrator.git
  fi

  # Fetch silently; tolerate offline
  if git fetch upstream main --quiet 2>/dev/null; then
    NUMSTAT=$(git diff upstream/main HEAD --numstat -- '*.py' 2>/dev/null || true)
    if [[ -n "$NUMSTAT" ]]; then
      CAO_ADDED=$(echo "$NUMSTAT" | awk '{a+=$1} END{print a+0}')
      CAO_DELETED=$(echo "$NUMSTAT" | awk '{d+=$2} END{print d+0}')
    fi
    CAO_NOTE="+${CAO_ADDED} added / -${CAO_DELETED} removed vs upstream"

    # List tagged py files in the diff (new/modified, not deleted)
    while IFS= read -r PY_FILE; do
      ABS_PY="$CAO_DIR/$PY_FILE"
      [[ -f "$ABS_PY" ]] && scan_file "$ABS_PY"
    done < <(git diff upstream/main HEAD --name-only -- '*.py' 2>/dev/null | grep -v '^test/' || true)
  else
    CAO_NOTE="(offline — upstream fetch skipped)"
  fi
  cd "$REPO_ROOT"
fi

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
GO_LOC=$(find "$REPO_ROOT/services/pocketbase" -name '*.go' ! -path '*/tests/*' -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')
RUST_LOC=$(find "$REPO_ROOT/services/proxy/src" -name '*.rs' -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')
TS_LOC=$(find "$REPO_ROOT/services/opencode/tools" "$REPO_ROOT/services/opencode/plugins" -name '*.ts' -exec wc -l {} + 2>/dev/null | awk 'END{print $1+0}')

# Bash: all project shell scripts excluding cao submodule, node_modules, tests
BASH_LOC=$(find "$REPO_ROOT" \
  -path "$REPO_ROOT/services/sandbox/cao" -prune -o \
  -path "$REPO_ROOT/node_modules" -prune -o \
  -path "$REPO_ROOT/client/node_modules" -prune -o \
  -path "*/tests/*" -prune -o \
  -path "*/.git/*" -prune -o \
  -type f -name '*.sh' -print \
  | xargs wc -l 2>/dev/null | awk 'END{print $1+0}')

# Core total = Go + Rust + TS + Python (CAO added) + Dart (non-generated)
CORE_TOTAL=$((GO_LOC + RUST_LOC + TS_LOC + CAO_ADDED + DART_LOC))

{
echo ""
echo "---"
echo ""
echo "## 📊 Lines of Code by Language"
echo ""
echo "| Language | LoC | Notes |"
echo "| :--- | ---: | :--- |"
echo "| Go | ${GO_LOC} | PocketBase backend & relay |"
echo "| Rust | ${RUST_LOC} | Sentinel Proxy |"
echo "| TypeScript | ${TS_LOC} | OpenCode MCP tools |"
echo "| Python | ${CAO_ADDED} added / -${CAO_DELETED} removed | CAO fork delta vs [awslabs upstream](https://github.com/awslabs/cli-agent-orchestrator) |"
echo "| Dart | ${DART_LOC} | Flutter client (non-generated, non-test) |"
echo "| Bash | ${BASH_LOC} | Shell scripts (infra / helpers, not counted in core) |"
echo "| **Core total** | **${CORE_TOTAL}** | Go + Rust + TS + Python delta + Dart |"
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
