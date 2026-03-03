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

// @pocketcoder-core: Update Checker. Checks the Codeberg repo for new commits/releases.
import { tool } from "@opencode-ai/plugin"

const CODEBERG_API = "https://codeberg.org/api/v1/repos/qtpi-bonding-org/pocketcoder"

export default tool({
  description: "Check for PocketCoder updates from the official Codeberg repository. Shows recent commits on main and any releases. Use this when the user asks about updates, or occasionally to keep them informed.",
  args: {
    count: tool.schema.number().optional().default(10).describe("Number of recent commits to show"),
  },
  async execute(args) {
    const results: string[] = []

    // Fetch latest releases
    try {
      const relResp = await fetch(`${CODEBERG_API}/releases?limit=3`)
      if (relResp.ok) {
        const releases = await relResp.json()
        if (releases.length > 0) {
          results.push("## Latest Releases\n")
          for (const r of releases) {
            const date = new Date(r.published_at).toLocaleDateString()
            results.push(`- **${r.tag_name}** (${date}): ${r.name || "No title"}`)
            if (r.body) results.push(`  ${r.body.slice(0, 200)}`)
          }
          results.push("")
        }
      }
    } catch { /* releases not critical */ }

    // Fetch recent commits on main
    try {
      const commitResp = await fetch(`${CODEBERG_API}/commits?sha=main&limit=${args.count}`)
      if (!commitResp.ok) {
        return `Failed to check for updates (HTTP ${commitResp.status}). The Codeberg API may be temporarily unavailable.`
      }
      const commits = await commitResp.json()
      results.push(`## Recent Commits on main (${commits.length})\n`)
      for (const c of commits) {
        const sha = c.sha.slice(0, 7)
        const date = new Date(c.created).toLocaleDateString()
        const msg = c.commit.message.split("\n")[0]
        results.push(`- \`${sha}\` (${date}) ${msg}`)
      }
    } catch (e) {
      return `Failed to reach Codeberg: ${e}. Check network connectivity.`
    }

    results.push(`\n---\nSource: codeberg.org/qtpi-bonding-org/pocketcoder`)
    return results.join("\n")
  },
})
