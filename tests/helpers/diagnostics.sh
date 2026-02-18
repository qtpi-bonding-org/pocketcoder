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
    if docker logs --tail "$lines" "$container" 2>&1 | tail -20; then
        echo "  [No logs available or container not found]"
    fi
}

# Get network state
get_network_state() {
    echo "Network configuration:"
    echo "  pocketcoder-memory network:"
    docker network inspect pocketcoder-memory 2>/dev/null | grep -A5 "Containers" || echo "    [Network not found]"
    echo ""
    echo "  pocketcoder-control network:"
    docker network inspect pocketcoder-control 2>/dev/null | grep -A5 "Containers" || echo "    [Network not found]"
}

# Get container status
get_container_status() {
    local container="$1"
    echo "Container status for $container:"
    docker inspect --format='  Status: {{.State.Status}}
  Running: {{.State.Running}}
  ExitCode: {{.State.ExitCode}}
  Health: {{.State.Health.Status}}
  StartedAt: {{.State.StartedAt}}
  FinishedAt: {{.State.FinishedAt}}' "$container" 2>/dev/null || echo "  [Container not found]"
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
    
    diagnostic_header "$service"
    
    echo "Test: $test_name"
    echo "Error: $error_msg"
    echo ""
    
    # Get container status
    local container_name=""
    case "$service" in
        "PocketBase") container_name="pocketcoder-pocketbase" ;;
        "OpenCode") container_name="pocketcoder-opencode" ;;
        "Sandbox") container_name="pocketcoder-sandbox" ;;
    esac
    
    if [ -n "$container_name" ]; then
        echo "Container Status:"
        get_container_status "$container_name"
        echo ""
        
        echo "Container Logs:"
        get_container_logs "$container_name" 30
        echo ""
    fi
    
    echo "Network State:"
    get_network_state
    echo ""
    
    print_troubleshooting_hints "$service"
    
    diagnostic_footer
}

# BATS helper for diagnostic on failure
# Usage: run_diagnostic_on_failure "PocketBase" "Health check failed"
run_diagnostic_on_failure() {
    local service="$1"
    local error_msg="$2"
    
    if [ "$status" -ne 0 ]; then
        run_diagnostic "$service" "$BATS_TEST_NAME" "$error_msg"
    fi
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