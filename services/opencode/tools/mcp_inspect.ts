import { tool } from "@opencode-ai/plugin"

export default tool({
    description: "Inspect an MCP server's technical details, including its tools, environment variables, and README documentation from the catalog.",
    args: {
        server_name: tool.schema.string().describe("The name of the MCP server to inspect (e.g., 'n8n', 'mysql')"),
        mode: tool.schema.enum(["all", "tools", "readme", "config"]).default("all").describe("Filter what information to return"),
    },
    async execute(args) {
        try {
            // Use catalog show which doesn't require docker.sock
            const process = Bun.spawn(["docker", "mcp", "catalog", "show", "docker-mcp", "--format", "json"])
            const stdout = (await new Response(process.stdout).text()).trim()

            if (!stdout) {
                return `Failed to retrieve catalog information.`
            }

            const catalog = JSON.parse(stdout)
            const registry = catalog.registry || catalog
            const requestedName = args.server_name.toLowerCase()

            // Case-insensitive matching
            const entryKey = Object.keys(registry).find(key => key.toLowerCase() === requestedName)
            if (!entryKey) {
                return `MCP server '${args.server_name}' not found in catalog.`
            }

            const data = registry[entryKey]
            let output = `### MCP Server: ${entryKey}\n\n`

            if (args.mode === "all" || args.mode === "readme") {
                if (data.readme) {
                    output += `#### README\n${data.readme}\n\n`
                }
            }

            if (args.mode === "all" || args.mode === "tools") {
                if (Array.isArray(data.tools)) {
                    output += `#### Tools (${data.tools.length})\n`
                    data.tools.forEach((t: any) => {
                        output += `- **${t.name}**: ${t.description || "No description"}\n`
                        if (t.arguments && Array.isArray(t.arguments)) {
                            t.arguments.forEach((arg: any) => {
                                output += `  - *${arg.name}* (${arg.type}): ${arg.desc || "No description"}\n`
                            })
                        }
                    })
                    output += "\n"
                }
            }

            if (args.mode === "all" || args.mode === "config") {
                const configSchema: Record<string, string> = {}

                // Extract required secrets (legacy/v2)
                if (Array.isArray(data.secrets)) {
                    data.secrets.forEach((s: any) => {
                        if (s.env) configSchema[s.env] = `Secret: ${s.name || s.env}`
                    })
                }

                // Extract environment variables (identifying placeholders)
                if (Array.isArray(data.env)) {
                    data.env.forEach((e: any) => {
                        if (e.name) {
                            const description = e.value && e.value.includes("{{")
                                ? `User configuration required: ${e.value}`
                                : `Environment variable: ${e.name}`
                            configSchema[e.name] = description
                        }
                    })
                }

                // Support for V3 'config' parameter schema
                if (Array.isArray(data.config)) {
                    data.config.forEach((c: any) => {
                        if (c.properties && typeof c.properties === 'object') {
                            Object.entries(c.properties).forEach(([prop, details]: [string, any]) => {
                                configSchema[prop] = details.description || `Configuration: ${prop}`
                            })
                        }
                    })
                }

                if (Object.keys(configSchema).length > 0) {
                    output += "#### Configuration Requirements\n"
                    Object.entries(configSchema).forEach(([key, desc]) => {
                        output += `- **${key}**: ${desc}\n`
                    })
                    output += "\n"
                } else if (data.config) {
                    output += `#### Configuration\n`
                    output += `\`\`\`json\n${JSON.stringify(data.config, null, 2)}\n\`\`\`\n\n`
                }
            }

            return output
        } catch (e) {
            console.error(`Error inspecting MCP server '${args.server_name}':`, e)
            return `Failed to inspect MCP server '${args.server_name}': ${e}`
        }
    },
})
