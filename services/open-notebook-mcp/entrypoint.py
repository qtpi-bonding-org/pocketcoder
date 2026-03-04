"""Custom entrypoint for open-notebook-mcp with streamable HTTP transport.

The upstream open-notebook-mcp passes host/port kwargs to FastMCP.run(),
but MCP SDK v1.26+ dropped those parameters. This entrypoint uses uvicorn
directly to serve the streamable HTTP app.

We also disable DNS rebinding protection since this runs inside a Docker
network and needs to accept requests from container hostnames.
"""

import os
import uvicorn

# Import the pre-configured FastMCP instance from open-notebook-mcp
from open_notebook_mcp.server import mcp

host = os.getenv("HOST", "0.0.0.0")
port = int(os.getenv("PORT", "8000"))

# Disable DNS rebinding protection for Docker networking
# Container-to-container calls use hostnames like "open-notebook-mcp:8000"
mcp.settings.transport_security.enable_dns_rebinding_protection = False

app = mcp.streamable_http_app()

if __name__ == "__main__":
    uvicorn.run(app, host=host, port=port)
