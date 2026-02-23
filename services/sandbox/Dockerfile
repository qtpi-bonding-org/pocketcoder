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

FROM python:3.11-slim-bookworm

# Install base tools + Node.js
RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    tmux \
    build-essential \
    sed \
    openssh-server \
    sudo \
    unzip \
    gnupg \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com bookworm main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

ENV BUN_INSTALL=/usr/local
ENV PATH=$BUN_INSTALL/bin:$PATH

RUN curl -fsSL https://bun.sh/install | bash \
    && ln -s /usr/local/bin/bun /usr/local/bin/node \
    && rm -rf /var/lib/apt/lists/*

# Install docker-cli (required for docker mcp plugin) and docker-mcp plugin
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

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

WORKDIR /sandbox

# Copy Sandbox entrypoints
COPY services/sandbox/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY services/sandbox/sync_keys.sh /usr/local/bin/sync_keys.sh
RUN chmod +x /usr/local/bin/sync_keys.sh

# Install Dependencies for Listener (Bun handles TS natively)
# Bun globals go to /usr/local/bin if BUN_INSTALL is /usr/local
RUN bun install -g opencode-ai@1.2.8

# Install uv (Python package manager for CAO)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv && \
    mv /root/.local/bin/uvx /usr/local/bin/uvx

# --- CAO Setup (PocketCoder Integration) ---
# Copy CAO Source (Vendored)
COPY services/sandbox/cao /app/cao

# Install Python dependencies and CAO in editable mode
# We do this in one step to ensure all files (README etc) are present
RUN pip install --no-cache-dir -e /app/cao

# Pre-sync uv dependencies so MCP server starts instantly
RUN cd /app/cao && uv sync

# Set Shared Tmux Socket by default for CAO
ENV TMUX_SOCKET=/tmp/tmux/pocketcoder
# -------------------------------------------


# --- SSH & Terminal Mirroring Setup ---
RUN useradd -m -s /bin/bash worker && \
    echo "worker:password" | chpasswd && \
    adduser worker sudo && \
    echo "worker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN mkdir -p /var/run/sshd
RUN sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
# Allow root for debugging if needed, but worker is preferred
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Fix entrypoint permissions
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh 
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy Rust binary from builder - no volume needed!
COPY --from=rust-builder /build/target/release/pocketcoder-proxy /usr/local/bin/pocketcoder
RUN chmod +x /usr/local/bin/pocketcoder

# Use the new entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]