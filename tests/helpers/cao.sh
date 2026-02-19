#!/usr/bin/env bash
# tests/helpers/cao.sh
# CAO (CLI Agent Orchestrator) helper functions for tests
# Provides utilities for creating and managing test terminals in CAO

# Create a terminal in CAO for testing
# Usage: create_test_terminal <delegating_agent_id> <session_name> <agent_profile>
# Returns: terminal_id
create_test_terminal() {
    local delegating_agent_id="$1"
    local session_name="${2:-pocketcoder}"
    local agent_profile="${3:-poco}"
    local working_directory="${4:-/workspace}"
    
    local cao_url="http://sandbox:9889"
    
    # Create terminal in the session using query parameters
    local response
    response=$(curl -s -X POST "${cao_url}/sessions/${session_name}/terminals?provider=tmux&agent_profile=${agent_profile}&working_directory=${working_directory}&delegating_agent_id=${delegating_agent_id}" \
        -H "Content-Type: application/json" 2>/dev/null)
    
    # Extract terminal_id from response
    local terminal_id
    terminal_id=$(echo "$response" | jq -r '.id // empty')
    
    if [ -z "$terminal_id" ]; then
        echo "Failed to create terminal in CAO: $response" >&2
        return 1
    fi
    
    echo "$terminal_id"
    return 0
}

# Get terminal info by delegating_agent_id
# Usage: get_terminal_by_agent_id <delegating_agent_id>
get_terminal_by_agent_id() {
    local delegating_agent_id="$1"
    local cao_url="http://sandbox:9889"
    
    curl -s "${cao_url}/terminals/by-delegating-agent/${delegating_agent_id}" 2>/dev/null
}

# Delete a terminal from CAO
# Usage: delete_test_terminal <terminal_id>
delete_test_terminal() {
    local terminal_id="$1"
    local cao_url="http://sandbox:9889"
    
    # CAO doesn't have a delete endpoint yet, so we just skip cleanup
    # The terminal will be cleaned up when the tmux session is destroyed
    return 0
}

# Verify CAO is accessible
# Usage: verify_cao_accessible
verify_cao_accessible() {
    local cao_url="http://sandbox:9889"
    
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "${cao_url}/health" 2>/dev/null)
    
    if [ "$response" != "200" ]; then
        echo "CAO is not accessible at ${cao_url}/health (HTTP ${response})" >&2
        return 1
    fi
    
    return 0
}

# Export functions for use in BATS
export -f create_test_terminal
export -f get_terminal_by_agent_id
export -f delete_test_terminal
export -f verify_cao_accessible
