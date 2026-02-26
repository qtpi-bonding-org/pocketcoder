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
      const process = Bun.spawn(["docker", "mcp", "catalog", "show", "docker-mcp", "--format", "json"])
      const stdout = (await new Response(process.stdout).text()).trim()

      if (stdout.trim()) {
        const catalog = JSON.parse(stdout)
        const registry = catalog.registry || catalog
        const requestedName = args.server_name.toLowerCase()

        // Case-insensitive matching
        const entryKey = Object.keys(registry).find(key => key.toLowerCase() === requestedName)
        const serverEntry = entryKey ? registry[entryKey] : null

        if (serverEntry) {
          image = serverEntry.image || ""

          // Extract required secrets
          if (Array.isArray(serverEntry.secrets)) {
            serverEntry.secrets.forEach((s: any) => {
              if (s.env) configSchema[s.env] = `Secret: ${s.name || s.env}`
            })
          }

          // Extract environment variables, identifying placeholders
          if (Array.isArray(serverEntry.env)) {
            serverEntry.env.forEach((e: any) => {
              if (e.name) {
                const description = e.value && e.value.includes("{{")
                  ? `User configuration required: ${e.value}`
                  : `Environment variable: ${e.name}`

                configSchema[e.name] = description
              }
            })
          }

          // Support for V3 'config' parameter schema
          if (Array.isArray(serverEntry.config)) {
            serverEntry.config.forEach((c: any) => {
              if (c.properties && typeof c.properties === 'object') {
                Object.entries(c.properties).forEach(([prop, details]: [string, any]) => {
                  configSchema[prop] = details.description || `Configuration: ${prop}`
                })
              }
            })
          }
        } else {
          console.warn(`⚠️ [mcp_request] Server '${args.server_name}' not found in catalog.`)
        }
      }
    } catch (e) {
      console.warn(`⚠️ [mcp_request] Auto-research via catalog failed for ${args.server_name}:`, e)
      // Fallback: proceed with just the basic name provided by user
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
    const action = data.synced ? "synced with existing record" : "submitted"
    let result = `MCP server '${args.server_name}' request ${action} (ID: ${data.id}, status: ${data.status}).`
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