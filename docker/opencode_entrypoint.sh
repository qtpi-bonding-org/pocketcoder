#!/bin/sh
# opencode_entrypoint.sh
# Standard entrypoint for the OpenCode container.

set -e

echo "🛡️  [PocketCoder] Initializing Environment..."

# 1. Wait for the proxy binary to be available (mounted via volume)
echo "⏳ Waiting for PocketCoder Shell binary..."
while [ ! -f /proxy/pocketcoder-shell ]; do
    sleep 1
done

# 2. Verify Proxy Server Connection
echo "⏳ Waiting for Proxy Server..."
count=0
while ! curl -s http://proxy:3001/health > /dev/null; do
    sleep 1
    count=$((count+1))
    if [ $count -gt 30 ]; then
        echo "❌ Proxy not reachable on http://proxy:3001. Aborting."
        exit 1
    fi
done
echo "✅ Proxy is UP."

# 3. THE SWITCHEROO (Hard Shell Enforcement)
# We do this LAST so the script can finish its own logic using the real shell.
if [ ! -f /bin/sh.original ]; then
    echo "🔒 Hardening Shell: Redirecting /bin/sh -> /proxy/pocketcoder-shell..."
    mv /bin/sh /bin/sh.original
    ln -s /proxy/pocketcoder-shell /bin/sh
    echo "✅ Shell is now HARDENED."
else
    echo "🔒 Shell already hardened."
fi

# 4. Launch OpenCode
echo "🚀 Launching OpenCode Reasoning Engine..."
exec opencode "$@"
