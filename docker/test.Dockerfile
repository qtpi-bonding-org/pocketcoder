# Test container with BATS and all testing dependencies
FROM bats/bats:latest

# Install testing dependencies
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    coreutils \
    docker-cli \
    netcat-openbsd \
    tmux

# Set working directory
WORKDIR /tests

# Copy test helpers and configuration
COPY tests/helpers/ /tests/helpers/
COPY tests/test-env.sh /tests/test-env.sh

# Default command runs all tests
CMD ["bats", "--tap", "/tests/health", "/tests/connection", "/tests/integration"]
