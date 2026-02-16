FROM oven/bun:alpine

# Install basic system dependencies (CURL is needed for health checks/scripts)
# (Alpine doesn't use bash by default, we keep it minimal)
RUN apk add --no-cache curl ripgrep

# Install OpenCode (The Reasoning Engine)
RUN bun install -g opencode-ai@latest

# Set the working directory
WORKDIR /app

# 🛡️ HARD SHELL ENFORCEMENT
# We use a custom entrypoint to harden the shell at runtime.
COPY docker/opencode_entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/opencode_entrypoint.sh

# Use our custom hardened entrypoint
ENTRYPOINT ["opencode_entrypoint.sh"]
