# Test container with BATS and all testing dependencies
FROM bats/bats:1.11.1

# Install testing dependencies
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    coreutils \
    docker-cli

# Set working directory
WORKDIR /tests

# Copy test helpers and configuration
COPY tests/helpers/ /tests/helpers/
COPY tests/test-env.sh /tests/test-env.sh

# Default command runs the opt-in current agent acceptance suites. The
# production stack has no general-purpose `test` Compose service anymore.
CMD ["bats", "--tap", "/tests/compose/agent/config_pipeline.bats", "/tests/compose/agent/acceptance.bats", "/tests/compose/agent/mcp_gateway.bats"]
