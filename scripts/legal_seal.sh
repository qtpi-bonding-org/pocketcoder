#!/bin/bash
# scripts/legal_seal.sh
# @pocketcoder-core: Legal Seal. Ensures all tagged files have the AGPLv3 license header.
# This script is strictly surgical: ONLY Bash, Go, and Rust in core directories.

set -e

CHECK_MODE=false
if [ "$1" == "--check" ]; then
    CHECK_MODE=true
fi

LICENSE_TEXT="PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>."

# Configuration
TAG="@pocketcoder-core"
CORE_DIRS=("backend" "proxy" "sandbox" "scripts" "test")
ROOT_FILES=("genesis.sh" "deploy.sh")

if [ "$CHECK_MODE" = true ]; then
    echo "🔍 Verifying Legal Seals (Strict Mode: Bash, Go, Rust)..."
    MISSING_COUNT=0
else
    echo "🛡️  Applying Legal Seals (Strict Mode: Bash, Go, Rust)..."
fi

seal_file() {
    local FILE_PATH=$1
    
    # 0. Quick check for tag
    if ! grep -q "$TAG" "$FILE_PATH"; then
        return
    fi

    # 1. Check if license already exists
    if head -n 30 "$FILE_PATH" | grep -q "GNU Affero General Public License" ; then
        return
    fi

    if [ "$CHECK_MODE" = true ]; then
        echo "❌ MISSING: $FILE_PATH"
        MISSING_COUNT=$((MISSING_COUNT + 1))
        return
    fi

    echo "✍️  Sealing $FILE_PATH..."
    
    local EXT="${FILE_PATH##*.}"
    local HEADER_FILE=$(mktemp)
    
    # 2. Build Header (STRICT: sh, go, rs ONLY)
    case "$EXT" in
        sh)
            echo "$LICENSE_TEXT" | sed 's/^/# /' > "$HEADER_FILE"
            echo "" >> "$HEADER_FILE"
            ;;
        go|rs)
            echo "/*" > "$HEADER_FILE"
            echo "$LICENSE_TEXT" >> "$HEADER_FILE"
            echo "*/" >> "$HEADER_FILE"
            echo "" >> "$HEADER_FILE"
            ;;
        *)
            # Even if it has the tag, if it's not a core language, we skip for safety.
            rm "$HEADER_FILE"
            return
            ;;
    esac

    # 3. Assemble File
    local TEMP_OUT=$(mktemp)
    local FIRST_LINE=$(head -n 1 "$FILE_PATH")
    
    if [[ "$FIRST_LINE" == "#!"* ]]; then
        echo "$FIRST_LINE" > "$TEMP_OUT"
        echo "" >> "$TEMP_OUT"
        cat "$HEADER_FILE" >> "$TEMP_OUT"
        tail -n +2 "$FILE_PATH" >> "$TEMP_OUT"
    else
        cat "$HEADER_FILE" > "$TEMP_OUT"
        cat "$FILE_PATH" >> "$TEMP_OUT"
    fi

    mv "$TEMP_OUT" "$FILE_PATH"
    rm "$HEADER_FILE"
    echo "✅ Sealed $FILE_PATH"
}

# Collect and process candidates with path-level exclusions
for DIR in "${CORE_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        # Find ONLY .sh, .go, .rs files
        # Skip 'sandbox/cao' and other noise directories at the find level
        find "$DIR" -path "*/sandbox/cao" -prune -o -type f \( -name "*.go" -o -name "*.rs" -o -name "*.sh" \) -print | while read -r f; do
            seal_file "$f"
        done
    fi
done

for f in "${ROOT_FILES[@]}"; do
    if [ -f "$f" ]; then
        seal_file "$f"
    fi
done

if [ "$CHECK_MODE" = true ]; then
    if [ "$MISSING_COUNT" -gt 0 ]; then
        echo "🚩 Found $MISSING_COUNT files missing the legal seal."
        exit 1
    else
        echo "✨ All core source files are correctly sealed."
    fi
else
    echo "🎉 Legal Seal process complete."
fi
