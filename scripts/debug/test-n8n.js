const http = require('http');

const SSE_URL = 'http://mcp-gateway:8811/sse';

console.log(`Connecting to ${SSE_URL}...`);

let postUrl = null;
const pendingRequests = new Map();

const sseReq = http.request(SSE_URL, {
    method: 'GET',
    headers: { 'Accept': 'text/event-stream' }
}, (res) => {
    console.log(`SSE Status: ${res.statusCode}`);

    let buffer = '';

    res.on('data', (chunk) => {
        buffer += chunk.toString();
        let lines = buffer.split('\n');
        buffer = lines.pop(); // Keep incomplete line in buffer

        let currentEvent = null;

        for (const line of lines) {
            if (line.startsWith('event: ')) {
                currentEvent = line.substring(7).trim();
            } else if (line.startsWith('data: ')) {
                const dataStr = line.substring(6).trim();

                if (currentEvent === 'endpoint') {
                    if (!postUrl) {
                        postUrl = `http://mcp-gateway:8811${dataStr}`;
                        console.log(`Session established! POST URL: ${postUrl}`);
                        runTest();
                    }
                } else if (currentEvent === 'message') {
                    try {
                        const message = JSON.parse(dataStr);
                        if (message.id && pendingRequests.has(message.id)) {
                            const { resolve, reject } = pendingRequests.get(message.id);
                            pendingRequests.delete(message.id);
                            if (message.error) reject(message.error);
                            else resolve(message.result);
                        } else if (message.method) {
                            // Server-to-client request or notification
                            console.log("Received server notification/request:", message.method);
                        }
                    } catch (e) {
                        console.error("Failed to parse message:", e, "Raw:", dataStr);
                    }
                }
                currentEvent = null; // reset for next event
            }
        }
    });
});

sseReq.on('error', (e) => {
    console.error(`SSE Connection error: ${e.message}`);
});

sseReq.end();

function makeRpcCall(method, params, id) {
    return new Promise((resolve, reject) => {
        if (id !== null) {
            pendingRequests.set(id, { resolve, reject });
        }

        const payload = JSON.stringify({
            jsonrpc: "2.0",
            id: id,
            method: method,
            params: params
        });

        const req = http.request(postUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload)
            }
        }, (res) => {
            if (res.statusCode >= 400 && id !== null) {
                pendingRequests.delete(id);
                reject(new Error(`POST failed with status ${res.statusCode}`));
            }
        });

        req.on('error', (e) => {
            if (id !== null) {
                pendingRequests.delete(id);
                reject(e);
            }
        });
        req.write(payload);
        req.end();

        if (id === null) resolve(); // Notifications don't wait for responses
    });
}

async function runTest() {
    try {
        console.log('\n--- 1. Initialize ---');
        const initRes = await makeRpcCall("initialize", {
            protocolVersion: "2024-11-05",
            capabilities: {},
            clientInfo: { name: "debug-script", version: "1.0.0" }
        }, 1);
        console.log("Initialized.");

        await makeRpcCall("notifications/initialized", {}, null);

        console.log('\n--- 1.5 Set config ---');
        const configRes = await makeRpcCall("tools/call", {
            name: "mcp-config-set",
            arguments: {
                server: "n8n",
                config: {
                    MCP_MODE: "stdio",
                    N8N_MCP_TELEMETRY_DISABLED: "1",
                    api_url: "http://n8n:5678",
                    N8N_API_KEY: "dummy"
                }
            }
        }, 2);
        console.log("mcp-config-set result:", configRes);

        console.log('\n--- 2. Add n8n to session ---');
        const addRes = await makeRpcCall("tools/call", {
            name: "mcp-add",
            arguments: { name: "n8n" }
        }, 3);
        console.log("mcp-add result:", addRes);

        console.log('\nWaiting 2 seconds for n8n to connect inside gateway...');
        await new Promise(r => setTimeout(r, 2000));

        console.log('\n--- 2.5 List dynamic tools ---');
        const toolsRes = await makeRpcCall("tools/list", {}, 4);
        console.log("Found tools:", toolsRes.tools.map(t => t.name).join(", "));
        const n8nCreate = toolsRes.tools.find(t => t.name === "n8n_create_workflow");
        if (n8nCreate) console.log("n8n_create_workflow schema:", JSON.stringify(n8nCreate, null, 2));

        console.log('\n--- 3. Create a simple workflow via n8n_create_workflow (direct) ---');
        const execRes = await makeRpcCall("tools/call", {
            name: "n8n_create_workflow",
            arguments: {
                name: `Test Workflow generated by script ${Date.now()}`,
                nodes: [
                    {
                        id: "1",
                        name: "Start",
                        type: "n8n-nodes-base.noOp",
                        typeVersion: 1,
                        position: [250, 250],
                        parameters: {}
                    },
                    {
                        id: "2",
                        name: "Process Data",
                        type: "n8n-nodes-base.set",
                        typeVersion: 3.4,
                        position: [450, 300],
                        parameters: {}
                    }
                ],
                connections: {
                    "Start": {
                        "main": [
                            [
                                {
                                    "node": "Process Data",
                                    "type": "main",
                                    "index": 0
                                }
                            ]
                        ]
                    }
                },
                active: false
            }
        }, 5);
        console.log("mcp-exec result:", JSON.stringify(execRes, null, 2));

        process.exit(0);
    } catch (err) {
        console.error("Test failed:", err);
        process.exit(1);
    }
}
