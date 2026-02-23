# Testing Guide

This document explains the PocketCoder testing architecture and how to run tests.

## Architecture Overview

The testing infrastructure uses three complementary tools:

1. **Earthly** - Orchestrates the full test lifecycle (build → start → test → cleanup)
2. **Docker Compose** - Defines service networking and dependencies
3. **BATS** - Bash Automated Testing System for writing tests

### Why This Stack?

- **Earthly**: Provides reproducible builds, proper caching, and CI/CD integration
- **Docker Compose**: Manages multi-container networking and service dependencies
- **BATS**: Simple, readable test syntax with TAP-compliant output

## Quick Start

### Run All Tests (Recommended)

```bash
earthly +test-all
```

This single command:
1. Builds all Docker images (backend, opencode, sandbox, test)
2. Starts services via docker-compose
3. Runs all test suites (health, connection, integration)
4. Cleans up containers and networks

### Run Specific Test Suites

```bash
# Health tests only (fastest)
earthly +test-health

# Connection tests only
earthly +test-connection

# Integration tests only (slowest)
earthly +test-integration
```

### Lint and Syntax Validation

```bash
# Validate BATS syntax (no services needed)
earthly +test-syntax

# Lint test files with shellcheck
earthly +test-lint
```

## Local Development Workflow

For faster iteration during test development, you can run docker-compose directly:

### 1. Start Services

```bash
docker-compose up -d
```

### 2. Run Tests

```bash
# Run all tests
docker-compose -f docker-compose.test.yml run --rm test

# Run specific test suite
docker-compose -f docker-compose.test.yml run --rm test bats /tests/health/*.bats

# Run single test file
docker-compose -f docker-compose.test.yml run --rm test bats /tests/health/opencode.bats
```

### 3. Cleanup

```bash
docker-compose down
```

### Alternative: BATS via Docker Alias

For quick test file validation without starting services:

```bash
# Create alias
alias bats='docker run -it -v "$(pwd):/code" -w /code bats/bats:latest'

# Run tests
bats tests/health/opencode.bats
```

## Test Organization

```
tests/
├── health/              # Container health verification
│   ├── opencode.bats
│   ├── pocketbase.bats
│   └── sandbox.bats
├── connection/          # One-way communication tests
│   ├── pb-to-opencode.bats
│   ├── opencode-to-pb.bats
│   ├── opencode-to-sandbox.bats
│   ├── sandbox-to-opencode.bats
│   └── pb-to-sandbox.bats
├── integration/         # End-to-end flow tests
│   ├── full-flow.bats
│   └── cao-subagent.bats
└── helpers/             # Shared test utilities
    ├── auth.sh
    ├── cleanup.sh
    ├── wait.sh
    ├── assertions.sh
    ├── diagnostics.sh
    └── tracking.sh
```

## Test Categories

### Health Tests (~2 minutes)

Verify each container is operational:
- HTTP endpoints respond correctly
- Required ports are listening
- Internal services (tmux, sshd) are running

### Connection Tests (~5 minutes)

Verify one-way communication paths:
- PocketBase → OpenCode (HTTP POST)
- OpenCode → PocketBase (SSE stream)
- OpenCode → Sandbox (shell bridge)
- Sandbox → OpenCode (sync response)
- PocketBase ↔ Sandbox (verify isolation)

### Integration Tests (~10 minutes)

Verify complete end-to-end flows:
- User message → full system traversal → response
- Permission gating workflow
- CAO subagent spawning and cleanup

## Environment Configuration

Test configuration is managed via environment variables in `tests/test-env.sh`:

```bash
# Container endpoints
PB_URL=http://pocketbase:8090
OPENCODE_URL=http://opencode:3000
SANDBOX_HOST=sandbox

# Timeouts
TEST_TIMEOUT_HEALTH=30
TEST_TIMEOUT_CONNECTION=60
TEST_TIMEOUT_INTEGRATION=300

# Retry logic
TEST_RETRY_COUNT=3
TEST_RETRY_DELAY=2
```

Override these in `docker-compose.test.yml` or via command line:

```bash
docker-compose -f docker-compose.test.yml run --rm \
  -e TEST_TIMEOUT_HEALTH=60 \
  test bats /tests/health/*.bats
```

## Writing Tests

### Basic Test Structure

```bash
#!/usr/bin/env bats

load '../helpers/auth.sh'
load '../helpers/cleanup.sh'
load '../helpers/wait.sh'

setup() {
    load_env
    TEST_ID=$(generate_test_id)
    export CURRENT_TEST_ID="$TEST_ID"
}

teardown() {
    cleanup_test_data "$TEST_ID" || true
}

@test "My test description" {
    # Test implementation
    run curl -s "$OPENCODE_URL/health"
    [ "$status" -eq 0 ]
    [[ "${lines[-1]}" == "200" ]]
}
```

### Helper Functions

Common helpers available in all tests:

```bash
# Wait for condition with timeout
wait_for_condition 30 "curl -s http://localhost:3000/health | grep -q ok"

# Wait for HTTP endpoint
wait_for_endpoint "http://localhost:3000/health" 30

# Retry with exponential backoff
retry 3 2 "curl -s http://localhost:3000/health"

# Track artifacts for cleanup
track_artifact "opencode_sessions:$session_id"

# Run diagnostics on failure
run_diagnostic_on_failure "OpenCode" "Health check failed"
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Test Suite

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: earthly/actions-setup@v1
      - name: Run tests
        run: earthly +test-all
```

### GitLab CI Example

```yaml
test:
  image: earthly/earthly:latest
  script:
    - earthly +test-all
```

## Troubleshooting

### Tests Fail to Connect to Services

Check that services are running and healthy:

```bash
docker-compose ps
docker-compose logs opencode
```

### Tests Timeout

Increase timeout values:

```bash
docker-compose -f docker-compose.test.yml run --rm \
  -e TEST_TIMEOUT_HEALTH=120 \
  test
```

### Orphaned Test Data

Clean up manually:

```bash
docker-compose -f docker-compose.test.yml run --rm test \
  bash /tests/helpers/cleanup.sh --orphaned
```

### Network Issues

Ensure networks exist:

```bash
docker network create pocketcoder-memory
docker network create pocketcoder-control
```

## Performance Targets

- Health tests: < 2 minutes
- Connection tests: < 5 minutes
- Integration tests: < 10 minutes
- Full suite: < 15 minutes

## Future Enhancements

- Parallel test execution (currently N=1 for MVP)
- Property-based testing (expand from N=1 to N=100+)
- Performance benchmarking
- Load testing
- Chaos engineering tests
