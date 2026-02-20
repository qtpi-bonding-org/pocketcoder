# Use shared Rust builder
FROM rust:1.83-alpine AS rust-builder
RUN apk add --no-cache musl-dev gcc
WORKDIR /build
COPY proxy/Cargo.toml proxy/Cargo.lock* ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src
COPY proxy/src ./src
RUN touch src/main.rs
RUN cargo build --release

FROM oven/bun:alpine

# Install basic system dependencies (CURL is needed for health checks/scripts)
# (Alpine doesn't use bash by default, we keep it minimal)
RUN apk add --no-cache curl ripgrep openssh-server docker-cli

# Install docker-mcp plugin for MCP catalog browsing
RUN ARCH=$(uname -m) && \
    case $ARCH in \
      x86_64)  M_ARCH="amd64" ;; \
      aarch64) M_ARCH="arm64" ;; \
    esac && \
    VERSION="v0.39.3" && \
    curl -L "https://github.com/docker/mcp-gateway/releases/download/${VERSION}/docker-mcp-linux-${M_ARCH}.tar.gz" -o /tmp/docker-mcp.tar.gz && \
    tar -xzf /tmp/docker-mcp.tar.gz -C /tmp && \
    mkdir -p /usr/local/lib/docker/cli-plugins/ && \
    mv /tmp/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp && \
    chmod +x /usr/local/lib/docker/cli-plugins/docker-mcp && \
    rm /tmp/docker-mcp.tar.gz

ENV DOCKER_MCP_IN_CONTAINER=1

# Install OpenCode (The Reasoning Engine)
RUN bun install -g opencode-ai@1.2.8

# Make OpenCode accessible to all users (needed for SSH ForceCommand)
RUN chmod o+rx /root && chmod -R o+rX /root/.bun

# Create node symlink for opencode script compatibility
RUN ln -s /usr/local/bin/bun /usr/local/bin/node

# Set the working directory
WORKDIR /app

# Create poco user with ash shell for SSH ForceCommand access
RUN adduser -D -s /bin/ash poco && passwd -u poco

# Create .ssh directory for poco user with correct permissions
RUN mkdir -p /home/poco/.ssh && \
    chown poco:poco /home/poco/.ssh && \
    chmod 700 /home/poco/.ssh && \
    chmod 755 /home/poco

# Generate SSH host keys at build time
RUN ssh-keygen -A

# Configure sshd for poco user with ForceCommand
RUN mkdir -p /etc/ssh/sshd_config.d && \
    echo 'Port 2222' > /etc/ssh/sshd_config.d/poco.conf && \
    echo 'LogLevel DEBUG3' >> /etc/ssh/sshd_config.d/poco.conf && \
    echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config.d/poco.conf && \
    echo 'PubkeyAuthentication yes' >> /etc/ssh/sshd_config.d/poco.conf && \
    echo 'PubkeyAcceptedAlgorithms +ssh-rsa' >> /etc/ssh/sshd_config.d/poco.conf && \
    echo 'AllowUsers poco' >> /etc/ssh/sshd_config.d/poco.conf && \
    echo 'Match User poco' >> /etc/ssh/sshd_config.d/poco.conf && \
    echo '    AuthorizedKeysFile /home/poco/.ssh/authorized_keys' >> /etc/ssh/sshd_config.d/poco.conf && \
    echo '    ForceCommand /usr/local/bin/opencode attach http://localhost:3000 --continue' >> /etc/ssh/sshd_config.d/poco.conf

# 🛡️ HARD SHELL ENFORCEMENT
# Copy the pocketcoder binary and create wrapper script at build time
COPY --from=rust-builder /build/target/release/pocketcoder-proxy /usr/local/bin/pocketcoder
RUN chmod +x /usr/local/bin/pocketcoder && \
    printf '#!/bin/ash\n/usr/local/bin/pocketcoder shell "$@"\n' > /usr/local/bin/pocketcoder-shell && \
    chmod +x /usr/local/bin/pocketcoder-shell

# We use a custom entrypoint to harden the shell at runtime.
COPY docker/opencode_entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/opencode_entrypoint.sh

# Use ash directly to avoid issues with shell hardening during container restart
ENTRYPOINT ["/bin/ash", "/usr/local/bin/opencode_entrypoint.sh"]
