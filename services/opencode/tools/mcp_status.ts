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

// @pocketcoder-core: MCP Status. Reports which MCP servers are currently live in the gateway.
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