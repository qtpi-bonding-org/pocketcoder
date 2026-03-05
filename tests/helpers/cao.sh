#!/usr/bin/env bash
# tests/helpers/cao.sh
# poco-agents helper functions for tests
# Provides utilities for verifying poco-agents MCP server availability

# Verify poco-agents is accessible
# Usage: verify_poco_agents_accessible
verify_poco_agents_accessible() {
    local url="http://sandbox:9888"

    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "${url}/health" 2>/dev/null)

    if [ "$response" != "200" ]; then
        echo "poco-agents is not accessible at ${url}/health (HTTP ${response})" >&2
        return 1
    fi

    return 0
}

# Legacy alias for backward compatibility
verify_cao_accessible() {
    verify_poco_agents_accessible "$@"
}

# Export functions for use in BATS
export -f verify_poco_agents_accessible
export -f verify_cao_accessible
