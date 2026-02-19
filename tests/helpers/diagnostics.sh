#!/bin/env bash
# tests/helpers/diagnostics.sh
# Health test diagnostics utilities
# Provides diagnostic output on failure, service-specific error messages, and troubleshooting hints
# Usage: source helpers/diagnostics.sh

# Configuration
export DIAGNOSTICS_ENABLED="${DIAGNOSTICS_ENABLED:-true}"

# Print diagnostic header
diagnostic_header() {
    local service="$1"
    echo ""
    echo "========================================"
    echo "  DIAGNOSTIC OUTPUT: $service"
    echo "========================================"
}

# Print diagnostic footer
diagnostic_footer() {
    echo "========================================"
    echo ""
}

# Print troubleshooting hints
print_troubleshooting_hints() {
    local service="$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  TROUBLESHOOTING HINTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    case "$service" in
        "PocketBase")
            echo "• Check if PocketBase container is running:"
            echo "    docker ps | grep pocketbase"
            echo ""
            echo "• Verify PocketBase is listening on port 8090:"
            echo "    nc -z localhost 8090"
            echo ""
            echo "• Check PocketBase logs for errors:"
            echo "    docker logs pocketcoder-pocketbase"
            echo ""
            echo "• Verify .env file has correct credentials:"
            echo "    grep POCKETBASE .env"
            echo ""
            echo "• Try restarting the container:"
            echo "    docker-compose restart pocketbase"
            ;;
        "OpenCode")
            echo "• Check if OpenCode container is running:"
            echo "    docker ps | grep opencode"
            echo ""
            echo "• Verify OpenCode is listening on port 3000:"
            echo "    nc -z localhost 3000"
            echo ""
            echo "• Check OpenCode logs for errors:"
            echo "    docker logs pocketcoder-opencode"
            echo ""
            echo "• Verify SSH daemon is running on port 2222:"
            echo "    nc -z localhost 2222"
            echo "    docker exec pocketcoder-opencode ps aux | grep sshd"
            echo ""
            echo "• Try restarting the container:"
            echo "    docker-compose restart opencode"
            ;;
        "Sandbox")
            echo "• Check if Sandbox container is running:"
            echo "    docker ps | grep sandbox"
            echo ""
            echo "• Verify Rust axum server is listening on port 3001:"
            echo "    nc -z localhost 3001"
            echo ""
            echo "• Verify CAO API is listening on port 9889:"
            echo "    nc -z localhost 9889"
            echo ""
            echo "• Check tmux socket exists:"
            echo "    docker exec pocketcoder-sandbox ls -la /tmp/tmux/pocketcoder"
            echo ""
            echo "• Check tmux session:"
            echo "    docker exec pocketcoder-sandbox tmux -S /tmp/tmux/pocketcoder list-sessions"
            echo ""
            echo "• Check Sandbox logs for errors:"
            echo "    docker logs pocketcoder-sandbox"
            echo ""
            echo "• Verify shell bridge binary:"
            echo "    docker exec pocketcoder-sandbox ls -la /app/shell_bridge/pocketcoder-shell"
            echo ""
            echo "• Try restarting the container:"
            echo "    docker-compose restart sandbox"
            ;;
        *)
            echo "• Check container status: docker ps | grep $service"
            echo "• Check container logs: docker logs $service"
            echo "• Verify network connectivity"
            ;;
    esac
    
    echo ""
}

# Get container logs
get_container_logs() {
    local container="$1"
    local lines="${2:-50}"
    
    echo "Container logs (last $lines lines):"
    
    # Try to get logs, but don't fail if container doesn't exist
    if docker logs --tail "$lines" "$container" 2>&1; then
        :  # Success, logs printed
    else
        # If docker logs fails, try to get any available info
        echo "  [Could not retrieve logs from $container]"
        echo "  Attempting to list all containers:"
        docker ps -a --format "table {{.Names}}\t{{.Status}}" 2>/dev/null | head -10
    fi
}

# Get network state
get_network_state() {
    echo "Network configuration:"
    
    # Check pocketcoder-memory network
    echo "  pocketcoder-memory network:"
    if docker network inspect pocketcoder-memory 2>/dev/null | grep -A5 "Containers" > /dev/null; then
        docker network inspect pocketcoder-memory 2>/dev/null | grep -A5 "Containers" | head -10
    else
        echo "    [Network not found or no containers connected]"
        # Try to list all networks
        echo "    Available networks:"
        docker network ls --filter "name=pocketcoder" --format "table {{.Name}}\t{{.Driver}}" 2>/dev/null || echo "    [Could not list networks]"
    fi
    
    echo ""
    echo "  pocketcoder-control network:"
    if docker network inspect pocketcoder-control 2>/dev/null | grep -A5 "Containers" > /dev/null; then
        docker network inspect pocketcoder-control 2>/dev/null | grep -A5 "Containers" | head -10
    else
        echo "    [Network not found or no containers connected]"
    fi
}

# Get container status
get_container_status() {
    local container="$1"
    echo "Container status for $container:"
    
    # First try docker inspect
    if docker inspect "$container" > /dev/null 2>&1; then
        docker inspect --format='  Status: {{.State.Status}}
  Running: {{.State.Running}}
  ExitCode: {{.State.ExitCode}}
  Health: {{.State.Health.Status}}
  StartedAt: {{.State.StartedAt}}
  FinishedAt: {{.State.FinishedAt}}' "$container" 2>/dev/null
    else
        # Fallback to docker ps if inspect fails
        echo "  [Container inspect failed, checking docker ps...]"
        if docker ps -a --filter "name=$container" --format "table {{.Names}}\t{{.Status}}\t{{.State}}" 2>/dev/null | grep -q "$container"; then
            docker ps -a --filter "name=$container" --format "  Name: {{.Names}}\n  Status: {{.Status}}\n  State: {{.State}}"
        else
            echo "  [Container not found in docker ps either]"
        fi
    fi
}

# Print service-specific error message
print_service_error() {
    local service="$1"
    local error="$2"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ERROR: $service"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $error"
    echo ""
}

# Run diagnostic on failure
run_diagnostic() {
    local service="$1"
    local test_name="$2"
    local error_msg="$3"
    
    if [ "$DIAGNOSTICS_ENABLED" != "true" ]; then
        return
    fi
    
    # Minimal output - just test name and error
    echo ""
    echo "❌ $test_name"
    echo "   Error: $error_msg"
}

# BATS helper for diagnostic on failure
# Usage: [ "$x" = "y" ] || run_diagnostic_on_failure "PocketBase" "Health check failed"
#
# IMPORTANT: This function ALWAYS prints diagnostics and returns 1 (fails the test).
# The old implementation checked $status (the BATS `run` variable), which meant
# assertions like `[ "$x" = "y" ] || run_diagnostic_on_failure ...` would silently
# pass because $status referred to the last `run` command, not the `[` test.
#
# Now: if you call this function, the test fails. Period.
run_diagnostic_on_failure() {
    local service="$1"
    local error_msg="$2"

    run_diagnostic "$service" "${BATS_TEST_NAME:-unknown}" "$error_msg"

    # Always fail — this function is only called from the || branch of a failed assertion
    return 1
}

# Check endpoint with diagnostic
# Usage: check_endpoint_with_diagnostic "http://localhost:3000/health" "OpenCode" "Health endpoint"
check_endpoint_with_diagnostic() {
    local url="$1"
    local service="$2"
    local test_name="$3"
    
    local response
    response=$(curl -s -w "\n%{http_code}" "$url" 2>/dev/null)
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" != "200" ]; then
        print_service_error "$service" "HTTP $http_code from $url"
        run_diagnostic "$service" "$test_name" "HTTP $http_code from $url"
        return 1
    fi
    
    echo "$body"
    return 0
}

# Check port with diagnostic
# Check port with diagnostic
check_port_with_diagnostic() {
    local host="$1"
    local port="$2"
    local service="$3"
    local test_name="$4"
    
    if ! nc -z "$host" "$port" 2>/dev/null; then
        print_service_error "$service" "Port $host:$port is not accessible"
        run_diagnostic "$service" "$test_name" "Port $host:$port is not accessible"
        return 1
    fi
    
    return 0
}

# Check docker exec command with diagnostic
check_docker_exec_with_diagnostic() {
    local container="$1"
    local command="$2"
    local service="$3"
    local test_name="$4"
    
    if ! docker exec "$container" bash -c "$command" > /dev/null 2>&1; then
        print_service_error "$service" "Command failed in container $container: $command"
        run_diagnostic "$service" "$test_name" "Command failed: $command"
        return 1
    fi
    
    return 0
}

# Export functions for use in BATS
export -f diagnostic_header diagnostic_footer print_troubleshooting_hints
export -f get_container_logs get_network_state get_container_status
export -f print_service_error run_diagnostic run_diagnostic_on_failure
export -f check_endpoint_with_diagnostic check_port_with_diagnostic
export -f check_docker_exec_with_diagnostic