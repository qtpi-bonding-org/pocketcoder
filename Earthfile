VERSION 0.8

# Test suite targets for PocketCoder
# Uses Earthly to orchestrate docker-compose services and BATS tests
#
# Architecture:
#   - Earthly manages the full test lifecycle (build → up → test → down)
#   - Docker Compose defines service networking and dependencies
#   - BATS runs in a test container with access to service networks
#
# Usage:
#   earthly +test-all          # Build images, start services, run all tests, cleanup
#   earthly +test-health       # Run health tests only
#   earthly +test-connection   # Run connection tests only
#   earthly +test-integration  # Run integration tests only
#   earthly +test-syntax       # Validate BATS syntax (no services needed)
#   earthly +test-lint         # Lint test files (no services needed)
#
# For local development:
#   docker-compose up -d                                    # Start services
#   docker-compose -f docker-compose.test.yml run test     # Run all tests
#   docker-compose -f docker-compose.test.yml run test bats /tests/health/*.bats  # Specific suite

# Build all Docker images needed for testing
build-images:
    BUILD +build-backend
    BUILD +build-opencode
    BUILD +build-sandbox
    BUILD +build-test

# Build backend (PocketBase) image
build-backend:
    FROM DOCKERFILE -f services/pocketbase/Dockerfile .
    SAVE IMAGE pocketcoder-backend:latest

# Build OpenCode image
build-opencode:
    FROM DOCKERFILE -f services/opencode/Dockerfile .
    SAVE IMAGE pocketcoder-opencode:latest

# Build Sandbox image
build-sandbox:
    FROM DOCKERFILE -f services/sandbox/Dockerfile .
    SAVE IMAGE pocketcoder-sandbox:latest

# Build test runner image
build-test:
    FROM DOCKERFILE -f services/test/Dockerfile .
    SAVE IMAGE pocketcoder-test:latest

# Start docker-compose services
services-up:
    FROM earthly/dind:alpine
    COPY docker-compose.yml .
    COPY .env .
    WITH DOCKER \
        --load pocketcoder-backend:latest=+build-backend \
        --load pocketcoder-opencode:latest=+build-opencode \
        --load pocketcoder-sandbox:latest=+build-sandbox
        RUN docker-compose up -d && \
            echo "Waiting for services to be healthy..." && \
            sleep 10
    END

# Run all tests with full lifecycle management
test-all:
    FROM earthly/dind:alpine
    RUN apk add --no-cache bash
    COPY docker-compose.yml .
    COPY docker-compose.test.yml .
    COPY .env .
    COPY tests /tests
    WITH DOCKER \
        --load pocketcoder-backend:latest=+build-backend \
        --load pocketcoder-opencode:latest=+build-opencode \
        --load pocketcoder-sandbox:latest=+build-sandbox \
        --load pocketcoder-test:latest=+build-test
        RUN export $(cat .env | grep -v '^#' | xargs) && \
            docker-compose -f docker-compose.yml up -d && \
            echo "Waiting for services to be healthy..." && \
            sleep 15 && \
            docker-compose -f docker-compose.test.yml run --rm test bats --tap /tests/health /tests/connection /tests/integration
    END

# Health tests - verify container availability
test-health:
    FROM earthly/dind:alpine-3.19-docker-25.0.5-r0
    RUN apk add --no-cache bash curl
    COPY docker-compose.yml .
    COPY .env .
    COPY tests /tests
    WITH DOCKER \
        --load pocketcoder-backend:latest=+build-backend \
        --load pocketcoder-opencode:latest=+build-opencode \
        --load pocketcoder-sandbox:latest=+build-sandbox \
        --load pocketcoder-test:latest=+build-test
        RUN export $(cat .env | grep -v '^#' | xargs) && \
            docker network create pocketcoder-memory 2>/dev/null || true && \
            docker network create pocketcoder-control 2>/dev/null || true && \
            docker run -d --name pocketbase --network pocketcoder-memory -p 8090:8090 \
              -e POCKETBASE_SUPERUSER_EMAIL=${POCKETBASE_SUPERUSER_EMAIL} \
              -e POCKETBASE_SUPERUSER_PASSWORD=${POCKETBASE_SUPERUSER_PASSWORD} \
              -e POCKETBASE_ADMIN_EMAIL=${POCKETBASE_ADMIN_EMAIL} \
              -e POCKETBASE_ADMIN_PASSWORD=${POCKETBASE_ADMIN_PASSWORD} \
              -e AGENT_EMAIL=${AGENT_EMAIL} \
              -e AGENT_PASSWORD=${AGENT_PASSWORD} \
              -e OPENCODE_URL=${OPENCODE_URL} \
              pocketcoder-backend:latest && \
            docker run -d --name opencode --network pocketcoder-memory --network pocketcoder-control -p 3000:3000 \
              -e PORT=3000 \
              -e GEMINI_API_KEY=${GEMINI_API_KEY} \
              -e PROXY_URL=http://sandbox:3001 \
              pocketcoder-opencode:latest && \
            docker run -d --name sandbox --network pocketcoder-control \
              pocketcoder-sandbox:latest && \
            echo "Waiting for services to be healthy..." && \
            sleep 45 && \
            docker run --rm --network pocketcoder-memory \
              -v ./tests:/tests:ro \
              -e PB_URL=http://pocketbase:8090 \
              -e OPENCODE_URL=http://opencode:3000 \
              -e SANDBOX_HOST=sandbox \
              -e SANDBOX_RUST_PORT=3001 \
              -e SANDBOX_CAO_API_PORT=9889 \
              -e SANDBOX_CAO_MCP_PORT=9888 \
              -e OPENCODE_SSH_PORT=2222 \
              -e POCKETBASE_ADMIN_EMAIL=${POCKETBASE_ADMIN_EMAIL} \
              -e POCKETBASE_ADMIN_PASSWORD=${POCKETBASE_ADMIN_PASSWORD} \
              -e AGENT_EMAIL=${AGENT_EMAIL} \
              -e AGENT_PASSWORD=${AGENT_PASSWORD} \
              --entrypoint bash \
              pocketcoder-test:latest \
              -c 'bats --tap /tests/health/*.bats'
    END

# Connection tests - verify one-way communication between services
test-connection:
    FROM earthly/dind:alpine
    RUN apk add --no-cache bash
    COPY docker-compose.yml .
    COPY docker-compose.test.yml .
    COPY .env .
    COPY tests /tests
    WITH DOCKER \
        --load pocketcoder-backend:latest=+build-backend \
        --load pocketcoder-opencode:latest=+build-opencode \
        --load pocketcoder-sandbox:latest=+build-sandbox \
        --load pocketcoder-test:latest=+build-test
        RUN export $(cat .env | grep -v '^#' | xargs) && \
            docker-compose -f docker-compose.yml up -d && \
            echo "Waiting for services to be healthy..." && \
            sleep 15 && \
            docker-compose -f docker-compose.test.yml run --rm test bats --tap /tests/connection/*.bats
    END

# Integration tests - verify end-to-end flows
test-integration:
    FROM earthly/dind:alpine
    RUN apk add --no-cache bash
    COPY docker-compose.yml .
    COPY docker-compose.test.yml .
    COPY .env .
    COPY tests /tests
    WITH DOCKER \
        --load pocketcoder-backend:latest=+build-backend \
        --load pocketcoder-opencode:latest=+build-opencode \
        --load pocketcoder-sandbox:latest=+build-sandbox \
        --load pocketcoder-test:latest=+build-test
        RUN export $(cat .env | grep -v '^#' | xargs) && \
            docker-compose -f docker-compose.yml up -d && \
            echo "Waiting for services to be healthy..." && \
            sleep 15 && \
            docker-compose -f docker-compose.test.yml run --rm test bats --tap /tests/integration/*.bats
    END

# Validate BATS syntax without running tests (no services needed)
test-syntax:
    FROM +build-test
    COPY tests/ /tests/
    RUN find /tests -name "*.bats" -exec bats --count {} \;

# Lint test files with shellcheck (no services needed)
test-lint:
    FROM alpine:latest
    RUN apk add --no-cache shellcheck bash
    COPY tests/ /tests/
    RUN find /tests -name "*.sh" -exec shellcheck {} \;
    # BATS files need --shell=bash flag
    RUN find /tests -name "*.bats" -exec shellcheck --shell=bash {} \;

# Generate test summary report
test-report:
    FROM earthly/dind:alpine
    RUN apk add --no-cache bash
    COPY docker-compose.yml .
    COPY docker-compose.test.yml .
    COPY .env .
    COPY tests /tests
    WITH DOCKER \
        --load pocketcoder-backend:latest=+build-backend \
        --load pocketcoder-opencode:latest=+build-opencode \
        --load pocketcoder-sandbox:latest=+build-sandbox \
        --load pocketcoder-test:latest=+build-test
        RUN export $(cat .env | grep -v '^#' | xargs) && \
            docker-compose -f docker-compose.yml up -d && \
            echo "Waiting for services to be healthy..." && \
            sleep 15 && \
            docker-compose -f docker-compose.test.yml run --rm test bash -c ' \
            echo "# Test Summary Report" > /tmp/test_report.md && \
            echo "Generated: $(date)" >> /tmp/test_report.md && \
            echo "" >> /tmp/test_report.md && \
            for dir in health connection integration; do \
                echo "## $dir Tests" >> /tmp/test_report.md && \
                echo "" >> /tmp/test_report.md && \
                bats --tap /tests/$dir/*.bats 2>&1 | tee -a /tmp/test_report.md || true; \
                echo "" >> /tmp/test_report.md; \
            done && \
            cat /tmp/test_report.md'
    END
    SAVE ARTIFACT /tmp/test_report.md AS LOCAL test_report.md
