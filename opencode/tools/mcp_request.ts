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
  description: "Request a new MCP server to be enabled. This sends the request to PocketBase for user approval. The server will be available to subagents after approval.",
  args: {
    server_name: tool.schema.string().describe("Name of the MCP server from the catalog (e.g., 'postgres', 'duckduckgo')"),
    reason: tool.schema.string().describe("Why this server is needed for the current task"),
  },
  async execute(args, context) {
    const pbUrl = process.env.POCKETBASE_URL || "http://pocketbase:8090"
    const token = await getAgentToken()

    const resp = await fetch(`${pbUrl}/api/pocketcoder/mcp_request`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${token}`,
      },
      body: JSON.stringify({
        server_name: args.server_name,
        reason: args.reason,
        session_id: context.sessionID,
      }),
    })

    if (!resp.ok) {
      const err = await resp.text()
      return `Request failed: ${err}`
    }

    const data = await resp.json()
    return `MCP server '${args.server_name}' request submitted (ID: ${data.id}, status: ${data.status}). Waiting for user approval.`
  },
})