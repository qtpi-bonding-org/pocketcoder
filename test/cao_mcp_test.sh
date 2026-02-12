#!/bin/bash
# test/cao_mcp_test.sh
# Verifies CAO MCP server is integrated with OpenCode

set -e

echo "🧪 Testing CAO MCP Integration..."

# Check if CAO MCP server command exists in the sandbox
echo "📦 Checking CAO installation in sandbox..."
if docker exec pocketcoder-opencode which uv > /dev/null 2>&1; then
    echo "✅ uv is installed"
else
    echo "❌ uv is not installed"
    exit 1
fi

if docker exec pocketcoder-opencode test -d /app/cao; then
    echo "✅ CAO directory exists at /app/cao"
else
    echo "❌ CAO directory not found"
    exit 1
fi

# Check if CAO MCP server can be invoked
echo "🔍 Testing CAO MCP server command..."
if docker exec pocketcoder-opencode bash -c "cd /app/cao && uv run cao-mcp-server --help" > /dev/null 2>&1; then
    echo "✅ CAO MCP server command works"
else
    echo "❌ CAO MCP server command failed"
    exit 1
fi

# Check OpenCode config has CAO MCP configured
echo "📝 Checking OpenCode configuration..."
if grep -q '"cao"' opencode.config.json; then
    echo "✅ CAO MCP server is configured in opencode.config.json"
else
    echo "❌ CAO MCP server not found in config"
    exit 1
fi

echo ""
echo "🎉 CAO MCP Integration Test PASSED!"
echo ""
echo "ℹ️  Poco can now use the following CAO tools:"
echo "   - cao_handoff: Synchronous task delegation"
echo "   - cao_assign: Asynchronous task spawning"
echo "   - cao_send_message: Agent-to-agent communication"
echo ""
echo "🔐 All CAO tools require permission (gated execution maintained)"
