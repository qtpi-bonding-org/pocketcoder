#!/bin/bash
# tests/test-env.sh
# Default environment configuration for test suite
# This file is sourced by helper scripts to set default values

# Container endpoints
export PB_URL="${PB_URL:-http://localhost:8090}"
export OPENCODE_URL="${OPENCODE_URL:-http://localhost:3000}"
export SANDBOX_HOST="${SANDBOX_HOST:-localhost}"

# Sandbox ports
export SANDBOX_RUST_PORT="${SANDBOX_RUST_PORT:-3001}"
export SANDBOX_CAO_API_PORT="${SANDBOX_CAO_API_PORT:-9889}"
export SANDBOX_CAO_MCP_PORT="${SANDBOX_CAO_MCP_PORT:-9888}"
export OPENCODE_SSH_PORT="${OPENCODE_SSH_PORT:-2222}"

# Sandbox service URLs (constructed from host and ports)
export SANDBOX_URL="${SANDBOX_URL:-http://${SANDBOX_HOST}:${SANDBOX_RUST_PORT}}"
export CAO_API_URL="${CAO_API_URL:-http://${SANDBOX_HOST}:${SANDBOX_CAO_API_PORT}}"
export CAO_MCP_URL="${CAO_MCP_URL:-http://${SANDBOX_HOST}:${SANDBOX_CAO_MCP_PORT}}"

# Test configuration
export TEST_TIMEOUT_HEALTH="${TEST_TIMEOUT_HEALTH:-30}"
export TEST_TIMEOUT_CONNECTION="${TEST_TIMEOUT_CONNECTION:-60}"
export TEST_TIMEOUT_INTEGRATION="${TEST_TIMEOUT_INTEGRATION:-300}"
export TEST_RETRY_COUNT="${TEST_RETRY_COUNT:-3}"
export TEST_RETRY_DELAY="${TEST_RETRY_DELAY:-2}"
export TEST_CLEANUP_ON_FAILURE="${TEST_CLEANUP_ON_FAILURE:-true}"
export TEST_PARALLEL="${TEST_PARALLEL:-false}"

# Polling configuration
export POLL_INTERVAL="${POLL_INTERVAL:-1}"

# Tmux socket path
export TMUX_SOCKET="${TMUX_SOCKET:-/tmp/tmux/pocketcoder}"
export TMUX_SESSION="${TMUX_SESSION:-pocketcoder}"

# Shell bridge path
export SHELL_BRIDGE_PATH="${SHELL_BRIDGE_PATH:-/shell_bridge/pocketcoder-shell}"

# CAO database path
export CAO_DB_PATH="${CAO_DB_PATH:-/root/.aws/cli-agent-orchestrator/db/cli-agent-orchestrator.db}"

# Test data prefix
export TEST_ID_PREFIX="${TEST_ID_PREFIX:-test_}"

# SSE endpoint
export OPENCODE_SSE_ENDPOINT="${OPENCODE_SSE_ENDPOINT:-/event}"

# Session endpoints
export OPENCODE_SESSION_ENDPOINT="${OPENCODE_SESSION_ENDPOINT:-/session}"
export OPENCODE_PROMPT_ENDPOINT="${OPENCODE_PROMPT_ENDPOINT:-/prompt_async}"

# Exec endpoint
export SANDBOX_EXEC_ENDPOINT="${SANDBOX_EXEC_ENDPOINT:-/exec}"

# Terminal resolution endpoint
export CAO_TERMINAL_ENDPOINT="${CAO_TERMINAL_ENDPOINT:-/terminals/by-delegating-agent}"

# Sentinel pattern for command execution
export SENTINEL_PATTERN="${SENTINEL_PATTERN:-POCKETCODER_EXIT:}"