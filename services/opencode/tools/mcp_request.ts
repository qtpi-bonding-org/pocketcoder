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
  description: "Request a new MCP server to be enabled. Automatically researches the technical requirements (image, secrets) from the Docker MCP catalog before submitting.",
  args: {
    server_name: tool.schema.string().describe("Name of the MCP server (e.g., 'n8n', 'mysql')"),
    reason: tool.schema.string().describe("Why this server is needed for the current task"),
  },
  async execute(args, context) {
    const pbUrl = process.env.POCKETBASE_URL || "http://pocketbase:8090"
    const token = await getAgentToken()

    let image = ""
    let configSchema: Record<string, string> = {}

    // 1. Auto-Research: Query the official catalog for technical metadata
    try {
      const process = Bun.spawn(["sh", "-c", "docker mcp catalog show docker-mcp --format json"])
      const stdout = await new Response(process.stdout).text()
      const catalog = JSON.parse(stdout)

      // The Docker MCP catalog JSON structure has servers under the 'registry' key
      const serverEntry = catalog.registry ? catalog.registry[args.server_name] : catalog[args.server_name]
      if (serverEntry) {
        image = serverEntry.image || ""

        // Extract required secrets
        if (Array.isArray(serverEntry.secrets)) {
          serverEntry.secrets.forEach((s: any) => {
            if (s.env) configSchema[s.env] = `Secret: ${s.name || s.env}`
          })
        }

        // Extract environment variables, especially those needing user configuration (placeholders)
        if (Array.isArray(serverEntry.env)) {
          serverEntry.env.forEach((e: any) => {
            if (e.name) {
              // If it's a template placeholder like {{n8n.api_url}}, we definitely need it from the user
              const description = e.value && e.value.includes("{{")
                ? `Configuration required: ${e.value}`
                : `Environment variable: ${e.name}`

              configSchema[e.name] = description
            }
          })
        }
      } else {
        console.warn(`⚠️ [mcp_request] Server '${args.server_name}' not found in catalog.`)
      }
    } catch (e) {
      console.warn(`⚠️ [mcp_request] Auto-research via catalog failed for ${args.server_name}:`, e)
      // Fallback: we'll still proceed with just the name
    }

    // 2. Submit the enriched request to PocketBase
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
        image: image,
        config_schema: configSchema,
      }),
    })

    if (!resp.ok) {
      const err = await resp.text()
      return `Request failed: ${err}`
    }

    const data = await resp.json()
    let result = `MCP server '${args.server_name}' request submitted (ID: ${data.id}, status: ${data.status}).`
    if (image) {
      const shortImage = image.length > 50 ? `${image.substring(0, 47)}...` : image
      result += ` Detected image: ${shortImage}.`
    }
    if (Object.keys(configSchema).length > 0) {
      result += ` Identified required configuration: ${Object.keys(configSchema).join(", ")}.`
    }
    return result + " Waiting for user approval and configuration entry in the PocketCoder dashboard."
  },
})