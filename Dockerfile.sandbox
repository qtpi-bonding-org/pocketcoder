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
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /sandbox

# Copy Sandbox entrypoints
COPY sandbox/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY sandbox/sync_keys.sh /usr/local/bin/sync_keys.sh
RUN chmod +x /usr/local/bin/sync_keys.sh

# Install Dependencies for Listener (Need TS execution, likely ts-node or bun is gone now)
# We will use 'tsx' to execute typescript directly with Node
RUN npm install -g tsx opencode-ai

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
RUN useradd -m -s /bin/bash worker && echo "worker:password" | chpasswd && adduser worker sudo
RUN mkdir -p /var/run/sshd
RUN sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
# Allow root for debugging if needed, but worker is preferred
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

# Fix entrypoint permissions
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh 
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use the new entrypoint
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
