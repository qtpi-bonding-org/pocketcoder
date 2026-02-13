#!/bin/bash
# scripts/generate_audit.sh
# @pocketcoder-core: Audit Generator. Programmatically builds the index of original code.
# Dynamically generates CODEBASE.md by searching for @pocketcoder-core tags in headers.

TARGET_FILE="CODEBASE.md"

cat > $TARGET_FILE <<EOF
# 🦅 The Sovereign Audit (Original Code Index)

This document is **programmatically generated**. It lists files explicitly tagged with \`@pocketcoder-core\`.
If a file isn't on this list, it's a third-party dependency (like PocketBase or CAO).

## 🏛️ Original Logic Index

| File | Tech | Role |
| :--- | :--- | :--- |
EOF

# Find all files with the tag, excluding the script itself and vendor/ignored dirs
# Logic: Look for "@pocketcoder-core:" and capture the description following it.
grep -r "@pocketcoder-core:" . \
    --exclude-dir={.git,.independent_repos,node_modules,pb_data,target,dist} \
    --exclude="scripts/generate_audit.sh" \
    --exclude="CODEBASE.md" | while read -r line; do
    
    # Parse file path
    FILE_PATH=$(echo "$line" | cut -d: -f1 | sed 's|^\./||')
    
    # Parse description (everything after the tag)
    # We use a greedy match but try to be careful about the separator
    DESCRIPTION=$(echo "$line" | grep -o "@pocketcoder""-core: .*" | cut -d: -f2- | sed 's/^ //')
    
    if [[ -z "$DESCRIPTION" ]]; then continue; fi

    # Determine tech based on extension
    EXT="${FILE_PATH##*.}"
    case "$EXT" in
        go)  TECH="Go" ;;
        rs)  TECH="Rust" ;;
        sh)  TECH="Bash" ;;
        py)  TECH="Python" ;;
        ts)  TECH="TypeScript" ;;
        *)   TECH="Other" ;;
    esac

    # Add row to table (check for duplicates if headers have multiple lines)
    if ! grep -q "\`$FILE_PATH\`" $TARGET_FILE; then
        echo "| \`$FILE_PATH\` | $TECH | $DESCRIPTION |" >> $TARGET_FILE
    fi
done

echo -e "\n---\n*Total Original Footprint: $(wc -l < $TARGET_FILE | awk '{print $1 - 10}') tagged files.*" >> $TARGET_FILE

echo "✅ [Audit] Generated $TARGET_FILE from source tags."
