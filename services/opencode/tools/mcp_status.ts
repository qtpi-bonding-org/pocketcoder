import { tool } from "@opencode-ai/plugin"
import { readFile } from "fs/promises"

export default tool({
  description: "Check which MCP servers are currently enabled in the gateway. Reads the live config.",
  args: {},
  async execute() {
    try {
      const config = await readFile("/mcp_config/docker-mcp.yaml", "utf-8")
      return `Currently enabled MCP servers:\n${config}`
    } catch {
      return "No MCP servers are currently enabled (config not found)."
    }
  },
})