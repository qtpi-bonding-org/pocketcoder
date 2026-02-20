import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Browse the Docker MCP Catalog to discover available MCP servers. Returns the full list of servers available for installation.",
  args: {
    search: tool.schema.string().optional().describe("Optional search term to filter servers"),
  },
  async execute(args) {
    const cmd = args.search
      ? `docker mcp catalog show docker-mcp 2>&1 | grep -i "${args.search}"`
      : `docker mcp catalog show docker-mcp 2>&1`
    const result = await Bun.shell([`${cmd}`]).text()
    return result.trim()
  },
})