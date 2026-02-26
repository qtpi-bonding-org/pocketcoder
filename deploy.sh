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
INCLUDE_TESTS=false
COMPOSE_FILES=("-f" "docker-compose.yml")

# Parse arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --docs) INCLUDE_DOCS=true ;;
        --tests|--test) INCLUDE_TESTS=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${BLUE}🦅 PocketCoder: Initializing Bunker Deployment...${NC}"

# 1. SECURE INITIALIZATION (Formerly Genesis)
# ------------------------------------------

# .env generation with random secrets
DOTENV=.env
if [ ! -f "$DOTENV" ]; then
    echo -e "${YELLOW}� Generating first-time secure credentials from template...${NC}"
    if [ ! -f .env.template ]; then
        echo -e "${RED}❌ Error: .env.template not found.${NC}"
        exit 1
    fi

    # Generate random passwords for first boot
    AGENT_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
    ADMIN_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')
    SUPERUSER_PASSWORD=$(openssl rand -base64 24 | tr -d '\n')

    # Construct .env from template but inject the random passwords
    # We use sed to replace placeholders if they exist, or just append/prep
    sed -e "s/AGENT_PASSWORD=.*/AGENT_PASSWORD=${AGENT_PASSWORD}/" \
        -e "s/POCKETBASE_ADMIN_PASSWORD=.*/POCKETBASE_ADMIN_PASSWORD=${ADMIN_PASSWORD}/" \
        -e "s/POCKETBASE_SUPERUSER_PASSWORD=.*/POCKETBASE_SUPERUSER_PASSWORD=${SUPERUSER_PASSWORD}/" \
        .env.template > "$DOTENV"
    
    echo -e "${GREEN}✅ Secure .env initialized.${NC}"
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
MCP_CONFIG_DIR="services/mcp-gateway/config"
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

if [ "$INCLUDE_TESTS" = true ]; then
    echo -e "${YELLOW}🧪 Including Test runner service...${NC}"
    COMPOSE_FILES+=("-f" "docker-compose.test.yml")
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
if [ "$INCLUDE_DOCS" = true ]; then
    echo -e "📚 ${BLUE}Docs:${NC}          http://localhost:4321"
fi
echo -e "🧠 ${BLUE}OpenCode Logs:${NC} docker logs -f pocketcoder-opencode"
echo -e "------------------------------------------------"
