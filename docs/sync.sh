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
(cd .. && bash scripts/generate_audit.sh)

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
  # gomarkdoc works best when run from the module root for all packages
  # We use --include-unexported if we want maximum context for the "Sovereign Audit"
  (cd ../backend && gomarkdoc --include-unexported ./...) >> ./src/content/docs/reference/backend.md || echo "⚠️ Go doc extraction had warnings"
else
  echo "❌ Error: gomarkdoc not found"
fi

# 3. Extract Proxy Docs (Rust)
echo "🦀 Generating High-Fidelity Proxy docs (Rust)..."
# We generate rustdoc JSON first (requires stable + bootstrap for unstable flags)
(cd ../proxy && RUSTC_BOOTSTRAP=1 cargo rustdoc -- -Z unstable-options --output-format json) || echo "⚠️ RustDoc JSON generation failed"

echo -e "---\ntitle: Proxy Reference\nhead: []\n---\n" > ./src/content/docs/reference/proxy.md

if command -v cargo-docs-md &> /dev/null; then
  echo "📦 Converting rustdoc JSON to Markdown..."
  # Generate to a temporary location
  mkdir -p /tmp/proxy_docs
  (cd ../proxy && cargo docs-md --path target/doc/pocketcoder_proxy.json --output /tmp/proxy_docs)
  
  # Concatenate the results into our reference file
  # Primary index first
  cat /tmp/proxy_docs/index.md >> ./src/content/docs/reference/proxy.md
  
  # Then append submodules
  for mod_dir in /tmp/proxy_docs/*/; do
    if [ -d "$mod_dir" ]; then
      mod_name=$(basename "$mod_dir")
      echo -e "\n\n---\n# Module: $mod_name\n" >> ./src/content/docs/reference/proxy.md
      cat "$mod_dir/index.md" >> ./src/content/docs/reference/proxy.md
    fi
  done
else
  echo "❌ Error: cargo-docs-md not found"
fi

# 4. Extract Stats and Update Landing Page
# Extract TOTAL_CORE from the generated CODEBASE.md
TOTAL_CORE=$(grep "Total Original Footprint:" ../CODEBASE.md | awk '{print $4}')
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
