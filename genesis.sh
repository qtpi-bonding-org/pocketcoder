#!/bin/bash
# PocketCoder: An accessible, secure, and user-friendly open-source coding assistant platform.
# Copyright (C) 2026 Qtpi Bonding LLC
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.


# @pocketcoder-core: Genesis. The idempotent setup script for first-time bunker boarding.
set -e

# 🏰 PocketCoder Setup Script (Strictly Idempotent)
# This script prepares the environment, sets up one-time credentials, 
# and ensures everything is ready for Docker.

echo "🏰 Starting PocketCoder Setup..."

# 1. LOAD OR GENERATE SECRETS
DOTENV=.env
if [ -f "$DOTENV" ]; then
    echo "ℹ️  Found existing .env file. Preserving current secrets..."
    
    # Extract values directly to avoid bash parsing issues with special characters
    AGENT_PASSWORD=$(grep "^AGENT_PASSWORD=" "$DOTENV" | cut -d'=' -f2-)
    ADMIN_PASSWORD=$(grep "^POCKETBASE_ADMIN_PASSWORD=" "$DOTENV" | cut -d'=' -f2-)
    SUPERUSER_PASSWORD=$(grep "^POCKETBASE_SUPERUSER_PASSWORD=" "$DOTENV" | cut -d'=' -f2-)
    GEMINI_API_KEY=$(grep "^GEMINI_API_KEY=" "$DOTENV" | cut -d'=' -f2-)
else
    echo "🔑 Generating first-time secure credentials..."
fi

# Set defaults ONLY if they weren't found in the existing .env
: "${AGENT_PASSWORD:=$(openssl rand -base64 24 | tr -d '\n')}"
: "${ADMIN_PASSWORD:=$(openssl rand -base64 24 | tr -d '\n')}"
: "${SUPERUSER_PASSWORD:=$(openssl rand -base64 24 | tr -d '\n')}"
: "${GEMINI_API_KEY:=""}"

# 2. ENSURE SSH KEYS
echo "🔑 Ensuring internal SSH keys for Proxy-to-Sandbox communication..."
mkdir -p .ssh_keys
if [ ! -f .ssh_keys/id_rsa ]; then
    ssh-keygen -t rsa -b 4096 -f .ssh_keys/id_rsa -N "" -q
    cat .ssh_keys/id_rsa.pub > .ssh_keys/authorized_keys
    chmod 600 .ssh_keys/id_rsa
    chmod 644 .ssh_keys/authorized_keys
    echo "✅ SSH keys generated in .ssh_keys/"
else
    echo "ℹ️  SSH keys already exist. Preserving them."
fi

# 3. CONSTRUCT .ENV FILE
# We rewrite the file to ensure the structure is clean and all variables are present
cat > "$DOTENV" <<EOF
COMPOSE_PROJECT_NAME=pocketcoder
# Container Ports
PORT=3000
POCKETBASE_URL=http://pocketbase:8090
OPENCODE_URL=http://opencode:3000

# ------------------------------------------------------------------
# 🛡️ SECURE CREDENTIALS (Idempotent)
# ------------------------------------------------------------------

# 🌌 POCKETBASE DASHBOARD (Super Administrator)
POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.app
POCKETBASE_SUPERUSER_PASSWORD=${SUPERUSER_PASSWORD}

# 👤 APP IDENTITY (The Human / Authorizer)
POCKETBASE_ADMIN_EMAIL=admin@pocketcoder.local
POCKETBASE_ADMIN_PASSWORD=${ADMIN_PASSWORD}

# 🤖 AGENT IDENTITY (The Bot)
AGENT_EMAIL=agent@pocketcoder.local
AGENT_PASSWORD=${AGENT_PASSWORD}

# 🧠 AI REASONING
GEMINI_API_KEY=${GEMINI_API_KEY}
EOF

echo "✅ Environment configured in .env"

# 4. START ALL SERVICES
echo "🚀 Booting up the PocketCoder ecosystem..."
docker compose up -d

# 5. WAIT FOR HEALTHCHECK
echo "⏳ Waiting for PocketBase to be ready..."
until curl -s -f http://localhost:8090/api/health > /dev/null; do
    sleep 2
    echo -n "."
done
echo " Ready!"

echo "
🎉 PocketCoder Setup Successful.

🤖 Agent Identity:
   Email: agent@pocketcoder.local
   Pass:  ${AGENT_PASSWORD}

👤 Admin User:
   Email: admin@pocketcoder.local
   Pass:  ${ADMIN_PASSWORD}

🔑 Superuser Password (Dashboard):
   Email: superuser@pocketcoder.app
   Pass:  ${SUPERUSER_PASSWORD}

🛑 These credentials are saved in your .env file and initialized in the database.
"
