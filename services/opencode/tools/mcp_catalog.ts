/*
PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
Copyright (C) 2026 Qtpi Bonding LLC

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

// @pocketcoder-core: MCP Catalog Browser. Lets Poco discover available Docker MCP servers.
import { tool } from "@opencode-ai/plugin"

export default tool({
  description: "Browse or search the Docker MCP Catalog to discover available MCP servers. Returns the names and descriptions of all matching servers.",
  args: {
    query: tool.schema.string().optional().describe("Optional search term to filter servers (checks both name and description)"),
  },
  async execute(args) {
    try {
      // Use direct docker binary to bypass shell bridge noise
      const process = Bun.spawn(["docker", "mcp", "catalog", "show", "docker-mcp", "--format", "json"])
      const stdout = (await new Response(process.stdout).text()).trim()

      if (!stdout) {
        return "The MCP catalog is empty or unreachable."
      }

      const catalog = JSON.parse(stdout)
      const registry = catalog.registry || catalog
      const servers = Object.entries(registry)

      if (args.query) {
        const q = args.query.toLowerCase()
        const filtered = servers.filter(([name, entry]: [string, any]) =>
          name.toLowerCase().includes(q) ||
          (entry.description && entry.description.toLowerCase().includes(q))
        )

        if (filtered.length === 0) {
          return `No MCP servers found matching '${args.query}'.`
        }

        let output = `### Matching MCP Servers (${filtered.length})\n\n`
        filtered.forEach(([name, entry]: [string, any]) => {
          output += `- **${name}**: ${entry.description || "No description"}\n`
        })
        return output
      } else {
        // List ALL servers (no truncation per user request)
        let output = `### All Available MCP Servers (${servers.length})\n\n`
        servers.forEach(([name, entry]: [string, any]) => {
          output += `- **${name}**: ${entry.description || "No description"}\n`
        })
        return output
      }
    } catch (e) {
      console.error("Error browsing MCP catalog:", e)
      return `Failed to browse MCP catalog: ${e}`
    }
  },
})