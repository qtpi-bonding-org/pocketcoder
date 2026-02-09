import { createOpencodeClient } from "@opencode-ai/sdk"

const client = createOpencodeClient({
    baseUrl: "http://localhost:4096",
})

async function run() {
    console.log("🚀 Starting Autonomous Command...");

    const session = await client.session.create({
        body: { title: "Gatekeeper Test" }
    });

    if (!session.data) throw new Error("Failed to create session");
    const sessionID = session.data.id;

    console.log(`📂 Session: ${sessionID}`);

    // Send the prompt - this will trigger a tool call and thus a permission
    await client.session.prompt({
        path: { id: sessionID },
        body: {
            model: { providerID: "google", modelID: "gemini-2.0-flash" },
            parts: [{ type: "text", text: "Create a file named 'INTERCEPT_ME.txt' with the text 'Proof of sovereignty'." }]
        }
    });

    console.log("✅ Command sequence finished.");
}

run().catch(console.error);
