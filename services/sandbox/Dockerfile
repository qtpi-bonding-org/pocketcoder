# Use shared Rust builder
FROM rust:1.88-alpine AS rust-builder
RUN apk add --no-cache musl-dev gcc
WORKDIR /build
COPY services/proxy/Cargo.toml services/proxy/Cargo.lock* ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src
COPY services/proxy/src ./src
RUN touch src/main.rs
RUN cargo build --release

# poco-agents builder (Alpine musl — no ONNX needed)
FROM rust:1.88-alpine AS agents-builder
RUN apk add --no-cache musl-dev gcc
WORKDIR /build
COPY services/poco-agents/Cargo.toml services/poco-agents/Cargo.lock* ./
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo build --release
RUN rm -rf src
COPY services/poco-agents/src ./src
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

COPY scripts/install-docker-mcp.sh /tmp/install-docker-mcp.sh
RUN /tmp/install-docker-mcp.sh && rm /tmp/install-docker-mcp.sh

ENV DOCKER_MCP_IN_CONTAINER=1

WORKDIR /sandbox

# Copy Sandbox entrypoints
COPY services/sandbox/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY services/sandbox/sync_keys.sh /usr/local/bin/sync_keys.sh
RUN chmod +x /usr/local/bin/sync_keys.sh

# Install Dependencies for Listener (Bun handles TS natively)
# Bun globals go to /usr/local/bin if BUN_INSTALL is /usr/local
RUN bun install -g opencode-ai@1.2.8

# Set Shared Tmux Socket
ENV TMUX_SOCKET=/tmp/tmux/pocketcoder


# --- SSH & Terminal Mirroring Setup ---
RUN useradd -m -s /bin/bash worker && \
    echo "worker:$(head -c 32 /dev/urandom | base64)" | chpasswd && \
    adduser worker sudo && \
    echo "worker ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
RUN mkdir -p /var/run/sshd
RUN sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
# Allow root for debugging if needed, but worker is preferred
RUN echo "PermitRootLogin no" >> /etc/ssh/sshd_config

# Fix entrypoint permissions
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh 
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy Rust binary from builder - no volume needed!
COPY --from=rust-builder /build/target/release/pocketcoder-proxy /usr/local/bin/pocketcoder
RUN chmod +x /usr/local/bin/pocketcoder

# Copy poco-agents binary
COPY --from=agents-builder /build/target/release/poco-agents /usr/local/bin/poco-agents
RUN chmod +x /usr/local/bin/poco-agents

# Use the new entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]