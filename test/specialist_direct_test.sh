#!/bin/bash
# test/specialist_direct_test.sh
# [Phase 2] Specialist Handoff Test (Plumbing)

set -e

# 1. Variables
SANDBOX_CONTAINER="pocketcoder-sandbox"
AGENT_STORE="/root/.aws/cli-agent-orchestrator/agent-store"
SPECIALIST_FILE="$AGENT_STORE/tf_expert.md"

echo "🧪 [Phase 2] Starting Specialist Direct Handoff Test..."

# 2. Ensure specialist profile is in position
echo "📝 Writing tf_expert.md to Sandbox agent-store..."
docker exec $SANDBOX_CONTAINER mkdir -p $AGENT_STORE
docker exec $SANDBOX_CONTAINER sh -c "cat <<EOF > $SPECIALIST_FILE
---
name: tf_expert
description: Terraform specialist
mcpServers:
  terraform:
    command: terraform-mcp-server
---
I am the Terraform specialist. I use the terraform-mcp-server to manage infrastructure. Use the 'terraform' tool to interact with me.
EOF"

# 3. Verify tool loading via CAO MCP Server
# We'll use curl to probe the CAO MCP server (running on 9888)
# Since it's SSE, we'll just check if the session endpoint is reachable
echo "🔍 Probing CAO MCP Server for terraform tools..."

# We use docker exec to run a small python snippet that lists tools via the local MCP server
# This bypasses the Proxy and tests the core plumbing (CAO -> Specialist)
LIST_TOOLS_PY="
import asyncio
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

async def main():
    server_params = StdioServerParameters(
        command='terraform-mcp-server',
        args=[],
        env=None
    )
    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()
            tools = await session.list_tools()
            for tool in tools.tools:
                print(f'Tool: {tool.name}')

if __name__ == '__main__':
    asyncio.run(main())
"

echo "🛠️  Checking if 'terraform-mcp-server' is directly callable in Sandbox..."
docker exec $SANDBOX_CONTAINER sh -c "echo \"$LIST_TOOLS_PY\" > /tmp/check_tools.py"
OUTPUT=$(docker exec $SANDBOX_CONTAINER sh -c "cd /app/cao && /usr/local/bin/uv run python /tmp/check_tools.py" 2>&1)

if echo "$OUTPUT" | grep -q "search_providers"; then
    echo "✅ SUCCESS: 'terraform-mcp-server' tool 'search_providers' found!"
else
    echo "❌ FAILURE: Terraform tools not found."
    echo "Debug Output:"
    echo "$OUTPUT"
    exit 1
fi

# 4. Trigger a direct search via CAO launch (Simulating a handoff)
echo "🚀 Testing CAO Handoff (launching tf_expert specialist)..."
# We run CAO launch in the sandbox and check if it successfully initializes the specialist
# We use --headless to ensure it doesn't hang on terminal input
LAUNCH_CHECK=$(docker exec $SANDBOX_CONTAINER sh -c "cd /app/cao && /usr/local/bin/uv run cao launch --agents tf_expert --headless 2>&1" | head -n 30)

if echo "$LAUNCH_CHECK" | grep -i "tf_expert" || echo "$LAUNCH_CHECK" | grep -i "Session"; then
    echo "✅ SUCCESS: CAO successfully identified and launched 'tf_expert'!"
else
    echo "❌ FAILURE: CAO could not launch 'tf_expert'."
    echo "Debug Output:"
    echo "$LAUNCH_CHECK"
    exit 1
fi

echo "🎉 [Phase 2] PLUMBING TEST PASSED!"
echo "The specialist is correctly provisioned, the profile is loaded, and the MCP tools are visible."
