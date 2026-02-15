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
# Strict Mode: ONLY indexes .sh, .go, and .rs files in core directories.

TARGET_FILE="CODEBASE.md"
TAG="@pocketcoder-core"
CORE_DIRS=("backend" "proxy" "sandbox" "scripts" "test")
ROOT_FILES=("genesis.sh" "deploy.sh")

cat > $TARGET_FILE <<EOF
# 🦅 The Sovereign Audit (Original Code Index)

This document is **programmatically generated**. It lists files explicitly tagged with \`@pocketcoder-core\`.
If a file isn't on this list, it's a third-party dependency (like PocketBase or CAO).

## 🏛️ Original Logic Index

| File | Tech | Role |
| :--- | :--- | :--- |
EOF

LOGIC_LOC=0
TEST_LOC=0
FILE_COUNT=0

# Collect files and process
for DIR in "${CORE_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        # Strict find: exclude sandbox/cao submodule, only target source languages
        find "$DIR" -path "*/sandbox/cao" -prune -o -type f \( -name "*.go" -o -name "*.rs" -o -name "*.sh" \) -print | while read -r FILE_PATH; do
            
            # Simple check for the tag
            TAG_LINE=$(grep "$TAG:" "$FILE_PATH" | head -n 1 || true)
            
            if [[ -n "$TAG_LINE" ]]; then
                # Parse description (everything after the tag)
                DESCRIPTION=$(echo "$TAG_LINE" | sed -n "s/.*$TAG: //p" | sed 's/ \*\/$//; s/ -->$//')
                
                if [[ -z "$DESCRIPTION" ]]; then continue; fi

                # Determine tech
                EXT="${FILE_PATH##*.}"
                case "$EXT" in
                    go)  TECH="Go" ;;
                    rs)  TECH="Rust" ;;
                    sh)  TECH="Bash" ;;
                    *)   TECH="Other" ;;
                esac

                # Add row to table
                if ! grep -q "|\`$FILE_PATH\`|" $TARGET_FILE; then
                    echo "| \`$FILE_PATH\` | $TECH | $DESCRIPTION |" >> $TARGET_FILE
                    
                    # Update metrics
                    LINES=$(wc -l < "$FILE_PATH" | awk '{print $1}')
                    if [[ "$TECH" == "Bash" ]]; then
                        TEST_LOC=$((TEST_LOC + LINES))
                    else
                        LOGIC_LOC=$((LOGIC_LOC + LINES))
                    fi
                    FILE_COUNT=$((FILE_COUNT + 1))
                    
                    # Pass variables out of the while loop subshell
                    echo "$LOGIC_LOC:$TEST_LOC:$FILE_COUNT" > /tmp/audit_counts
                fi
            fi
        done
        # Read subshell counts
        if [ -f /tmp/audit_counts ]; then
            IFS=':' read -r LOGIC_LOC TEST_LOC FILE_COUNT < /tmp/audit_counts
        fi
    fi
done

for f in "${ROOT_FILES[@]}"; do
    if [ -f "$f" ]; then
        FILE_PATH="$f"
        TAG_LINE=$(grep "$TAG:" "$FILE_PATH" | head -n 1 || true)
        if [[ -n "$TAG_LINE" ]]; then
            DESCRIPTION=$(echo "$TAG_LINE" | sed -n "s/.*$TAG: //p")
            echo "| \`$FILE_PATH\` | Bash | $DESCRIPTION |" >> $TARGET_FILE
            
            LINES=$(wc -l < "$FILE_PATH" | awk '{print $1}')
            TEST_LOC=$((TEST_LOC + LINES))
            FILE_COUNT=$((FILE_COUNT + 1))
        fi
    fi
done

echo -e "\n---\n*Total Original Footprint: $LOGIC_LOC lines of core logic, $TEST_LOC lines of testing/infra ($FILE_COUNT tagged files).*" >> $TARGET_FILE

echo "✅ [Audit] Generated $TARGET_FILE from source tags (Strict Mode)."
rm -f /tmp/audit_counts
