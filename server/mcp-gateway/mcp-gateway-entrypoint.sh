#!/bin/sh
set -e

# No `docker mcp catalog init` here on purpose: as of docker-mcp v0.43,
# that command no longer exists (prints catalog-subcommand help and does
# nothing), and its absence is what keeps mcp-find/mcp-add scoped to only
# what PocketBase's mcp_servers approval flow has actually rendered into
# the --catalog file -- v0.39.3's `catalog init` silently imported Docker's
# full public catalog at every boot, which is what let mcp-find leak
# servers no one approved. See spikes/mcp-gateway-v0.43-upgrade/README.md.
echo "Starting MCP Gateway with args: $@"
exec docker mcp gateway run "$@"
