# CAO MCP Integration Architecture

## Overview
Poco (head agent) can now spawn and coordinate sub-agents using the CAO (CLI Agent Orchestrator) framework.

## Architecture

```
┌─────────────────────────────────────┐
│   OpenCode Container (Poco)         │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Poco (Head Agent)           │  │
│  │  - Gemini 2.0 Flash          │  │
│  │  - Gated Execution           │  │
│  └──────────┬───────────────────┘  │
│             │ uses MCP tools       │
│  ┌──────────▼───────────────────┐  │
│  │  cao-mcp-server (local)      │  │
│  │  - handoff (sync)            │  │
│  │  - assign (async)            │  │
│  │  - send_message              │  │
│  └──────────┬───────────────────┘  │
└─────────────┼───────────────────────┘
              │ HTTP to sandbox:9889
┌─────────────▼───────────────────────┐
│   Sandbox Container (Workers)       │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  cao-server (HTTP API)       │  │
│  │  - Port 9889                 │  │
│  │  - Manages tmux sessions     │  │
│  └──────────┬───────────────────┘  │
│             │ spawns               │
│  ┌──────────▼───────────────────┐  │
│  │  Sub-Agents (OpenCode)       │  │
│  │  - Run in tmux windows       │  │
│  │  - Report back to Poco       │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Components

### OpenCode Container
- **Poco**: Primary agent with Gemini 2.0 Flash
- **cao-mcp-server**: MCP wrapper providing orchestration tools
- **CAO**: Installed via uv for MCP server functionality

### Sandbox Container
- **cao-server**: HTTP API (port 9889) for session management
- **OpenCode CLI**: For running sub-agents
- **tmux**: Session isolation and management

## MCP Tools Available to Poco

### `cao_handoff`
Synchronous task delegation. Poco waits for the sub-agent to complete and returns results.

**Use case**: Sequential workflows where results are needed immediately.

### `cao_assign`
Asynchronous task spawning. Poco continues working while sub-agent runs in parallel.

**Use case**: Parallel research, testing, or analysis tasks.

### `cao_send_message`
Direct communication with existing sub-agents.

**Use case**: Iterative feedback or multi-turn collaboration.

## Security Model

- **All CAO tools require permission** (`cao_*: ask`)
- **Gated execution maintained**: Sub-agent spawning goes through approval
- **Chain of command**: Sub-agents report to Poco, not directly to the user
- **Bunker mentality**: All agents inherit Poco's paranoid security posture

## Configuration

### opencode.config.json
```json
{
  "mcp": {
    "cao": {
      "type": "local",
      "command": ["uv", "run", "--directory", "/app/cao", "cao-mcp-server"],
      "enabled": true,
      "environment": {
        "CAO_ENABLE_WORKING_DIRECTORY": "false",
        "SERVER_HOST": "sandbox",
        "SERVER_PORT": "9889"
      }
    }
  },
  "permission": {
    "cao_*": "ask"
  }
}
```

## Testing

Run the integration test:
```bash
./test/cao_mcp_test.sh
```

This verifies:
- CAO is installed in both containers
- cao-server is running in sandbox
- MCP server can communicate with cao-server
- OpenCode configuration is correct

## Next Steps

1. **Create agent profiles**: Define specialized sub-agents (researcher, tester, etc.)
2. **Test delegation**: Have Poco spawn a simple sub-agent
3. **Monitor performance**: Ensure sub-agents don't overwhelm resources
4. **Refine permissions**: Adjust which CAO operations require approval
