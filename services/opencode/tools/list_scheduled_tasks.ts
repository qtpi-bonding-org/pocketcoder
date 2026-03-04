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

// @pocketcoder-core: List Scheduled Tasks Tool. Shows all cron jobs for the current user.
import { tool } from "@opencode-ai/plugin"

let cachedToken: string | null = null

async function getAgentToken(): Promise<string> {
  if (cachedToken) return cachedToken
  const pbUrl = process.env.POCKETBASE_URL || "http://pocketbase:8090"
  const resp = await fetch(`${pbUrl}/api/collections/users/auth-with-password`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      identity: process.env.AGENT_EMAIL,
      password: process.env.AGENT_PASSWORD,
    }),
  })
  if (!resp.ok) throw new Error(`Agent auth failed: ${resp.status}`)
  const data = await resp.json()
  cachedToken = data.token
  return cachedToken!
}

export default tool({
  description: "List all scheduled tasks for the current user. Shows active and disabled cron jobs with their schedules and last execution status.",
  args: {},
  async execute(_args, context) {
    const pbUrl = process.env.POCKETBASE_URL || "http://pocketbase:8090"
    const token = await getAgentToken()

    const resp = await fetch(`${pbUrl}/api/pocketcoder/scheduled_tasks?session_id=${encodeURIComponent(context.sessionID)}`, {
      headers: {
        "Authorization": `Bearer ${token}`,
      },
    })

    if (!resp.ok) {
      const err = await resp.text()
      return `Failed to list scheduled tasks: ${err}`
    }

    const tasks = await resp.json()

    if (!Array.isArray(tasks) || tasks.length === 0) {
      return "No scheduled tasks found."
    }

    const lines = tasks.map((t: any) => {
      const status = t.enabled ? "ACTIVE" : "DISABLED"
      const lastRun = t.last_executed ? `Last run: ${t.last_executed} (${t.last_status || "unknown"})` : "Never run"
      return `- [${status}] ${t.name} (${t.cron_expression}) — ID: ${t.id}\n  Prompt: ${t.prompt}\n  ${lastRun}`
    })

    return `Scheduled tasks:\n\n${lines.join("\n\n")}`
  },
})
