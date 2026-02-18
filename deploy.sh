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
#!/bin/bash
# deploy.sh - Convenience script to boot the PocketCoder bunker.

set -e

# Colors for better readability
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🦅 PocketCoder: Initializing Bunker...${NC}"

# 1. Environment Check
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo -e "${YELLOW}⚠️  .env not found. Creating from .env.example...${NC}"
        cp .env.example .env
        echo -e "${YELLOW}🛑 Please update your .env with valid credentials (e.g., GEMINI_API_KEY) and run ./deploy.sh again.${NC}"
        exit 1
    else
        echo -e "${RED}❌ Error: .env or .env.example not found.${NC}"
        exit 1
    fi
fi

# 2. Boot Services
echo -e "${BLUE}🚀 Starting Docker services...${NC}"
docker compose up -d --build

# 3. Wait for Healthy Status
echo -e "${BLUE}⏳ Waiting for services to stabilize...${NC}"
sleep 5

# 4. Status Overview
echo -e "\n${GREEN}✅ PocketCoder is LIVE.${NC}"
echo -e "------------------------------------------------"
echo -e "🏰 ${BLUE}PocketBase UI:${NC} http://localhost:8090/_/"
echo -e "🧠 ${BLUE}OpenCode Logs:${NC} docker logs -f pocketcoder-opencode"
echo -e "🛡️  ${BLUE}Sandbox Logs:${NC} docker logs -f pocketcoder-sandbox"
echo -e "------------------------------------------------"
echo -e "${YELLOW}Hint:${NC} Use './test/run_all_tests.sh' to verify the installation."
