#!/bin/sh
# opencode_entrypoint.sh
# Standard entrypoint for the OpenCode container.

set -e

echo "🛡️  [PocketCoder] Initializing Environment..."

# 0. SSH Setup - Install authorized key and start sshd
echo "🔐 Setting up SSH access..."

# Create .ssh directory for poco user
mkdir -p /home/poco/.ssh
chmod 700 /home/poco/.ssh

# Copy authorized public key from mounted volume
if [ -f /ssh_keys/id_rsa.pub ]; then
    cp /ssh_keys/id_rsa.pub /home/poco/.ssh/authorized_keys
    chmod 600 /home/poco/.ssh/authorized_keys
    echo "✅ SSH authorized key installed"
else
    echo "⚠️  SSH key not found at /ssh_keys/id_rsa.pub"
fi

# Set correct ownership
chown -R poco:poco /home/poco/.ssh

# Start sshd daemon on port 2222
echo "🚀 Starting sshd on port 2222..."
/usr/sbin/sshd -D -e 2>/tmp/sshd.log &
echo "✅ sshd started"

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
# In Alpine, /bin/sh is a symlink to Busybox.
# We redirect /bin/sh to our proxy, while keeping /bin/ash as the "escape hatch" for system scripts.
if [ -L /bin/sh ] && [ "$(readlink /bin/sh)" != "/proxy/pocketcoder-shell" ]; then
    echo "🔒 Hardening Shell: /bin/sh -> /proxy/pocketcoder-shell..."
    # We don't rename the binary (busybox), we just change the generic 'sh' entry point.
    ln -sf /proxy/pocketcoder-shell /bin/sh
    echo "✅ Shell is now HARDENED."
else
    echo "🔒 Shell already hardened or custom state detected."
fi

# 4. Background Log Tailing (for visibility)
(
    while [ ! -d /root/.local/share/opencode/log ]; do sleep 2; done
    # Wait for the first log file to appear
    while [ -z "$(ls /root/.local/share/opencode/log/*.log 2>/dev/null)" ]; do sleep 1; done
    echo "📊 [Relay] Log stream active."
    tail -f /root/.local/share/opencode/log/*.log
) &

# 5. Launch OpenCode
echo "🚀 Launching OpenCode Reasoning Engine..."
exec opencode "$@"
