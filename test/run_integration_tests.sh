#!/bin/bash
# SSH Key Integration Test Runner
# Starts services and runs integration tests

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}SSH Key Integration Test Suite${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Error: docker-compose is not installed${NC}"
    exit 1
fi

# Check if services are already running
if docker-compose ps | grep -q "Up"; then
    echo -e "${YELLOW}Services are already running${NC}"
    USE_EXISTING=true
else
    echo -e "${YELLOW}Starting services with docker-compose...${NC}"
    docker-compose up -d
    USE_EXISTING=false
    
    # Wait for services to be ready
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 5
    
    # Wait for PocketBase to be healthy
    MAX_RETRIES=30
    RETRY=0
    while [ $RETRY -lt $MAX_RETRIES ]; do
        if curl -s -f http://localhost:8080/api/health > /dev/null 2>&1; then
            echo -e "${GREEN}PocketBase is ready${NC}"
            break
        fi
        RETRY=$((RETRY+1))
        echo -e "${YELLOW}Waiting for PocketBase... ($RETRY/$MAX_RETRIES)${NC}"
        sleep 1
    done
    
    if [ $RETRY -eq $MAX_RETRIES ]; then
        echo -e "${RED}PocketBase failed to start${NC}"
        docker-compose logs pocketbase
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}Running integration tests...${NC}"
echo ""

# Run the integration tests
./test/ssh_key_integration_test.sh

TEST_EXIT_CODE=$?

# Run deletion test if main tests passed
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}Running deletion/revocation test...${NC}"
    echo ""
    ./test/ssh_key_deletion_test.sh
    TEST_EXIT_CODE=$?
fi

# Cleanup if we started the services
if [ "$USE_EXISTING" = "false" ]; then
    echo ""
    echo -e "${YELLOW}Stopping services...${NC}"
    docker-compose down
fi

exit $TEST_EXIT_CODE
