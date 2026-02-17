#!/bin/bash
# new_tests/run_test.sh
# Simple wrapper to run tests in Docker containers
# Usage: ./run_test.sh <zone> [container]
# Example: ./run_test.sh b pocketcoder-opencode
#          ./run_test.sh a pocketcoder-pocketbase
#          ./run_test.sh c pocketcoder-proxy
#          ./run_test.sh d pocketcoder-sandbox

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ZONE="${1:-b}"
CONTAINER="${2:-pocketcoder-pocketbase}"
TEST_FILE="$SCRIPT_DIR/zone_${ZONE}_tests.sh"

if [ ! -f "$TEST_FILE" ]; then
    echo "❌ Error: Test file not found: $TEST_FILE"
    echo "Available zones: a, b, c, d"
    exit 1
fi

echo "🧪 Running Zone $ZONE tests in container: $CONTAINER"
echo "================================================"

# Set environment variables based on zone
case "$ZONE" in
    a)  export PB_URL="http://pocketbase:8090" ;;
    b)  export OPENCODE_URL="http://opencode:4096" ;;
    c)  export PROXY_URL="http://proxy:3001"; export OPENCODE_URL="http://opencode:3000" ;;
    d)  export CAO_URL="http://cao:3002"; export OPENCODE_URL="http://opencode:3000" ;;
esac

# Copy test files to container
echo "📦 Copying test files to container..."
docker exec "$CONTAINER" mkdir -p /workspace/new_tests 2>/dev/null || true
docker cp "$TEST_FILE" "$CONTAINER:/workspace/new_tests/"
docker cp "$SCRIPT_DIR/helpers/." "$CONTAINER:/workspace/new_tests/helpers/" 2>/dev/null || true

# Run the test directly
echo "🚀 Running tests..."
docker exec -e OPENCODE_URL="$OPENCODE_URL" -e PB_URL="$PB_URL" -e PROXY_URL="$PROXY_URL" -e CAO_URL="$CAO_URL" "$CONTAINER" busybox sh "/workspace/new_tests/zone_${ZONE}_tests.sh"

echo ""
echo "================================================"
echo "✅ Zone $ZONE tests completed"