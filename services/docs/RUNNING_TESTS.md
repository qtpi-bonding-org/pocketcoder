# Running Tests with Earthly

This document explains how to run the PocketCoder test suite using Earthly.

## Prerequisites

1. Install Earthly: https://earthly.dev/get-earthly
2. Ensure Docker is running
3. Ensure `.env` file exists with required variables (see `.env.example`)

## Required Environment Variables

The following variables must be set in your `.env` file:

```bash
COMPOSE_PROJECT_NAME=pocketcoder
PORT=3000
POCKETBASE_URL=http://pocketbase:8090
OPENCODE_URL=http://opencode:3000

# Credentials
POCKETBASE_SUPERUSER_EMAIL=superuser@pocketcoder.app
POCKETBASE_SUPERUSER_PASSWORD=<your-password>
POCKETBASE_ADMIN_EMAIL=admin@pocketcoder.local
POCKETBASE_ADMIN_PASSWORD=<your-password>
AGENT_EMAIL=agent@pocketcoder.local
AGENT_PASSWORD=<your-password>

# AI API Key
GEMINI_API_KEY=<your-api-key>
```

## Running Tests

### Health Tests Only (Checkpoint 4)

```bash
earthly +test-health
```

This will:
1. Build all Docker images (backend, opencode, sandbox, test)
2. Start the services with environment variables from `.env`
3. Wait for services to be healthy
4. Run all health tests in `tests/health/*.bats`

### All Tests

```bash
earthly +test-all
```

Runs health, connection, and integration tests.

### Connection Tests Only

```bash
earthly +test-connection
```

### Integration Tests Only

```bash
earthly +test-integration
```

### Generate Test Report

```bash
earthly +test-report
```

Creates a `test_report.md` file with detailed test results.

## Troubleshooting

### Environment Variables Not Loading

If you see errors about missing environment variables:

1. Verify `.env` file exists in the project root
2. Check that all required variables are set
3. Ensure no syntax errors in `.env` (no spaces around `=`)

### Services Not Starting

If services fail to start:

```bash
# Check if ports are already in use
docker ps

# Clean up any existing containers
docker-compose down -v

# Try again
earthly +test-health
```

### Tests Timing Out

If tests timeout waiting for services:

1. Increase the sleep time in Earthfile (currently 15 seconds)
2. Check service logs: `docker-compose logs <service-name>`
3. Verify your machine has enough resources (Docker Desktop settings)

## Test Output

Tests use TAP (Test Anything Protocol) format. Example output:

```
1..3
ok 1 PocketBase health endpoint returns 200 OK
ok 2 PocketBase database is accessible
ok 3 PocketBase Relay module is loaded
```

- `ok` = test passed
- `not ok` = test failed
- Numbers indicate test count

## Local Development

For faster iteration during development, you can run tests without Earthly:

```bash
# Start services
docker-compose up -d

# Run specific test file
docker-compose -f docker-compose.test.yml run --rm test bats /tests/health/pocketbase.bats

# Run all health tests
docker-compose -f docker-compose.test.yml run --rm test bats /tests/health/*.bats

# Cleanup
docker-compose down
```

This skips the image building step and is faster for rapid testing.
