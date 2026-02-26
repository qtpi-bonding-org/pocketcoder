import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Check which MCP servers are currently enabled in the gateway. Reads the live config.",
  args: {},
  async execute() {
    try {
      const config = await Bun.file("/mcp_config/docker-mcp.yaml").text()
      return `Currently enabled MCP servers:\n${config}`
    } catch {
      return "No MCP servers are currently enabled (config not found)."
    }
  },
})