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

// @pocketcoder-core: Schedule Task Tool. Creates a cron job record so Poco can schedule recurring tasks.
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
  description: "Schedule a recurring task. Creates a cron job that will execute a prompt on a schedule. The user will be asked to approve this action.",
  args: {
    task_name: tool.schema.string().describe("A short name for the scheduled task (e.g., 'Nightly Tests', 'PR Review Reminder')"),
    cron_expression: tool.schema.string().describe("Standard cron expression for the schedule (e.g., '0 9 * * 1' for every Monday at 9am)"),
    prompt: tool.schema.string().describe("The prompt/instruction to execute on each run"),
    session_mode: tool.schema.string().optional().describe("'new' to create a fresh chat each run (default), or 'existing' to reuse the current chat"),
    description: tool.schema.string().optional().describe("Optional longer description of what this task does"),
  },
  async execute(args, context) {
    const pbUrl = process.env.POCKETBASE_URL || "http://pocketbase:8090"
    const token = await getAgentToken()

    const resp = await fetch(`${pbUrl}/api/pocketcoder/schedule_task`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`,
      },
      body: JSON.stringify({
        name: args.task_name,
        cron_expression: args.cron_expression,
        prompt: args.prompt,
        session_mode: args.session_mode || "new",
        description: args.description || "",
        session_id: context.sessionID,
      }),
    })

    if (!resp.ok) {
      const err = await resp.text()
      return `Failed to schedule task: ${err}`
    }

    const data = await resp.json()
    return `Scheduled '${data.name}' (${data.cron_expression}). ID: ${data.id}. The task is now active and will run on schedule.`
  },
})
