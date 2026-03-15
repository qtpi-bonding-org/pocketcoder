# Use shared Rust builder
FROM rust:1.83-alpine AS rust-builder
RUN apk add --no-cache musl-dev gcc
WORKDIR /build
COPY services/proxy/Cargo.toml services/proxy/Cargo.lock* ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src
COPY services/proxy/src ./src
RUN touch src/main.rs
RUN cargo build --release

FROM oven/bun:alpine

# Install basic system dependencies (CURL is needed for health checks/scripts)
# (Alpine doesn't use bash by default, we keep it minimal)
RUN apk add --no-cache curl ripgrep docker-cli

# Install docker-mcp plugin for MCP catalog browsing
COPY scripts/install-docker-mcp.sh /tmp/install-docker-mcp.sh
RUN /tmp/install-docker-mcp.sh && rm /tmp/install-docker-mcp.sh

ENV DOCKER_MCP_IN_CONTAINER=1

# Install OpenCode (The Reasoning Engine)
RUN bun install -g opencode-ai@1.2.8

# Create node symlink for opencode script compatibility
RUN ln -s /usr/local/bin/bun /usr/local/bin/node

# Set the working directory
WORKDIR /app

# 🛡️ HARD SHELL ENFORCEMENT
# Copy the pocketcoder binary and create wrapper script at build time
COPY --from=rust-builder /build/target/release/pocketcoder-proxy /usr/local/bin/pocketcoder
RUN chmod +x /usr/local/bin/pocketcoder && \
    printf '#!/bin/ash\n/usr/local/bin/pocketcoder shell "$@"\n' > /usr/local/bin/pocketcoder-shell && \
    chmod +x /usr/local/bin/pocketcoder-shell

# We use a custom entrypoint to harden the shell at runtime.
COPY services/opencode/opencode_entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/opencode_entrypoint.sh

# Use ash directly to avoid issues with shell hardening during container restart
ENTRYPOINT ["/bin/ash", "/usr/local/bin/opencode_entrypoint.sh"]
