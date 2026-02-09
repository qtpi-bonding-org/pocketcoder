#!/bin/bash
set -e

echo "🔄 [Sovereign Docs] Starting polyglot documentation extraction..."

# Clean up previous extractions
rm -rf ./src/content/docs/reference
mkdir -p ./src/content/docs/reference

# Function to extract body content (skip H1 if present)
extract_body() {
  local file=$1
  if [ -f "$file" ]; then
    # Skip the first line (Title) to let Starlight handle it via frontmatter
    tail -n +2 "$file"
  else
    echo "⚠️ File not found: $file"
  fi
}

# 1. Sync Root Markdown Files
echo "📝 Syncing root guides..."

echo -e "---\ntitle: Architecture\ndescription: Detailed overview of PocketCoder's Sovereign Authority architecture.\n---\n" > ./src/content/docs/architecture.md
extract_body ../ARCHITECTURE.md >> ./src/content/docs/architecture.md

echo -e "---\ntitle: Development\ndescription: How to set up and build PocketCoder locally.\n---\n" > ./src/content/docs/development.md
extract_body ../DEVELOPMENT.md >> ./src/content/docs/development.md

# 2. Extract Go Docs (Backend)
echo "🐹 Extracting Go docs (backend)..."
echo -e "---\ntitle: Backend Reference\n---\n" > ./src/content/docs/reference/backend.md
if command -v gomarkdoc &> /dev/null; then
  gomarkdoc -u ../backend >> ./src/content/docs/reference/backend.md || echo "⚠️ Go doc extraction had warnings"
else
  echo "⚠️ gomarkdoc not found, skipping backend docs"
fi
LOC_BACKEND=$(find ../backend -name "*.go" | xargs wc -l | tail -n 1 | awk '{print $1}')
echo -e "\n\n**Lines of Code:** $LOC_BACKEND" >> ./src/content/docs/reference/backend.md

# 3. Extract Node.js Docs (Relay)
echo "🟢 Extracting Relay docs (Node.js)..."
echo -e "---\ntitle: Relay Reference\n---\n" > ./src/content/docs/reference/relay.md
if command -v documentation &> /dev/null; then
  documentation build ../relay/chat_relay.mjs -f md >> ./src/content/docs/reference/relay.md || echo "⚠️ JS doc extraction had warnings"
else
  echo "⚠️ documentation (js) not found, skipping relay docs"
fi
LOC_RELAY=$(find ../relay -name "*.mjs" -o -name "*.js" | xargs wc -l | tail -n 1 | awk '{print $1}')
echo -e "\n\n**Lines of Code:** $LOC_RELAY" >> ./src/content/docs/reference/relay.md

# 4. Extract Rust Docs (Proxy)
echo "🦀 Extracting Proxy docs (Rust)..."
echo -e "---\ntitle: Proxy Reference\n---\n" > ./src/content/docs/reference/proxy.md

if command -v cargo-rdme &> /dev/null; then
    current_dir=$(pwd)
    
    # Create a temp copy of proxy to allow cargo to write to target (since volume is ro)
    echo "📦 Copying proxy source to temp build dir..."
    rm -rf /tmp/proxy_build
    cp -r ../proxy /tmp/proxy_build
    cd /tmp/proxy_build

    # Try cargo-rdme with stdout
    if cargo rdme --stdout > /tmp/proxy_docs.md 2>/dev/null; then
        echo "✅ Used cargo-rdme"
        cat /tmp/proxy_docs.md >> "$current_dir/src/content/docs/reference/proxy.md"
        rm /tmp/proxy_docs.md
    else
        echo "⚠️ cargo-rdme failed or not configured, falling back to grep..."
        # Fallback to grep on the ORIGINAL source (or temp, doesn't matter)
        cd "$current_dir"
        grep "^///" ../proxy/src/main.rs | sed 's/^\/\/\///' | sed 's/^ //' >> ./src/content/docs/reference/proxy.md || true
    fi
    cd "$current_dir" || exit
    rm -rf /tmp/proxy_build
else
    # Fallback to grep
    echo "⚠️ cargo-rdme not found, falling back to grep..."
    grep "^///" ../proxy/src/main.rs | sed 's/^\/\/\///' | sed 's/^ //' >> ./src/content/docs/reference/proxy.md || true
fi
LOC_PROXY=$(find ../proxy/src -name "*.rs" | xargs wc -l | tail -n 1 | awk '{print $1}')
echo -e "\n\n**Lines of Code:** $LOC_PROXY" >> ./src/content/docs/reference/proxy.md

# 5. Update Landing Page with Total LOC
TOTAL_LOC=$((LOC_BACKEND + LOC_RELAY + LOC_PROXY))
echo "📊 Total Lines of Code: $TOTAL_LOC"

echo "📝 Updating index.mdx with real stats..."
cat > ./src/content/docs/index.mdx <<EOF
---
title: Welcome to PocketCoder
description: Get started building your personal AI assistant.
template: splash
hero:
  tagline: The Featherweight Industrial AI Agent Platform.
  actions:
    - text: Read the docs
      link: /architecture
      icon: right-arrow
      variant: primary
    - text: View on GitHub
      link: https://github.com/pocketcoder-ai/pocketcoder
      icon: external
---

import { Card, CardGrid } from '@astrojs/starlight/components';

## Next steps

<CardGrid stagger>
	<Card title="Sovereign Control" icon="shield">
		The reasoning engine is isolated from execution. You own the gatekeeper.
	</Card>
	<Card title="Featherweight" icon="setting">
		Only $TOTAL_LOC lines of core code. Easy to audit and maintain.
	</Card>
	<Card title="Local-First" icon="open-book">
		Designed to run on your own hardware or a private VPS.
	</Card>
</CardGrid>
EOF

echo "✅ [Sovereign Docs] Extraction complete."
