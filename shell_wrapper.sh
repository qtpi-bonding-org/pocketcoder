#!/bin/bash
# POCKETCODER FIREWALL BRIDGE
# This script replaces /bin/bash in the OpenCode container.
# It intercepts execution and forwards it to the Rust Gateway.

# 1. Fallback for interactive mode or non-command usage
if [ "$1" != "-c" ]; then
    # We might want to block interactive shells entirely or forward them?
    # For now, let's allow basic shell for debugging if needed, 
    # OR strictly block. "Execution Firewall" implies strictness.
    # But OpenCode might call it for other things. 
    # Let's fallback to /bin/bash for safety but log it?
    # Actually, for v1, let's assume OpenCode ALWAYS uses -c.
    exec /bin/bash "$@"
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
        
        // POST to Gateway
        const res = await fetch("http://gateway:3001/exec", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ cmd, cwd })
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
