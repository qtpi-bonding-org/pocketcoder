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


# @pocketcoder-core: Master Orchestrator. Manages the full test suite and environment cleanup.
# test/run_all_tests.sh
# Master test suite runner for PocketCoder

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}🚀 PocketCoder Master Test Suite${NC}"
echo -e "${GREEN}========================================${NC}"

# Override .env if running from host
export POCKETBASE_URL="http://localhost:8090"

# Ensure we are in the root directory
if [ ! -f docker-compose.yml ]; then
    echo -e "${RED}Error: Must run from project root (where docker-compose.yml is)${NC}"
    exit 1
fi

# 1. Check Services
echo -e "\n${YELLOW}Step 1: Checking services...${NC}"
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}Services are not running. Starting them...${NC}"
    docker-compose up -d
    echo -e "${YELLOW}Waiting for services to warm up (10s)...${NC}"
    sleep 10
else
    echo -e "${GREEN}✓ Services are up.${NC}"
fi

RUN_FAILED=false

# Helper to run a test
run_test() {
    local script=$1
    local name=$2
    echo -e "\n${YELLOW}Running: $name...${NC}"
    if ./test/$script; then
        echo -e "${GREEN}✓ $name Passed.${NC}"
    else
        echo -e "${RED}✗ $name Failed.${NC}"
        RUN_FAILED=true
    fi
}

# 2. Key Integration Tests (Foundational: Health, SSH, Delegation)
run_test "run_integration_tests.sh" "Core System Integration"

# 3. Core Logic Flow
run_test "permission_flow_full.sh" "Permission & Gatekeeper Flow"
run_test "feature_turn_batching.sh" "Turn-Based Message Batching"

# 4. Feature Specific Tests
run_test "feature_artifacts.sh" "Artifact Serving API"
run_test "feature_whitelist_integration.sh" "Authority Evaluator (Integration)"
run_test "feature_whitelist.sh" "Whitelist Rules Persistence"

# 5. SOP Governance (Restarts Service - Must be Last)
run_test "sop_workflow_test.sh" "SOP Governance Master Signature"

echo -e "\n${GREEN}========================================${NC}"
if [ "$RUN_FAILED" = true ]; then
    echo -e "${RED}❌ SOME TESTS FAILED.${NC}"
    exit 1
else
    echo -e "${GREEN}✅ ALL TESTS PASSED SUCCESSFULLY!${NC}"
    exit 0
fi
