#!/bin/sh
# POCKETCODER FIREWALL BRIDGE
# This script replaces /bin/bash in the OpenCode container.
# It intercepts execution and forwards it to the Rust Gateway.

# 1. Restricted Mode: Block interactive or non-conforming calls
if [ "$1" != "-c" ]; then
    echo "\x1b[31m🔥 [Firewall Blocked]: Interactive or raw shell invocation is restricted for security. Always execute commands via 'bash -c \"command\"'.\x1b[0m" >&2
    exit 1
fi

export CMD="$2"
export CWD=$(pwd)

# 2. The Bridge (Node.js Fetch)
# We use 'node' because it's guaranteed to be in the OpenCode container (node:20+).
# curl relies on system deps that might differ.
# We map 'gateway' host in docker-compose.

node -e '
(async () => {
    try {
        const cmd = process.env.CMD;
        const cwd = process.env.CWD;
        const usageId = process.env.POCKETCODER_USAGE_ID;
        
        // POST to Gateway
        const res = await fetch("http://gateway:3001/exec", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ cmd, cwd, usage_id: usageId })
        });
        
        // Parse Response
        // Expected: { stdout: string, exit_code: number } OR { error: string }
        const json = await res.json();
        
        if (json.error) {
             console.error("\x1b[31m🔥 [Firewall Blocked]: " + json.error + "\x1b[0m");
             process.exit(1); 
        }
        
        // Write Stdout (without extra newline)
        process.stdout.write(json.stdout || "");
        
        // Exit with the remote exit code
        process.exit(json.exit_code || 0);

    } catch (e) {
        console.error("\x1b[31m🔥 [Bridge Error]: Connection to Gateway Failed.\n" + e.message + "\x1b[0m");
        process.exit(1);
    }
})()
'
