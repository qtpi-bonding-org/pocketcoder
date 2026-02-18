FROM rust:1.83-alpine AS builder
RUN apk add --no-cache musl-dev gcc
WORKDIR /app
COPY proxy/Cargo.toml proxy/Cargo.lock* ./
# Create dummy src/main.rs to build dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src

# Now copy actual source and build app
COPY proxy/src ./src
# Touch main.rs to ensure rebuild
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
    sqlite3 \
    openssh-client \
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

WORKDIR /sandbox

# Copy Sandbox entrypoints
COPY sandbox/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sandbox/sync_keys.sh /usr/local/bin/sync_keys.sh
RUN chmod +x /usr/local/bin/sync_keys.sh

# Install Dependencies for Listener (Bun handles TS natively)
# Bun globals go to /usr/local/bin if BUN_INSTALL is /usr/local
RUN bun install -g opencode-ai

# Install uv (Python package manager for CAO)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv && \
    mv /root/.local/bin/uvx /usr/local/bin/uvx

# --- CAO Setup (PocketCoder Integration) ---
# Copy CAO Source (Vendored)
COPY sandbox/cao /app/cao

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

# Copy Rust binary from builder
COPY --from=builder /app/target/release/pocketcoder-proxy /app/pocketcoder
RUN mkdir -p /app/shell_bridge
COPY --from=builder /app/target/release/pocketcoder-proxy /app/shell_bridge/pocketcoder
RUN printf '#!/bin/ash\n/app/shell_bridge/pocketcoder shell "$@"\n' > /app/shell_bridge/pocketcoder-shell && \
    chmod +x /app/shell_bridge/pocketcoder-shell

# Use the new entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]