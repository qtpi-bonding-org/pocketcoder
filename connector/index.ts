import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";
import express from 'express';

const server = new Server({ name: "pocketcoder-connector", version: "1.0.0" }, { capabilities: { tools: {} } });
server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: [] }));
server.setRequestHandler(CallToolRequestSchema, async () => { throw new Error("No tools."); });

const app = express();
let transport: SSEServerTransport;

app.get("/sse", async (req, res) => {
    transport = new SSEServerTransport("/messages", res);
    await server.connect(transport);
});

app.post("/messages", express.json(), async (req, res) => {
    if (transport) await transport.handlePostMessage(req, res);
});

app.listen(process.env.PORT || 3001, () => {
    console.log(`🚀 Connector listening on ${process.env.PORT || 3001}`);
});
