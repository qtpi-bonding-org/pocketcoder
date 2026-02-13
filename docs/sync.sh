#!/bin/bash
set -e

echo "🔄 [Sovereign Docs] Starting polyglot documentation extraction..."

# Clean up previous extractions
rm -rf ./src/content/docs/reference
rm -rf ./src/content/docs/guides
rm -f ./src/content/docs/*.md ./src/content/docs/*.mdx
mkdir -p ./src/content/docs/reference
mkdir -p ./src/content/docs/guides

# Programmatically generate Codebase Audit
echo "🦅 Generating Sovereign Audit..."
(cd .. && ./scripts/generate_audit.sh)

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

echo -e "---\ntitle: Architecture\ndescription: Detailed overview of PocketCoder's Sovereign Authority architecture.\nhead: []\n---\n" > ./src/content/docs/architecture.md
extract_body ../ARCHITECTURE.md >> ./src/content/docs/architecture.md

echo -e "---\ntitle: Development\ndescription: How to set up and build PocketCoder locally.\nhead: []\n---\n" > ./src/content/docs/development.md
extract_body ../DEVELOPMENT.md >> ./src/content/docs/development.md

echo -e "---\ntitle: Sovereign Audit\ndescription: Complete index of original PocketCoder files.\nhead: []\n---\n" > ./src/content/docs/codebase.md
extract_body ../CODEBASE.md >> ./src/content/docs/codebase.md

echo -e "---\ntitle: Security Architecture\ndescription: How PocketCoder enforces sovereign isolation.\nhead: []\n---\n" > ./src/content/docs/security.md
extract_body ../SECURITY.md >> ./src/content/docs/security.md

# 1b. Sync Guides
echo "📖 Syncing guides..."
for guide in ./guides/*.md; do
  if [ -f "$guide" ]; then
    name=$(basename "$guide" .md)
    title=$(echo "$name" | sed 's/_/ /g' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    echo -e "---\ntitle: $title\nhead: []\n---\n" > "./src/content/docs/guides/$name.md"
    extract_body "$guide" >> "./src/content/docs/guides/$name.md"
  fi
done

# 2. Extract Go Docs (Backend & Relay)
echo "🐹 Extracting Go docs..."
echo -e "---\ntitle: Backend Reference\nhead: []\n---\n" > ./src/content/docs/reference/backend.md
if command -v gomarkdoc &> /dev/null; then
  gomarkdoc -u ../backend/internal/... >> ./src/content/docs/reference/backend.md || echo "⚠️ Go doc extraction had warnings"
else
  echo "⚠️ gomarkdoc not found, skipping backend docs"
fi

LOC_RELAY=$(find ../backend/pkg/relay -name "*.go" | xargs wc -l | tail -n 1 | awk '{print $1}')
LOC_BACKEND=$(find ../backend/internal -name "*.go" | xargs wc -l | tail -n 1 | awk '{print $1}')
LOC_BACKEND_MAIN=$(wc -l ../backend/main.go | awk '{print $1}')
LOC_BACKEND=$((LOC_BACKEND + LOC_BACKEND_MAIN))

echo -e "\n\n**Lines of Code (Core):** $LOC_BACKEND" >> ./src/content/docs/reference/backend.md
echo -e "**Lines of Code (Relay):** $LOC_RELAY" >> ./src/content/docs/reference/backend.md

# 3. Extract Proxy Docs (Rust)
echo "🦀 Extracting Proxy docs (Rust)..."
echo -e "---\ntitle: Proxy Reference\nhead: []\n---\n" > ./src/content/docs/reference/proxy.md
echo -e "Detailed documentation for the Rust-based Sovereign Proxy.\n" >> ./src/content/docs/reference/proxy.md

# Extract high-level module docs and public functions
grep -E "^\s*///" ../proxy/src/main.rs | sed 's/^\s*\/\/\///' >> ./src/content/docs/reference/proxy.md
echo -e "\n### Public Interface (Main)\n" >> ./src/content/docs/reference/proxy.md
grep -E "^\s*pub (async )?fn" ../proxy/src/main.rs | sed 's/^\s*//' | sed 's/ {\s*$//' | sed 's/$/;/' | sed 's/^/- `/' | sed 's/$/`/' >> ./src/content/docs/reference/proxy.md

LOC_PROXY=$(wc -l ../proxy/src/main.rs | awk '{print $1}')
echo -e "\n\n**Lines of Code:** $LOC_PROXY" >> ./src/content/docs/reference/proxy.md

# 4. Extract Sandbox Stats (Original Glue Only)
echo "🏗️ Extracting Sandbox stats..."
LOC_SH=$(wc -l ../sandbox/entrypoint.sh ../sandbox/sync_keys.sh | tail -n 1 | awk '{print $1}')
LOC_PY=$(wc -l ../sandbox/cao/src/cli_agent_orchestrator/providers/opencode.py | awk '{print $1}')
LOC_SANDBOX=$((LOC_SH + LOC_PY))

# 5. Extract Client Stats (Flutter)
echo "📱 Extracting Client stats..."
LOC_CLIENT=$(find ../client/lib -name "*.dart" | xargs wc -l | tail -n 1 | awk '{print $1}')

# 6. Update Landing Page with Total LOC
TOTAL_CORE=$((LOC_BACKEND + LOC_RELAY + LOC_PROXY + LOC_SANDBOX))
echo "📊 Total Core Lines of Code: $TOTAL_CORE"

echo "📝 Updating index.mdx with real stats..."
cat > ./src/content/docs/index.mdx <<EOF
---
title: Welcome to PocketCoder
description: A personal research lab for Sovereign AI.
head: []
template: splash
hero:
  tagline: A Minimalist Sovereign AI Assistant Lab.
  actions:
    - text: Read the docs
      link: /architecture
      icon: right-arrow
      variant: primary
    - text: View on GitHub
      link: https://github.com/qtpi-bonding-org/pocketcoder
      icon: external
---

import { Card, CardGrid } from '@astrojs/starlight/components';

## Next steps

<CardGrid stagger>
	<Card title="Sovereign Control" icon="shield">
		The reasoning engine is isolated from execution. You own the gatekeeper.
	</Card>
	<Card title="Minimalist" icon="setting">
		Only ~$TOTAL_CORE lines of original code. Built by a solo dev for auditability.
	</Card>
	<Card title="Multi-Platform" icon="laptop">
		Full Flutter client available for Mobile and Web.
	</Card>
	<Card title="Local-First" icon="open-book">
		Designed to run on your own hardware or a private VPS.
	</Card>
</CardGrid>
EOF

echo "✅ [Sovereign Docs] Extraction complete."
