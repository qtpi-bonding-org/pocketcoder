#!/bin/sh
# opencode_entrypoint.sh
# Hardens the shell environment at runtime before launching OpenCode.

set -e

echo "🛡️  [PocketCoder] Initializing Hardened Environment..."

# 1. THE SWITCHEROO (Hard Shell Enforcement)
# We do this at runtime to ensure the system is ready before we lock it down.
# We move the real shell aside and link the proxy.
if [ ! -f /bin/sh.original ]; then
    echo "🔒 Hardening Shell: Redirecting /bin/sh -> /proxy/pocketcoder-shell..."
    mv /bin/sh /bin/sh.original
    ln -s /proxy/pocketcoder-shell /bin/sh
else
    echo "🔒 Shell already hardened."
fi

# 2. Verify Proxy Connection
echo "⏳ Waiting for Proxy Server..."
count=0
while ! curl -s http://proxy:3001/health > /dev/null; do
    sleep 1
    count=$((count+1))
    if [ $count -gt 30 ]; then
        echo "❌ Proxy not reachable. Aborting."
        exit 1
    fi
done
echo "✅ Proxy is UP."

# 3. Launch OpenCode
echo "🚀 Launching OpenCode Reasoning Engine..."
# Pass all arguments to the main executable
exec opencode "$@"
