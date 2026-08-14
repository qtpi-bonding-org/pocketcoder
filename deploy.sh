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

# @pocketcoder-core: Deployment Script. Orchestrates the full bunker setup.

set -e

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Initialize flags
INCLUDE_DOCS=false
HARDEN_HOST=true
COMPOSE_FILES=("-f" "docker-compose.yml")

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --docs) INCLUDE_DOCS=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${BLUE}🦅 PocketCoder: Initializing Bunker Deployment...${NC}"

if [ "$HARDEN_HOST" = true ] && [ "$(uname -s)" = "Linux" ]; then
    echo -e "${BLUE}🛡️  Applying standard Linux host hardening...${NC}"
    sudo ./deploy/standard-linux/harden-host.sh --apply
fi

# 1. SECURE INITIALIZATION (Formerly Genesis)
# ------------------------------------------

# .env generation with random secrets
DOTENV=.env
if [ ! -f "$DOTENV" ] || ! grep -q "AGENT_PASSWORD" "$DOTENV"; then
    echo -e "${YELLOW}� Generating first-time secure credentials from template...${NC}"
    if [ ! -f .env.template ]; then
        echo -e "${RED}❌ Error: .env.template not found.${NC}"
        exit 1
    fi

    # Extract existing API keys if .env exists
    EXISTING_API_KEYS=""
    if [ -f "$DOTENV" ]; then
        EXISTING_API_KEYS=$(grep "API" "$DOTENV" || true)
    fi

    # Generate random passwords for first boot
    AGENT_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
    ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
    SUPERUSER_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')

    # Construct .env from template but inject the random passwords
    # We use sed to replace placeholders if they exist, or just append/prep
    sed -e "s|AGENT_PASSWORD=.*|AGENT_PASSWORD=${AGENT_PASSWORD}|" \
        -e "s|POCKETBASE_ADMIN_PASSWORD=.*|POCKETBASE_ADMIN_PASSWORD=${ADMIN_PASSWORD}|" \
        -e "s|POCKETBASE_SUPERUSER_PASSWORD=.*|POCKETBASE_SUPERUSER_PASSWORD=${SUPERUSER_PASSWORD}|" \
        .env.template > "$DOTENV"
    
    # Re-inject preserved API keys
    if [ -n "$EXISTING_API_KEYS" ]; then
        echo "$EXISTING_API_KEYS" | while IFS= read -r line; do
            key=$(echo "$line" | cut -d '=' -f 1)
            # If the key exists in .env, replace it. Otherwise append it.
            if grep -q "^${key}=" "$DOTENV"; then
                sed "s|^${key}=.*|${line}|" "$DOTENV" > "${DOTENV}.tmp" && mv "${DOTENV}.tmp" "$DOTENV"
            else
                echo "$line" >> "$DOTENV"
            fi
        done
        echo -e "${GREEN}✅ Preserved API keys re-injected.${NC}"
    fi

    echo -e "${GREEN}✅ Secure .env initialized.${NC}"
fi

# Standard Linux uses native host Caddy, matching the NixOS image. It detects
# the VPS public IP and obtains the sslip.io certificate without publishing
# PocketBase directly. Local macOS/Docker development keeps the optional Caddy
# Compose profile instead.
if [ "$(uname -s)" = "Linux" ]; then
    echo -e "${BLUE}🔒 Configuring native Caddy HTTPS...${NC}"
    sudo ./deploy/standard-linux/setup-caddy.sh
fi

# Ensure internal SSH keys for Proxy-to-Sandbox communication
if [ ! -f .ssh_keys/id_rsa ]; then
    echo -e "${BLUE}🔑 Ensuring internal SSH keys...${NC}"
    mkdir -p .ssh_keys
    ssh-keygen -t rsa -b 4096 -f .ssh_keys/id_rsa -N "" -q
    cat .ssh_keys/id_rsa.pub > .ssh_keys/authorized_keys
    chmod 600 .ssh_keys/id_rsa
    chmod 644 .ssh_keys/authorized_keys
    echo -e "${GREEN}✅ SSH keys generated in .ssh_keys/${NC}"
fi

# MCP configuration initialization
MCP_CONFIG_DIR="server/mcp-gateway/config"
if [ ! -f "$MCP_CONFIG_DIR/docker-mcp.yaml" ]; then
    echo -e "${BLUE}🔌 Initializing docker-mcp.yaml from template...${NC}"
    cp "$MCP_CONFIG_DIR/docker-mcp.yaml.template" "$MCP_CONFIG_DIR/docker-mcp.yaml"
fi

if [ ! -f "$MCP_CONFIG_DIR/mcp.env" ]; then
    echo -e "${BLUE}🔌 Initializing mcp.env from template...${NC}"
    cp "$MCP_CONFIG_DIR/mcp.env.template" "$MCP_CONFIG_DIR/mcp.env"
fi

# 2. CONSTRUCT COMPOSE COMMAND
# ---------------------------
if [ "$INCLUDE_DOCS" = true ]; then
    echo -e "${YELLOW}📚 Including Documentation service...${NC}"
    COMPOSE_FILES+=("-f" "docker-compose.docs.yml")
fi

# 3. BUILD & BOOT
# ---------------
echo -e "${BLUE}🏗️  Building images...${NC}"
docker compose "${COMPOSE_FILES[@]}" build

echo -e "${BLUE}🚀 Starting PocketCoder ecosystem...${NC}"
docker compose "${COMPOSE_FILES[@]}" up -d

# 4. STATUS OVERVIEW
# -----------------
echo -e "\n${GREEN}✅ PocketCoder is LIVE.${NC}"
echo -e "------------------------------------------------"
echo -e "🏰 ${BLUE}PocketBase UI:${NC} http://localhost:8090/_/"
if [ "$(uname -s)" = "Linux" ] && [ -f /etc/pocketcoder/domain.env ]; then
    # shellcheck disable=SC1091
    source /etc/pocketcoder/domain.env
    echo -e "🌐 ${BLUE}PocketCoder HTTPS:${NC} ${PB_URL}"
fi
if [ "$INCLUDE_DOCS" = true ]; then
    echo -e "📚 ${BLUE}Docs:${NC}          http://localhost:4321"
fi
echo -e "🏰 ${BLUE}PocketBase Logs:${NC} docker logs -f pocketcoder-pocketbase"
echo -e "------------------------------------------------"
