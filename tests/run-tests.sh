#!/bin/bash
# Test runner script for PocketCoder
# Wraps docker compose commands to run BATS tests
#
# Usage:
#   ./scripts/run-tests.sh                    # Run all tests
#   ./scripts/run-tests.sh health             # Run health tests
#   ./scripts/run-tests.sh connection         # Run connection tests
#   ./scripts/run-tests.sh integration        # Run integration tests
#   ./scripts/run-tests.sh integration/full-flow.bats  # Run specific test file

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
COMPOSE_FILES=("-f" "docker-compose.yml" "-f" "docker-compose.test.yml")
TEST_SERVICE="test"
TEST_DIR="/tests"
TIMEOUT=300000

# Helper functions
print_usage() {
    cat << EOF
Usage: $(basename "$0") [TEST_PATH]

Run BATS tests in Docker containers.

Arguments:
  TEST_PATH    Path to test file or directory (optional)
               Examples:
                 health                         - Run all health tests
                 connection                     - Run all connection tests
                 integration                    - Run all integration tests
                 integration/core               - Run core flow tests
                 integration/auth               - Run auth & permission tests
                 integration/mcp                - Run MCP gateway tests
                 integration/features           - Run feature-specific tests
                 integration/agent              - Run agent behavior tests
                 integration/core/full-flow.bats - Run specific test file
               If omitted, runs all tests

Examples:
  $(basename "$0")                                     # Run all tests
  $(basename "$0") health                              # Run health tests
  $(basename "$0") integration/core                    # Run core flow tests
  $(basename "$0") integration/agent                   # Run agent behavior tests
  $(basename "$0") integration/core/full-flow.bats     # Run full flow test

EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if docker compose is available
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "docker is not installed"
        exit 1
    fi
    
    if ! docker compose version &> /dev/null; then
        log_error "docker compose is not available"
        exit 1
    fi
}

# Capture container logs before teardown
capture_logs() {
    local log_file="$1"
    
    if [ -z "$log_file" ]; then
        local log_dir="tests/logs"
        local timestamp
        timestamp=$(date +%Y%m%d_%H%M%S)
        log_file="$log_dir/test-run-${timestamp}.log"
        mkdir -p "$log_dir"
    fi
    
    log_info "Capturing container logs to $log_file"
    
    {
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                            CONTAINER LOGS                                    ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        
        # Hardcoded container names to ensure we get all logs
        for container_name in pocketcoder-pocketbase pocketcoder-opencode pocketcoder-sandbox pocketcoder-mcp-gateway; do
            echo "┌──────────────────────────────────────────────────────────────────────────────┐"
            echo "│ Container: ${container_name}"
            echo "└──────────────────────────────────────────────────────────────────────────────┘"
            
            # Get ALL logs from the container (no tail limit)
            if docker logs "$container_name" &>/dev/null; then
                docker logs "$container_name" 2>&1 || echo "  [failed to get logs]"
            else
                echo "  [container not found or not running]"
            fi
            echo ""
        done
        
        echo "╔══════════════════════════════════════════════════════════════════════════════╗"
        echo "║                         END OF CONTAINER LOGS                                ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    } >> "$log_file" 2>&1
    
    log_info "Logs saved to $log_file"
}

# Start services
start_services() {
    log_info "Building and starting services..."
    docker compose "${COMPOSE_FILES[@]}" up -d --build
    log_info "Services started"
}

# Stop services
stop_services() {
    log_info "Stopping services and removing volumes..."
    docker compose "${COMPOSE_FILES[@]}" down -v
    log_info "Services stopped and volumes removed"
}

# Run tests
run_tests() {
    local test_path="$1"
    shift || true
    local extra_args="$*"

    # Strip leading tests/ if present to handle both 'tests/integration/...' and 'integration/...'
    test_path="${test_path#tests/}"
    
    # Build and start services
    start_services
    
    if [ -z "$test_path" ]; then
        # Run all tests
        log_info "Running all tests..."
        docker compose "${COMPOSE_FILES[@]}" run --rm \
            -e TIMEOUT_MULTIPLIER="${TIMEOUT_MULTIPLIER:-1}" \
            --entrypoint bash \
            "$TEST_SERVICE" \
            -c "bats --tap --recursive $extra_args $TEST_DIR/health $TEST_DIR/connection $TEST_DIR/integration"
    else
        # Run specific test path
        log_info "Running tests: $test_path"
        docker compose "${COMPOSE_FILES[@]}" run --rm \
            -e TIMEOUT_MULTIPLIER="${TIMEOUT_MULTIPLIER:-1}" \
            --entrypoint bash \
            "$TEST_SERVICE" \
            -c "bats --tap --recursive $extra_args $TEST_DIR/$test_path"
    fi
}

# Main
main() {
    local test_path="${1:-}"
    
    # Show help if requested
    if [ "$test_path" = "-h" ] || [ "$test_path" = "--help" ]; then
        print_usage
        exit 0
    fi
    
    # Check prerequisites
    check_docker
    
    # Setup log file
    local log_dir="tests/logs"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="$log_dir/test-run-${timestamp}.log"
    mkdir -p "$log_dir"
    
    log_info "Test summary will be saved to $log_file"
    echo "=== Test Run: $timestamp ===" > "$log_file"
    echo "=== Command: run-tests.sh $test_path ===" >> "$log_file"
    echo "" >> "$log_file"

    # Ensure a clean slate before starting
    stop_services
    
    # Run tests and check for failures in TAP output
    local exit_code=0
    local test_output
    test_output=$(run_tests "$test_path" 2>&1 | tee -a "$log_file")
    
    # Check if any tests failed by looking for "not ok" in TAP output
    if echo "$test_output" | grep -q "^not ok"; then
        log_error "Tests failed - see $log_file for details"
        exit_code=1
    else
        log_info "All tests passed"
        exit_code=0
    fi
    
    # Capture container logs
    capture_logs "$log_file"
    
    # Cleanup
    stop_services
    
    exit $exit_code
}

main "$@"
