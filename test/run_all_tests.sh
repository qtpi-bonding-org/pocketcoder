#!/bin/bash
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

# 2. Run Permission Flow Test
echo -e "\n${YELLOW}Step 2: Testing Permission & Reasoning Flow...${NC}"
echo -e "${YELLOW}(opencode <-> relay <-> pocketbase)${NC}"
if ./test/permission_flow_full.sh; then
    echo -e "${GREEN}✓ Permission Flow Passed.${NC}"
else
    echo -e "${RED}✗ Permission Flow Failed.${NC}"
    exit 1
fi

# 3. Run SSH Integration tests
echo -e "\n${YELLOW}Step 3: Testing SSH & Sandbox Integration...${NC}"
echo -e "${YELLOW}(pocketbase <-> relay <-> sandbox)${NC}"
# run_integration_tests.sh already handles start/stop if needed, 
# but we have services up, so it will use existing.
if ./test/run_integration_tests.sh; then
    echo -e "${GREEN}✓ SSH Integration Passed.${NC}"
else
    echo -e "${RED}✗ SSH Integration Failed.${NC}"
    exit 1
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✅ ALL TESTS PASSED SUCCESSFULLY!${NC}"
echo -e "${GREEN}========================================${NC}"
