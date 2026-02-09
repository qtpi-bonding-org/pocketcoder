#!/bin/bash
set -e

echo "🔄 [Sovereign Docs] Starting polyglot documentation extraction..."

# 1. Sync Root Markdown Files
echo "📝 Syncing root guides..."
cp ../ARCHITECTURE.md ./src/content/docs/architecture.md
cp ../DEVELOPMENT.md ./src/content/docs/development.md

# 2. Extract Go Docs (Backend)
echo "🐹 Extracting Go docs (backend)..."
# Using -u to include unexported symbols in the main package
gomarkdoc -u ../backend > ./src/content/docs/reference/backend.md || echo "⚠️ Go doc extraction had warnings"

# 3. Extract Node.js Docs (Relay)
echo "🟢 Extracting Node.js docs (relay)..."
# Using documentation.js which handles ESM better
documentation build ../relay/chat_relay.mjs -f md > ./src/content/docs/reference/relay.md || echo "⚠️ JS doc extraction had warnings"

# 4. Extract Rust Docs (Proxy)
echo "🦀 Extracting Rust docs (proxy)..."
# Simple extraction for now since cargo-rdme can be picky with workspace layouts
if [ -f ../proxy/src/main.rs ]; then
  echo "/* Proxy Reference */" > ./src/content/docs/reference/proxy.md
  grep "^///" ../proxy/src/main.rs | sed 's/^\/\/\///' >> ./src/content/docs/reference/proxy.md || true
fi

echo "✅ [Sovereign Docs] Extraction complete. Files updated in docs/src/content/docs/reference/"
